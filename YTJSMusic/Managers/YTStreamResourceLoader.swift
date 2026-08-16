// YTJSMusic/Managers/YTStreamResourceLoader.swift
import Foundation
import AVFoundation

public class YTStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    public static let scheme = "ytaudio"
    private static let chunkSize: Int64 = 256 * 1024  // 256KB sub-chunks
    private static let userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)"
    
    private let resourceLoaderQueue = DispatchQueue(label: "com.ytjsmusic.resourceloader", qos: .userInitiated)
    
    public let streamSource: StreamSource
    private var remoteURL: URL?
    private let track: Track
    private let jscClient: JSCYoutubeClient
    
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let lock = NSLock()
    
    public var trace: PlaybackStartupTrace?
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    public init(streamSource: StreamSource, track: Track, jscClient: JSCYoutubeClient) {
        self.streamSource = streamSource
        self.track = track
        self.jscClient = jscClient
        switch streamSource {
        case .cached:
            self.remoteURL = nil
        case .remote(let ref):
            self.remoteURL = ref.initialURL
        }
        super.init()
    }
    
    public var customSchemeURL: URL {
        switch streamSource {
        case .cached(let ref):
            return ref.key.cacheURL
        case .remote(let ref):
            var comps = URLComponents(url: ref.initialURL, resolvingAgainstBaseURL: false) ?? URLComponents()
            comps.scheme = Self.scheme
            return comps.url ?? ref.initialURL
        }
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                                shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        resourceLoaderQueue.async { [weak self] in
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
        if trace?.t4FirstResourceRequest == nil {
            trace?.t4FirstResourceRequest = CACurrentMediaTime()
        }
        
        let infoReq = loadingRequest.contentInformationRequest
        let dataReq = loadingRequest.dataRequest
        let cacheKey = streamSource.key
        
        if let info = infoReq {
            info.isByteRangeAccessSupported = true
            info.contentType = cacheKey.mimeType.contains("opus") ? "audio/webm" : "com.apple.m4a-audio"
            
            if let cachedInfo = AudioStreamCacheIndex.shared.getStreamInfo(key: cacheKey), cachedInfo.contentLength > 0 {
                info.contentLength = cachedInfo.contentLength
            } else if case .remote(let ref) = streamSource, let total = ref.contentLength, total > 0 {
                info.contentLength = total
            }
        }
        
        guard let dr = dataReq else {
            if !loadingRequest.isCancelled { loadingRequest.finishLoading() }
            return
        }
        
        let requestedStart = Int(dr.currentOffset)
        let fetchLength = Int(Swift.min(Int64(dr.requestedLength), Self.chunkSize))
        let requestedRange = NSRange(location: requestedStart, length: fetchLength)
        
        // 1. Try synchronous reading via AudioStreamCacheDiskReader
        if let result = AudioStreamCacheDiskReader.shared.readChunkSync(key: cacheKey, requestedRange: requestedRange), !result.data.isEmpty {
            if trace?.t5FirstBytesSupplied == nil {
                trace?.t5FirstBytesSupplied = CACurrentMediaTime()
            }
            trace?.bytesServedFromDisk += Int64(result.data.count)
            dr.respond(with: result.data)
            
            if result.isCompleteRequest {
                if !loadingRequest.isCancelled { loadingRequest.finishLoading() }
                return
            }
            
            // If partial chunk served, update requestedRange for remaining missing bytes
            let servedLength = result.data.count
            let remainingRange = NSRange(location: requestedStart + servedLength, length: fetchLength - servedLength)
            fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: remainingRange, retryAttempt: 0)
            return
        }
        
        // 2. Uncached range: Fetch from YouTube CDN
        fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: requestedRange, retryAttempt: 0)
    }
    
    private func fetchBytesFromCDN(loadingRequest: AVAssetResourceLoadingRequest, requestedRange: NSRange, retryAttempt: Int) {
        guard !loadingRequest.isCancelled, let dr = loadingRequest.dataRequest else { return }
        let cacheKey = streamSource.key
        
        // If remoteURL is nil (cached scheme fallback), resolve URL on demand
        if remoteURL == nil {
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
                self.remoteURL = newURL
            } else {
                let err = NSError(domain: "YTStreamLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to resolve CDN fallback URL"])
                loadingRequest.finishLoading(with: err)
                return
            }
        }
        
        guard let url = remoteURL else { return }
        
        let reqStart = requestedRange.location
        let reqEnd = requestedRange.location + requestedRange.length - 1
        
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("bytes=\(reqStart)-\(reqEnd)", forHTTPHeaderField: "Range")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        
        let sema = DispatchSemaphore(value: 0)
        var fetchedData: Data?
        var statusCode: Int = 0
        var taskError: Error?
        var responseHeaders: [AnyHashable: Any]?
        
        let key = ObjectIdentifier(loadingRequest)
        trace?.networkRequests += 1
        
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
        
        let tStart = CACurrentMediaTime()
        task.resume()
        let waitResult = sema.wait(timeout: .now() + 12.0)
        let elapsed = CACurrentMediaTime() - tStart
        
        if waitResult == .timedOut {
            SystemLogger.shared.append("[STREAM LOADER TIMEOUT] Request for range \(reqStart)-\(reqEnd) timed out after \(String(format: "%.1f", elapsed))s. Cancelling task...")
            task.cancel()
            lock.lock()
            activeTasks.removeValue(forKey: key)
            lock.unlock()
            if !loadingRequest.isCancelled {
                let err = NSError(domain: "YTStreamLoader", code: -1001, userInfo: [NSLocalizedDescriptionKey: "CDN chunk request timed out"])
                loadingRequest.finishLoading(with: err)
            }
            return
        }
        
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
                self.remoteURL = newURL
                fetchBytesFromCDN(loadingRequest: loadingRequest, requestedRange: requestedRange, retryAttempt: retryAttempt + 1)
                return
            }
        }
        
        // 4. Exponential Backoff for Transient Network Failure
        if (taskError != nil || statusCode >= 500) && retryAttempt < 3 {
            let backoffDelay = pow(2.0, Double(retryAttempt)) * 0.5
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
        if let headers = responseHeaders {
            for (k, v) in headers {
                if "\(k)".lowercased() == "content-range" {
                    if let totalStr = "\(v)".components(separatedBy: "/").last,
                       let total = Int64(totalStr.trimmingCharacters(in: .whitespaces)), total > 0 {
                        if let info = loadingRequest.contentInformationRequest {
                            info.contentLength = total
                        }
                        let saveKey = cacheKey
                        Task {
                            await AudioStreamCacheManager.shared.updateContentLength(key: saveKey, length: total)
                        }
                    }
                    break
                }
            }
        }
        
        if let data = fetchedData, !data.isEmpty {
            if trace?.t5FirstBytesSupplied == nil {
                trace?.t5FirstBytesSupplied = CACurrentMediaTime()
            }
            trace?.bytesFetchedFromCDN += Int64(data.count)
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
