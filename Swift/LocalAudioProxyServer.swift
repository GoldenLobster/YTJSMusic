// Swift/LocalAudioProxyServer.swift
// Lightweight local HTTP proxy server for AVPlayer to forward stream requests with YouTube headers

import Foundation
import Network

public class LocalAudioProxyServer {
    public static let shared = LocalAudioProxyServer()
    
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let queue = DispatchQueue(label: "com.antigravity.proxy", qos: .userInitiated)
    
    public func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[PROXY] Local HTTP Audio Proxy server ready on 127.0.0.1:\(self.port)")
                case .failed(let err):
                    print("[PROXY ERROR] Proxy server failed: \(err.localizedDescription)")
                default:
                    break
                }
            }
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: queue)
        } catch {
            print("[PROXY ERROR] Could not start NWListener: \(error.localizedDescription)")
        }
    }
    
    public func getProxyURL(for rawStreamUrl: String) -> URL? {
        guard let encoded = rawStreamUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "http://127.0.0.1:\(port)/stream?url=\(encoded)")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty, error == nil else {
                connection.cancel()
                return
            }
            
            let requestString = String(data: data, encoding: .utf8) ?? ""
            self.processHTTPRequest(requestString: requestString, connection: connection)
        }
    }
    
    private func processHTTPRequest(requestString: String, connection: NWConnection) {
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            connection.cancel()
            return
        }
        
        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2, components[0] == "GET" else {
            connection.cancel()
            return
        }
        
        let pathAndQuery = components[1]
        guard let urlComponents = URLComponents(string: pathAndQuery),
              let queryItems = urlComponents.queryItems,
              let targetUrlString = queryItems.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: targetUrlString) else {
            let notFound = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
            connection.send(content: notFound.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
            return
        }
        
        // Extract Range header from incoming request
        var rangeHeader: String? = nil
        for line in lines {
            if line.lowercased().hasPrefix("range:") {
                rangeHeader = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            }
        }
        
        print("[PROXY] Forwarding GET request for \(targetURL.host ?? "googlevideo.com") Range: \(rangeHeader ?? "bytes=0-")")
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        if let rangeHeader = rangeHeader {
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: sessionConfig)
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse, let data = data, error == nil else {
                let errResp = "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n"
                connection.send(content: errResp.data(using: .utf8), completion: .contentProcessed({ _ in connection.cancel() }))
                return
            }
            
            // Build HTTP response headers to return to AVPlayer
            var headerLines = [
                "HTTP/1.1 \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))",
                "Content-Type: \(httpResponse.mimeType ?? "audio/mp4")",
                "Content-Length: \(data.count)",
                "Accept-Ranges: bytes",
                "Connection: close"
            ]
            
            if let contentRange = httpResponse.allHeaderFields["Content-Range"] as? String {
                headerLines.append("Content-Range: \(contentRange)")
            }
            
            let headerData = (headerLines.joined(separator: "\r\n") + "\r\n\r\n").data(using: .utf8)!
            
            connection.send(content: headerData, completion: .contentProcessed({ _ in
                connection.send(content: data, completion: .contentProcessed({ _ in
                    print("[PROXY SUCCESS] Sent \(data.count) bytes to AVPlayer (HTTP \(httpResponse.statusCode))")
                    connection.cancel()
                }))
            }))
        }
        task.resume()
    }
}
