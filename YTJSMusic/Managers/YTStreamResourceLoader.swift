// YTJSMusic/Managers/YTStreamResourceLoader.swift
//
// Intercepts every AVPlayer HTTP request to YouTube CDN and ensures:
// 1. A Range header is ALWAYS present (YouTube URL param rqh=1 mandates it)
// 2. Requested byte ranges are capped at 512KB to avoid YouTube's anti-bulk-download HTTP 403

import Foundation
import AVFoundation

class YTStreamResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    
    // Custom URL scheme so AVPlayer routes ALL requests through this delegate
    static let scheme = "ytaudio"
    
    // 64KB per chunk: ~4s of 128kbps audio, well within YouTube CDN's range limit.
    // 512KB was triggering 403 — YouTube's rqh=1 URLs only allow small range requests.
    private static let chunkSize: Int64 = 64 * 1024  // 64KB
    
    // YouTube iOS app User-Agent — CDN may require this for c=IOS-generated URLs
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
        let infoReq  = loadingRequest.contentInformationRequest
        let dataReq  = loadingRequest.dataRequest
        
        // Determine byte range - always include Range header (required by YouTube rqh=1)
        var rangeStart: Int64 = 0
        var rangeEnd:   Int64 = Self.chunkSize - 1
        
        if let dr = dataReq {
            rangeStart = dr.requestedOffset
            let requested = Int64(dr.requestedLength)
            let capped    = min(requested, Self.chunkSize)
            rangeEnd      = rangeStart + capped - 1
        }
        
        var req = URLRequest(url: actualURL, timeoutInterval: 60)
        req.httpMethod = "GET"
        req.setValue("bytes=\(rangeStart)-\(rangeEnd)", forHTTPHeaderField: "Range")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        
        let logMsg = "[STREAM LOADER] → bytes=\(rangeStart)-\(rangeEnd) of \(actualURL.host ?? "googlevideo")"
        print(logMsg)
        SystemLogger.shared.append(logMsg)
        
        let key = ObjectIdentifier(loadingRequest)
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            defer {
                self.lock.lock()
                self.activeTasks.removeValue(forKey: key)
                self.lock.unlock()
            }
            
            if let error = error {
                let msg = "[STREAM LOADER ERROR] \(error.localizedDescription)"
                print(msg); SystemLogger.shared.append(msg)
                loadingRequest.finishLoading(with: error)
                return
            }
            
            guard let http = response as? HTTPURLResponse else {
                loadingRequest.finishLoading(with: NSError(domain: "YTStreamLoader", code: -1, userInfo: nil))
                return
            }
            
            let resMsg = "[STREAM LOADER] ← HTTP \(http.statusCode) | \(data?.count ?? 0) bytes | bytes=\(rangeStart)-\(rangeEnd)"
            print(resMsg); SystemLogger.shared.append(resMsg)
            
            guard http.statusCode < 400 else {
                let err = NSError(domain: "YTStreamLoader", code: http.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "YouTube CDN HTTP \(http.statusCode)"])
                loadingRequest.finishLoading(with: err)
                return
            }
            
            // Populate content information (total file size, MIME, seek support)
            if let info = infoReq {
                info.isByteRangeAccessSupported = true
                info.contentType = "audio/mp4"
                for (k, v) in http.allHeaderFields {
                    if "\(k)".lowercased() == "content-range" {
                        // "bytes start-end/total"
                        if let totalStr = "\(v)".components(separatedBy: "/").last,
                           let total   = Int64(totalStr.trimmingCharacters(in: .whitespaces)), total > 0 {
                            info.contentLength = total
                        }
                        break
                    }
                }
            }
            
            if let data = data, !data.isEmpty {
                loadingRequest.dataRequest?.respond(with: data)
            }
            loadingRequest.finishLoading()
        }
        
        lock.lock()
        activeTasks[key] = task
        lock.unlock()
        task.resume()
    }
}
