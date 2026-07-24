// Swift/LocalAudioProxyServer.swift
// Lightweight local HTTP proxy server for AVPlayer to forward stream requests with YouTube headers

import Foundation
import Network

public class LocalAudioProxyServer {
    public static let shared = LocalAudioProxyServer()
    
    public var onLog: ((String) -> Void)?
    
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private let queue = DispatchQueue(label: "com.antigravity.proxy", qos: .userInitiated)
    
    public func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else { return }
            listener = try NWListener(using: parameters, on: endpointPort)
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    let msg = "[PROXY] Local HTTP Audio Proxy server ready on 127.0.0.1:\(self?.port ?? 8080)"
                    print(msg)
                    self?.onLog?(msg)
                case .failed(let err):
                    let msg = "[PROXY ERROR] Proxy server failed: \(err.localizedDescription)"
                    print(msg)
                    self?.onLog?(msg)
                default:
                    break
                }
            }
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: queue)
        } catch {
            let msg = "[PROXY ERROR] Could not start NWListener: \(error.localizedDescription)"
            print(msg)
            onLog?(msg)
        }
    }
    
    // Safely encode raw stream URL as URL-safe Base64 to prevent query-string splitting or char corruption
    public func getProxyURL(for rawStreamUrl: String) -> URL? {
        guard let data = rawStreamUrl.data(using: .utf8) else { return nil }
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
                 .replacingOccurrences(of: "/", with: "_")
                 .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return URL(string: "http://127.0.0.1:\(port)/stream?b64=\(b64)")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
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
              let rawB64Value = queryItems.first(where: { $0.name == "b64" })?.value else {
            let notFound = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
            let completion: NWConnection.SendCompletion = .contentProcessed { _ in connection.cancel() }
            connection.send(content: notFound.data(using: .utf8), completion: completion)
            return
        }
        
        // Convert URL-safe Base64 back to standard Base64 (restoring + and / and padding =)
        var b64String = rawB64Value.replacingOccurrences(of: "-", with: "+")
                                   .replacingOccurrences(of: "_", with: "/")
                                   .replacingOccurrences(of: " ", with: "+")
        while b64String.count % 4 != 0 {
            b64String.append("=")
        }
        
        guard let b64Data = Data(base64Encoded: b64String),
              let targetUrlString = String(data: b64Data, encoding: .utf8),
              let targetURL = URL(string: targetUrlString) else {
            let logErr = "[PROXY ERROR] Failed to decode Base64 target URL from: \(rawB64Value)"
            print(logErr)
            onLog?(logErr)
            let notFound = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"
            let completion: NWConnection.SendCompletion = .contentProcessed { _ in connection.cancel() }
            connection.send(content: notFound.data(using: .utf8), completion: completion)
            return
        }
        
        // Extract Range header from incoming AVPlayer request
        var rangeHeader: String? = nil
        for line in lines {
            if line.lowercased().hasPrefix("range:") {
                rangeHeader = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            }
        }
        
        let reqLog = "[PROXY] Forwarding GET for \(targetURL.host ?? "googlevideo.com") (Range: \(rangeHeader ?? "bytes=0-"))"
        print(reqLog)
        onLog?(reqLog)
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.setValue("com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)", forHTTPHeaderField: "User-Agent")
        if let rangeHeader = rangeHeader {
            request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: sessionConfig)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 403 {
                let warnMsg = "[PROXY 403 FORBIDDEN] \(targetURL.host ?? "") returned 403. Retrying without custom User-Agent..."
                print(warnMsg)
                self.onLog?(warnMsg)
                
                var retryRequest = URLRequest(url: targetURL)
                retryRequest.httpMethod = "GET"
                if let rangeHeader = rangeHeader {
                    retryRequest.setValue(rangeHeader, forHTTPHeaderField: "Range")
                }
                
                let retryTask = session.dataTask(with: retryRequest) { rData, rResponse, rError in
                    if let rHttp = rResponse as? HTTPURLResponse {
                        let rMsg = "[PROXY RETRY RESULT] Status \(rHttp.statusCode) for \(targetURL.host ?? "")"
                        print(rMsg)
                        self.onLog?(rMsg)
                    }
                    self.sendProxyResponse(connection: connection, response: rResponse, data: rData, error: rError)
                }
                retryTask.resume()
                return
            }
            
            self.sendProxyResponse(connection: connection, response: response, data: data, error: error)
        }
        task.resume()
    }
    
    private func sendProxyResponse(connection: NWConnection, response: URLResponse?, data: Data?, error: Error?) {
        guard let httpResponse = response as? HTTPURLResponse, let data = data, error == nil else {
            let errLog = "[PROXY ERROR] Upstream request failed: \(error?.localizedDescription ?? "No data received")"
            print(errLog)
            onLog?(errLog)
            let errResp = "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n"
            let completion: NWConnection.SendCompletion = .contentProcessed { _ in connection.cancel() }
            connection.send(content: errResp.data(using: .utf8), completion: completion)
            return
        }
        
        let statusLog = "[PROXY UPSTREAM] HTTP \(httpResponse.statusCode) (\(data.count) bytes)"
        print(statusLog)
        onLog?(statusLog)
        
        // Clean Content-Type header (remove codecs parameter so AVPlayer parses it cleanly)
        let rawMime = httpResponse.mimeType ?? "audio/mp4"
        let cleanMime = rawMime.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? "audio/mp4"
        
        // Extract Content-Range header case-insensitively from upstream YouTube response
        var upstreamContentRange: String? = nil
        for (k, v) in httpResponse.allHeaderFields {
            if "\(k)".lowercased() == "content-range" {
                upstreamContentRange = "\(v)"
                break
            }
        }
        
        // Build HTTP response headers to return to AVPlayer
        var headerLines = [
            "HTTP/1.1 \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))",
            "Content-Type: \(cleanMime)",
            "Content-Length: \(data.count)",
            "Accept-Ranges: bytes",
            "Connection: close"
        ]
        
        // For 206 Partial Content, format/forward valid Content-Range header
        if httpResponse.statusCode == 206 {
            if let contentRange = upstreamContentRange {
                headerLines.append("Content-Range: \(contentRange)")
            } else if data.count > 0 {
                headerLines.append("Content-Range: bytes 0-\(data.count - 1)/*")
            }
        }
        
        guard let headerData = (headerLines.joined(separator: "\r\n") + "\r\n\r\n").data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        let headerCompletion: NWConnection.SendCompletion = .contentProcessed { _ in
            let bodyCompletion: NWConnection.SendCompletion = .contentProcessed { [weak self] _ in
                let succMsg = "[PROXY SUCCESS] Sent \(data.count) bytes of \(cleanMime) to AVPlayer (HTTP \(httpResponse.statusCode))"
                print(succMsg)
                self?.onLog?(succMsg)
                connection.cancel()
            }
            connection.send(content: data, completion: bodyCompletion)
        }
        connection.send(content: headerData, completion: headerCompletion)
    }
}
