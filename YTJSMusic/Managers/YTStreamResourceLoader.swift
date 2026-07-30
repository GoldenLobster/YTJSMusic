// YTJSMusic/Managers/YTStreamResourceLoader.swift
//
// Intercepts every AVPlayer HTTP request to YouTube CDN and ensures:
// 1. A Range header is ALWAYS present (YouTube URL param rqh=1 mandates it)
// 2. Sub-chunked downloading (256KB per HTTP request) to satisfy YouTube CDN rate-limits while fully fulfilling AVPlayer's requested byte ranges.

import Foundation
import AVFoundation

class YTStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    
    // Custom URL scheme so AVPlayer routes ALL requests through this delegate
    static let scheme = "ytaudio"
    
    // 256KB sub-chunks: ~16 seconds of 128kbps audio per HTTP request.
    // Fetching in 256KB sub-chunks satisfies YouTube CDN range limits while allowing
    // AVPlayer to continuously receive data without early finishLoading() cutoffs.
    private static let chunkSize: Int64 = 256 * 1024  // 256KB
    
    // YouTube iOS app User-Agent — CDN requires this for c=IOS-generated URLs
    private static let userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)"
    
    private let actualURL: URL
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let lock = NSLock()
    
    // Ephemeral session: no shared cookies or cache that could corrupt YouTube CDN requests
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
    /// Caller MUST retain the returned loader for the lifetime of the AVPlayerItem.
    static func makeAsset(for streamURL: URL) -> (AVURLAsset, YTStreamResourceLoader) {
        let loader = YTStreamResourceLoader(actualURL: streamURL)
        
        // Swap https:// -> ytaudio:// so AVURLAsset defers to our delegate
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
        
        // 1. Handle Content Information Request
        if let info = infoReq {
            info.isByteRangeAccessSupported = true
            info.contentType = AVFileType.m4a.rawValue // "com.apple.m4a-audio"
            
            // Quick 2-byte probe to determine total track length if not yet known
            var probeReq = URLRequest(url: actualURL, timeoutInterval: 30)
            probeReq.httpMethod = "GET"
            probeReq.setValue("bytes=0-1", forHTTPHeaderField: "Range")
            probeReq.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            
            let sema = DispatchSemaphore(value: 0)
            var totalLength: Int64 = 0
            
            let probeTask = session.dataTask(with: probeReq) { data, response, error in
                if let http = response as? HTTPURLResponse {
                    for (k, v) in http.allHeaderFields {
                        if "\(k)".lowercased() == "content-range" {
                            if let totalStr = "\(v)".components(separatedBy: "/").last,
                               let total = Int64(totalStr.trimmingCharacters(in: .whitespaces)), total > 0 {
                                totalLength = total
                            }
                            break
                        }
                    }
                }
                sema.signal()
            }
            probeTask.resume()
            _ = sema.wait(timeout: .now() + 10.0)
            
            if totalLength > 0 {
                info.contentLength = totalLength
                SystemLogger.shared.append("[STREAM LOADER] Total track size: \(totalLength) bytes")
            }
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
        
        // Continuously fetch sub-chunks and feed data to AVPlayer until requestedLength is satisfied
        while dr.currentOffset < targetEndOffset && !loadingRequest.isCancelled {
            let currentStart = dr.currentOffset
            let currentEnd = min(currentStart + Self.chunkSize - 1, targetEndOffset - 1)
            
            var req = URLRequest(url: actualURL, timeoutInterval: 30)
            req.httpMethod = "GET"
            req.setValue("bytes=\(currentStart)-\(currentEnd)", forHTTPHeaderField: "Range")
            req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            
            let sema = DispatchSemaphore(value: 0)
            var chunkData: Data?
            var statusCode: Int = 0
            var taskError: Error?
            
            let key = ObjectIdentifier(loadingRequest)
            let task = session.dataTask(with: req) { [weak self] data, response, error in
                statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
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
            _ = sema.wait(timeout: .now() + 30.0)
            
            if loadingRequest.isCancelled {
                SystemLogger.shared.append("[STREAM LOADER] Request cancelled by AVPlayer at offset \(currentStart)")
                return
            }
            
            if let error = taskError {
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
            
            guard let data = chunkData, !data.isEmpty else {
                // End of stream reached
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
