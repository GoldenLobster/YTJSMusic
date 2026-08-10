// YTJSMusic/Managers/YTStreamResourceLoader.swift
import Foundation
import AVFoundation

public class YTStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    public static let scheme = "ytaudio"
    private static let chunkSize: Int64 = 256 * 1024  // 256KB sub-chunks
    private static let userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)"
    
    private var streamURL: URL
    private let track: Track
    private let cacheKey: AudioStreamCacheKey
    private let jscClient: JSCYoutubeClient
    
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let lock = NSLock()
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    public init(streamURL: URL, track: Track, cacheKey: AudioStreamCacheKey, jscClient: JSCYoutubeClient) {
        self.streamURL = streamURL
        self.track = track
        self.cacheKey = cacheKey
        self.jscClient = jscClient
        super.init()
    }
    
    public func getCustomSchemeURL() -> URL? {
        var comps = URLComponents(url: streamURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        comps.scheme = Self.scheme
        return comps.url
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.perform(loadingRequest)
        }
        return true
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let key = ObjectIdentifier(loadingRequest)
        lock.lock()
        activeTasks[key]?.cancel()
        activeTasks.removeValue(forKey: key)
        lock.unlock()
    }
    
    private func perform(_ loadingRequest: AVAssetResourceLoadingRequest) {
        let infoReq = loadingRequest.contentInformationRequest
        let dataReq = loadingRequest.dataRequest
        
        if let info = infoReq {
            info.isByteRangeAccessSupported = true
            info.contentType = cacheKey.mimeType.contains("opus") ? "audio/webm" : "com.apple.m4a-audio"
        }
        
        guard let dr = dataReq else {
            if !loadingRequest.isCancelled { loadingRequest.finishLoading() }
            return
        }
        
        let requestedStart = Int(dr.currentOffset)
        let fetchLength = Int(Swift.min(Int64(dr.requestedLength), Self.chunkSize))
        let requestedRange = NSRange(location: requestedStart, length: fetchLength)
        
        // 1. Try reading from AudioStreamCacheManager
        class ReadDataBox {
            var data: Data? = nil
        }
        let semaphore = DispatchSemaphore(value: 0)
        let box = ReadDataBox()
        let key = self.cacheKey
        
        Task {
            box.data = await AudioStreamCacheManager.shared.readChunk(key: key, requestedRange: requestedRange)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        if let data = box.data, !data.isEmpty {
            SystemLogger.shared.append("[CACHE HIT] Served \(data.count) bytes from disk for offset \(requestedStart)")
            dr.respond(with: data)
            if !loadingRequest.isCancelled { loadingRequest.finishLoading() }
            return
        }
        
        // 2. Uncached range: Fetch from YouTube CDN with 403 Re-resolution & Backoff
        fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: requestedRange, retryAttempt: 0)
    }
    
    private func fetchBytesFromCDN(loadingRequest: AVAssetResourceLoadingRequest, requestedRange: NSRange, retryAttempt: Int) {
        guard !loadingRequest.isCancelled, let dr = loadingRequest.dataRequest else { return }
        
        let reqStart = requestedRange.location
        let reqEnd = requestedRange.location + requestedRange.length - 1
        
        var req = URLRequest(url: streamURL, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("bytes=\(reqStart)-\(reqEnd)", forHTTPHeaderField: "Range")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        
        let sema = DispatchSemaphore(value: 0)
        var fetchedData: Data?
        var statusCode: Int = 0
        var taskError: Error?
        var responseHeaders: [AnyHashable: Any]?
        
        let key = ObjectIdentifier(loadingRequest)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
                responseHeaders = http.allHeaderFields
            }
            fetchedData = data
            taskError = error
            
            self?.lock.lock()
            self?.activeTasks.removeValue(forKey: key)
            self?.lock.unlock()
            
            sema.signal()
        }
        
        lock.lock()
        activeTasks[key] = task
        lock.unlock()
        
        task.resume()
        _ = sema.wait(timeout: .now() + 15.0)
        
        if loadingRequest.isCancelled { return }
        
        // 3. Smart HTTP 403 Recovery (URL Signature Expiration)
        if statusCode == 403 {
            SystemLogger.shared.append("[STREAM LOADER HTTP 403] Expiration detected. Re-resolving fresh stream URL...")
            let resSema = DispatchSemaphore(value: 0)
            var freshURL: URL? = nil
            
            jscClient.getAudioStreamUrl(videoId: track.id) { result in
                if case .success(let streamUrlStr) = result, let url = URL(string: streamUrlStr) {
                    freshURL = url
                }
                resSema.signal()
            }
            _ = resSema.wait(timeout: .now() + 10.0)
            
            if let newURL = freshURL {
                SystemLogger.shared.append("[STREAM LOADER 403 FIXED] Re-resolved fresh URL. Retrying byte fetch...")
                self.streamURL = newURL
                fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: requestedRange, retryAttempt: retryAttempt + 1)
                return
            }
        }
        
        // 4. Exponential Backoff for Transient Network Failure
        if (taskError != nil || statusCode >= 500) && retryAttempt < 3 {
            let backoffDelay = pow(2.0, Double(retryAttempt)) * 0.5 // 0.5s, 1s, 2s
            SystemLogger.shared.append("[STREAM LOADER BACKOFF] Transient error (HTTP \(statusCode)). Retrying in \(backoffDelay)s...")
            Thread.sleep(forTimeInterval: backoffDelay)
            fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: requestedRange, retryAttempt: retryAttempt + 1)
            return
        }
        
        if let error = taskError {
            loadingRequest.finishLoading(with: error)
            return
        }
        
        if statusCode >= 400 {
            let err = NSError(domain: "YTStreamLoader", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "YouTube CDN HTTP \(statusCode)"])
            loadingRequest.finishLoading(with: err)
            return
        }
        
        // Populate Content-Length if provided
        if let info = loadingRequest.contentInformationRequest, let headers = responseHeaders {
            for (k, v) in headers {
                if "\(k)".lowercased() == "content-range" {
                    if let totalStr = "\(v)".components(separatedBy: "/").last,
                       let total = Int64(totalStr.trimmingCharacters(in: .whitespaces)), total > 0 {
                        info.contentLength = total
                    }
                    break
                }
            }
        }
        
        if let data = fetchedData, !data.isEmpty {
            dr.respond(with: data)
            
            // Save newly fetched data to AudioStreamCacheManager
            let saveKey = cacheKey
            Task {
                await AudioStreamCacheManager.shared.writeChunk(key: saveKey, range: requestedRange, data: data)
            }
        }
        
        if !loadingRequest.isCancelled {
            loadingRequest.finishLoading()
        }
    }
}
