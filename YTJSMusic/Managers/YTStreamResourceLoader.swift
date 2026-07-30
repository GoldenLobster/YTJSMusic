// YTJSMusic/Managers/YTStreamResourceLoader.swift
//
// Intercepts every AVPlayer HTTP request to YouTube CDN and ensures:
// 1. Range header is ALWAYS present (YouTube rqh=1 param requires it)
// 2. Sub-chunked downloading (128KB per HTTP request) for fast, zero-delay initial playback and smooth streaming without 1MB cutoffs.

import Foundation
import AVFoundation

class YTStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    
    // Custom URL scheme so AVPlayer routes ALL requests through this delegate
    static let scheme = "ytaudio"
    
    // 128KB sub-chunks: ~8s of 128kbps audio per HTTP request.
    // Fetching in 128KB sub-chunks allows initial playback to start in <100ms.
    private static let chunkSize: Int64 = 128 * 1024  // 128KB
    
    // YouTube iOS app User-Agent
    private static let userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)"
    
    private let actualURL: URL
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let lock = NSLock()
    
    // Ephemeral session: no shared cookies or cache
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    init(actualURL: URL) {
        self.actualURL = actualURL
        super.init()
    }
    
    // MARK: - Factory
    
    /// Creates an AVURLAsset wired to this resource loader.
    /// The asset uses a `ytaudio://` scheme that forces ALL requests through our delegate.
    static func makeAsset(for streamURL: URL) -> (AVURLAsset, YTStreamResourceLoader) {
        let loader = YTStreamResourceLoader(actualURL: streamURL)
        
        var comps = URLComponents(url: streamURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        comps.scheme = scheme
        let fakeURL = comps.url ?? streamURL
        
        let asset = AVURLAsset(url: fakeURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.global(qos: .userInitiated))
        return (asset, loader)
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        perform(loadingRequest)
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let key = ObjectIdentifier(loadingRequest)
        lock.lock()
        activeTasks[key]?.cancel()
        activeTasks.removeValue(forKey: key)
        lock.unlock()
    }
    
    // MARK: - Request Handling
    
    private func perform(_ loadingRequest: AVAssetResourceLoadingRequest) {
        let infoReq = loadingRequest.contentInformationRequest
        let dataReq = loadingRequest.dataRequest
        
        // 1. Immediately configure Content Information Request if present
        if let info = infoReq {
            info.isByteRangeAccessSupported = true
            info.contentType = AVFileType.m4a.rawValue // "com.apple.m4a-audio"
        }
        
        // 2. Handle Data Request
        guard let dr = dataReq else {
            if !loadingRequest.isCancelled {
                loadingRequest.finishLoading()
            }
            return
        }
        
        let targetEndOffset = dr.requestedOffset + Int64(dr.requestedLength)
        let hostName = actualURL.host ?? "googlevideo"
        
        let startLog = "[STREAM LOADER] Requested range: bytes=\(dr.requestedOffset)-\(targetEndOffset - 1) (\(dr.requestedLength) bytes) of \(hostName)"
        print(startLog)
        SystemLogger.shared.append(startLog)
        
        // Continuously fetch 128KB sub-chunks and feed data to AVPlayer
        while dr.currentOffset < targetEndOffset && !loadingRequest.isCancelled {
            let currentStart = dr.currentOffset
            let currentEnd = min(currentStart + Self.chunkSize - 1, targetEndOffset - 1)
            
            var req = URLRequest(url: actualURL, timeoutInterval: 20)
            req.httpMethod = "GET"
            req.setValue("bytes=\(currentStart)-\(currentEnd)", forHTTPHeaderField: "Range")
            req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            
            let sema = DispatchSemaphore(value: 0)
            var chunkData: Data?
            var statusCode: Int = 0
            var taskError: Error?
            var responseHeaders: [AnyHashable: Any]?
            
            let key = ObjectIdentifier(loadingRequest)
            let task = session.dataTask(with: req) { [weak self] data, response, error in
                if let http = response as? HTTPURLResponse {
                    statusCode = http.statusCode
                    responseHeaders = http.allHeaderFields
                }
                chunkData = data
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
            _ = sema.wait(timeout: .now() + 20.0)
            
            if loadingRequest.isCancelled {
                SystemLogger.shared.append("[STREAM LOADER] Cancelled at offset \(currentStart)")
                return
            }
            
            if let error = taskError {
                if (error as NSError).code == NSURLErrorCancelled { return }
                let msg = "[STREAM LOADER ERROR] Network error at \(currentStart): \(error.localizedDescription)"
                print(msg); SystemLogger.shared.append(msg)
                loadingRequest.finishLoading(with: error)
                return
            }
            
            if statusCode >= 400 {
                let msg = "[STREAM LOADER HTTP \(statusCode)] Failed fetching bytes=\(currentStart)-\(currentEnd)"
                print(msg); SystemLogger.shared.append(msg)
                let err = NSError(domain: "YTStreamLoader", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "YouTube CDN HTTP \(statusCode)"])
                loadingRequest.finishLoading(with: err)
                return
            }
            
            // Populate content length dynamically from response headers
            if let info = infoReq, info.contentLength == 0, let headers = responseHeaders {
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
            
            guard let data = chunkData, !data.isEmpty else {
                break
            }
            
            dr.respond(with: data)
            let progressMsg = "[STREAM LOADER] Fetched \(data.count) bytes (progress: \(dr.currentOffset)/\(targetEndOffset))"
            print(progressMsg)
            SystemLogger.shared.append(progressMsg)
        }
        
        if !loadingRequest.isCancelled {
            loadingRequest.finishLoading()
        }
    }
}
