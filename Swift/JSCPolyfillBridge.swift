// Swift/JSCPolyfillBridge.swift
// Native Swift Polyfill Bridge for iOS JavaScriptCore (JSContext)

import Foundation
import JavaScriptCore
import CryptoKit
import QuartzCore

public class JSCPolyfillBridge: NSObject {
    public weak var context: JSContext?
    public var onLog: ((String, String) -> Void)?
    
    // Timer state management
    private var activeTimers: [Int32: Timer] = [:]
    private var nextTimerId: Int32 = 1
    private let timerQueue = DispatchQueue(label: "com.antigravity.jsc.timers", attributes: .concurrent)
    
    public init(context: JSContext) {
        self.context = context
        super.init()
        registerNativeBridges()
    }
    
    /// Registers all Swift native functions onto JSContext
    public func registerNativeBridges() {
        guard let context = context else { return }
        
        // 1. Native Console Logging Bridge
        let nativeLog: @convention(block) (String, String) -> Void = { [weak self] level, message in
            print("[JSC-\(level)] \(message)")
            self?.onLog?(level, message)
        }
        context.setObject(nativeLog, forKeyedSubscript: "__nativeLog" as NSString)
        
        // 2. Native Network Fetch Bridge (URLSession)
        let nativeFetch: @convention(block) (NSDictionary) -> JSValue? = { [weak self] requestDict in
            guard let context = self?.context else { return nil }
            
            return JSValue(newPromiseIn: context) { resolve, reject in
                guard let urlString = requestDict["url"] as? String,
                      let url = URL(string: urlString) else {
                    reject?.call(withArguments: ["Invalid URL"])
                    return
                }
                
                var request = URLRequest(url: url)
                if let method = requestDict["method"] as? String {
                    request.httpMethod = method
                }
                
                // Parse headers from JS (supports both [[key, value]] array and [key: value] dict)
                if let headersArray = requestDict["headers"] as? [[String]] {
                    for pair in headersArray {
                        if pair.count >= 2 {
                            request.setValue(pair[1], forHTTPHeaderField: pair[0])
                        }
                    }
                } else if let headersDict = requestDict["headers"] as? [String: String] {
                    for (key, val) in headersDict {
                        request.setValue(val, forHTTPHeaderField: key)
                    }
                }
                
                // Parse request body from JS
                if let bodyData = requestDict["body"] as? [UInt8] {
                    request.httpBody = Data(bodyData)
                } else if let bodyStr = requestDict["body"] as? String {
                    request.httpBody = bodyStr.data(using: .utf8)
                }
                
                let logMsg = "[FETCH OUTGOING] \(request.httpMethod ?? "GET") \(urlString)"
                print(logMsg)
                self?.onLog?("LOG", logMsg)
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        let errLog = "[FETCH ERROR] \(urlString) -> \(error.localizedDescription)"
                        print(errLog)
                        self?.onLog?("ERROR", errLog)
                        reject?.call(withArguments: [error.localizedDescription])
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        reject?.call(withArguments: ["Invalid HTTP Response"])
                        return
                    }
                    
                    let statusCode = httpResponse.statusCode
                    let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    
                    if statusCode >= 400 {
                        let resText = data != nil ? String(data: data!, encoding: .utf8) ?? "" : ""
                        let resLog = "[FETCH HTTP \(statusCode)] \(urlString) -> \(resText.prefix(200))"
                        print(resLog)
                        self?.onLog?("WARN", resLog)
                    } else {
                        let resLog = "[FETCH HTTP \(statusCode)] \(urlString)"
                        print(resLog)
                        self?.onLog?("LOG", resLog)
                    }
                    
                    // Parse response headers into array of [key, value] pairs
                    var headersArray: [[String]] = []
                    for (k, v) in httpResponse.allHeaderFields {
                        headersArray.append(["\(k)", "\(v)"])
                    }
                    
                    // Convert body data into byte array
                    let bodyBytes: [UInt8] = data != nil ? Array(data!) : []
                    
                    let responsePayload: [String: Any] = [
                        "status": statusCode,
                        "statusText": statusText,
                        "headers": headersArray,
                        "body": bodyBytes
                    ]
                    
                    resolve?.call(withArguments: [responsePayload])
                }
                task.resume()
            }
        }
        context.setObject(nativeFetch, forKeyedSubscript: "__nativeFetch" as NSString)
        
        // 3. Hardware Randomness (SecRandomCopyBytes)
        let nativeGetRandomValues: @convention(block) (Int) -> [UInt8] = { count in
            var bytes = [UInt8](repeating: 0, count: count)
            let result = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
            if result == errSecSuccess {
                return bytes
            } else {
                return (0..<count).map { _ in UInt8.random(in: 0...255) }
            }
        }
        context.setObject(nativeGetRandomValues, forKeyedSubscript: "__nativeGetRandomValues" as NSString)
        
        let nativeRandomUUID: @convention(block) () -> String = {
            return UUID().uuidString.lowercased()
        }
        context.setObject(nativeRandomUUID, forKeyedSubscript: "__nativeRandomUUID" as NSString)
        
        // 4. WebCrypto Digest & Sign via CryptoKit
        let nativeSubtleDigest: @convention(block) (String, [UInt8]) -> JSValue? = { [weak self] algo, bytes in
            guard let context = self?.context else { return nil }
            return JSValue(newPromiseIn: context) { resolve, reject in
                let data = Data(bytes)
                var digestBytes: [UInt8] = []
                
                switch algo.uppercased() {
                case "SHA1", "SHA-1":
                    let hash = Insecure.SHA1.hash(data: data)
                    digestBytes = Array(hash)
                case "SHA256", "SHA-256":
                    let hash = SHA256.hash(data: data)
                    digestBytes = Array(hash)
                case "SHA384", "SHA-384":
                    let hash = SHA384.hash(data: data)
                    digestBytes = Array(hash)
                case "SHA512", "SHA-512":
                    let hash = SHA512.hash(data: data)
                    digestBytes = Array(hash)
                default:
                    reject?.call(withArguments: ["Unsupported algorithm: \(algo)"])
                    return
                }
                resolve?.call(withArguments: [digestBytes])
            }
        }
        context.setObject(nativeSubtleDigest, forKeyedSubscript: "__nativeSubtleDigest" as NSString)
        
        let nativeSubtleSign: @convention(block) (String, [UInt8], [UInt8]) -> JSValue? = { [weak self] algo, keyBytes, dataBytes in
            guard let context = self?.context else { return nil }
            return JSValue(newPromiseIn: context) { resolve, reject in
                let key = SymmetricKey(data: Data(keyBytes))
                let data = Data(dataBytes)
                var macBytes: [UInt8] = []
                
                switch algo.uppercased() {
                case "SHA256", "SHA-256", "HMAC-SHA256":
                    let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
                    macBytes = Array(mac)
                case "SHA384", "SHA-384", "HMAC-SHA384":
                    let mac = HMAC<SHA384>.authenticationCode(for: data, using: key)
                    macBytes = Array(mac)
                case "SHA512", "SHA-512", "HMAC-SHA512":
                    let mac = HMAC<SHA512>.authenticationCode(for: data, using: key)
                    macBytes = Array(mac)
                default:
                    reject?.call(withArguments: ["Unsupported HMAC algorithm: \(algo)"])
                    return
                }
                resolve?.call(withArguments: [macBytes])
            }
        }
        context.setObject(nativeSubtleSign, forKeyedSubscript: "__nativeSubtleSign" as NSString)
        
        // 5. Native Async Timers (DispatchQueue & Timer)
        let nativeSetTimeout: @convention(block) (JSValue, Double) -> Int32 = { [weak self] callback, ms in
            guard let self = self else { return 0 }
            var timerId: Int32 = 0
            self.timerQueue.sync(flags: .barrier) {
                self.nextTimerId += 1
                timerId = self.nextTimerId
            }
            let interval = max(ms / 1000.0, 0.001)
            
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
                    callback.call(withArguments: [])
                    self.timerQueue.async(flags: .barrier) {
                        self.activeTimers.removeValue(forKey: timerId)
                    }
                }
                self.timerQueue.async(flags: .barrier) {
                    self.activeTimers[timerId] = timer
                }
            }
            return timerId
        }
        context.setObject(nativeSetTimeout, forKeyedSubscript: "__nativeSetTimeout" as NSString)
        
        let nativeClearTimeout: @convention(block) (Int32) -> Void = { [weak self] timerId in
            guard let self = self else { return }
            self.timerQueue.async(flags: .barrier) {
                if let timer = self.activeTimers[timerId] {
                    DispatchQueue.main.async { timer.invalidate() }
                    self.activeTimers.removeValue(forKey: timerId)
                }
            }
        }
        context.setObject(nativeClearTimeout, forKeyedSubscript: "__nativeClearTimeout" as NSString)
        
        let nativeSetInterval: @convention(block) (JSValue, Double) -> Int32 = { [weak self] callback, ms in
            guard let self = self else { return 0 }
            var timerId: Int32 = 0
            self.timerQueue.sync(flags: .barrier) {
                self.nextTimerId += 1
                timerId = self.nextTimerId
            }
            let interval = max(ms / 1000.0, 0.001)
            
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    callback.call(withArguments: [])
                }
                self.timerQueue.async(flags: .barrier) {
                    self.activeTimers[timerId] = timer
                }
            }
            return timerId
        }
        context.setObject(nativeSetInterval, forKeyedSubscript: "__nativeSetInterval" as NSString)
        
        let nativeClearInterval: @convention(block) (Int32) -> Void = { [weak self] timerId in
            guard let self = self else { return }
            self.timerQueue.async(flags: .barrier) {
                if let timer = self.activeTimers[timerId] {
                    DispatchQueue.main.async { timer.invalidate() }
                    self.activeTimers.removeValue(forKey: timerId)
                }
            }
        }
        context.setObject(nativeClearInterval, forKeyedSubscript: "__nativeClearInterval" as NSString)
        
        // 6. High-Resolution Clock (CACurrentMediaTime)
        let nativePerformanceNow: @convention(block) () -> Double = {
            return CACurrentMediaTime() * 1000.0
        }
        context.setObject(nativePerformanceNow, forKeyedSubscript: "__nativePerformanceNow" as NSString)
    }
}
