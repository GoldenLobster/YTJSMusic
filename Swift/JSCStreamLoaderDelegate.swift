// Swift/JSCStreamLoaderDelegate.swift
// Resource Loader Delegate for AVPlayer to stream HTTPS audio with custom YouTube User-Agent & Headers

import Foundation
import AVFoundation

public class JSCStreamLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate {
    private var session: URLSession?
    private var pendingRequests: [AVAssetResourceLoadingRequest: URLSessionDataTask] = [:]
    
    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30.0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let customURL = loadingRequest.request.url,
              var components = URLComponents(url: customURL, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        components.scheme = "https"
        guard let targetURL = components.url else { return false }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        
        // Inject YouTube iOS App User-Agent and Origin headers
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        
        // Handle Byte Range requests from AVPlayer
        if let dataRequest = loadingRequest.dataRequest {
            let offset = dataRequest.requestedOffset
            let length = dataRequest.requestedLength
            if length > 0 {
                let rangeHeader = "bytes=\(offset)-\(offset + Int64(length) - 1)"
                request.setValue(rangeHeader, forHTTPHeaderField: "Range")
            } else {
                let rangeHeader = "bytes=\(offset)-"
                request.setValue(rangeHeader, forHTTPHeaderField: "Range")
            }
        }
        
        print("[RESOURCE LOADER] Intercepted stream request for target: \(targetURL.host ?? "googlevideo.com")")
        
        let task = session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[RESOURCE LOADER ERROR] \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
                self.pendingRequests.removeValue(forKey: loadingRequest)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                loadingRequest.finishLoading(with: NSError(domain: "JSCStreamLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
                self.pendingRequests.removeValue(forKey: loadingRequest)
                return
            }
            
            // Set content information request properties if present
            if let infoRequest = loadingRequest.contentInformationRequest {
                infoRequest.isByteRangeAccessSupported = true
                
                // Convert MIME type to valid Apple Uniform Type Identifier (UTI)
                let mime = httpResponse.mimeType?.lowercased() ?? ""
                if mime.contains("webm") {
                    infoRequest.contentType = "org.webmproject.webm"
                } else if mime.contains("mp4") || mime.contains("m4a") || mime.contains("aac") {
                    infoRequest.contentType = "public.mpeg-4-audio"
                } else {
                    infoRequest.contentType = "public.mpeg-4-audio"
                }
                
                // Extract total content length from Content-Range or Content-Length
                if let contentRange = httpResponse.allHeaderFields["Content-Range"] as? String,
                   let totalStr = contentRange.components(separatedBy: "/").last,
                   let totalLength = Int64(totalStr) {
                    infoRequest.contentLength = totalLength
                } else if let contentLengthStr = httpResponse.allHeaderFields["Content-Length"] as? String,
                          let contentLength = Int64(contentLengthStr) {
                    infoRequest.contentLength = contentLength
                }
            }
            
            if let dataRequest = loadingRequest.dataRequest, let data = data {
                dataRequest.respond(with: data)
                loadingRequest.finishLoading()
                print("[RESOURCE LOADER SUCCESS] Provided \(data.count) bytes to AVPlayer (HTTP \(httpResponse.statusCode))")
            } else {
                loadingRequest.finishLoading()
            }
            
            self.pendingRequests.removeValue(forKey: loadingRequest)
        }
        
        pendingRequests[loadingRequest] = task
        task?.resume()
        return true
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        if let task = pendingRequests[loadingRequest] {
            task.cancel()
            pendingRequests.removeValue(forKey: loadingRequest)
        }
    }
}
