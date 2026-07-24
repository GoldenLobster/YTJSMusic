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
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let customURL = loadingRequest.request.url,
              var components = URLComponents(url: customURL, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        // Convert custom scheme back to https
        components.scheme = "https"
        guard let targetURL = components.url else { return false }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        
        // Pass YouTube iOS app User-Agent and Origin headers
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        
        // Handle Range requests from AVPlayer
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
        
        print("[RESOURCE LOADER] Intercepted stream request for \(targetURL.host ?? "googlevideo.com")")
        
        let task = session?.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[RESOURCE LOADER ERROR] \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
                self.pendingRequests.removeValue(forKey: loadingRequest)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if let dataRequest = loadingRequest.dataRequest, let data = data {
                    // Fill response info
                    let infoRequest = loadingRequest.contentInformationRequest
                    infoRequest?.isByteRangeAccessSupported = true
                    infoRequest?.contentType = httpResponse.mimeType ?? "audio/mp4"
                    if let contentLengthStr = httpResponse.allHeaderFields["Content-Length"] as? String,
                       let contentLength = Int64(contentLengthStr) {
                        infoRequest?.contentLength = contentLength
                    }
                    
                    dataRequest.respond(with: data)
                    loadingRequest.finishLoading()
                    print("[RESOURCE LOADER] Streamed \(data.count) bytes to AVPlayer (HTTP \(httpResponse.statusCode))")
                } else {
                    loadingRequest.finishLoading()
                }
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
