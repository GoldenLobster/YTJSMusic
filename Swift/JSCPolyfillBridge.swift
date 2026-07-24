// Swift/JSCPolyfillBridge.swift
// Native Swift backend backing JavaScriptCore polyfills for YouTube.js on iOS / macOS

import Foundation
import JavaScriptCore
import CryptoKit
import Security

#if canImport(QuartzCore)
import QuartzCore
#endif

@objc public protocol JSCPolyfillBridgeJSExport: JSExport {
    // JS context native bridge declarations if needed
}

/// Native Swift Bridge providing underlying OS capabilities (Networking, Crypto, Timers, Clock)
/// to the JavaScriptCore context for running YouTube.js (youtubei.js).
public class JSCPolyfillBridge: NSObject {
    public weak var context: JSContext?
    private var activeTimers: [Int: Timer] = [:]
    private var timerCounter: Int = 0
    private let timerLock = NSLock()
    
    public init(context: JSContext) {
        self.context = context
        super.init()
        setupNativeBridges()
    }
    
    public func setupNativeBridges() {
        guard let context = context else { return }
        
        // 1. Native Console Logger
        let nativeLog: @convention(block) (String, String) -> Void = { level, message in
            print("[JSC-\(level)] \(message)")
        }
        context.setObject(nativeLog, forKeyedSubscript: "__nativeLog" as NSString)
        
        // 2. Native Network Fetcher using URLSession
        let nativeFetch: @convention(block) (JSValue) -> JSValue? = { [weak self] paramsVal in
            guard let context = self?.context,
                  let dict = paramsVal.toDictionary(),
                  let urlString = dict["url"] as? String,
                  let url = URL(string: urlString) else {
                return nil
            }
            
            let method = (dict["method"] as? String) ?? "GET"
            var request = URLRequest(url: url)
            request.httpMethod = method
            
            if let headersArray = dict["headers"] as? [[Any]] {
                for pair in headersArray {
                    if pair.count >= 2, let k = pair[0] as? String, let v = pair[1] as? String {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                }
            }
            
            if let bodyString = dict["body"] as? String {
                request.httpBody = bodyString.data(using: .utf8)
            } else if let bodyBytes = dict["body"] as? [UInt8] {
                request.httpBody = Data(bodyBytes)
            }
            
            return JSValue(newPromiseIn: context) { resolve, reject in
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        reject?.call(withArguments: [error.localizedDescription])
                        return
                    }
                    
                    let httpRes = response as? HTTPURLResponse
                    let status = httpRes?.statusCode ?? 200
                    
                    var resHeaders: [[String]] = []
                    if let allHeaderFields = httpRes?.allHeaderFields {
                        for (k, v) in allHeaderFields {
                            resHeaders.append(["\(k)", "\(v)"])
                        }
                    }
                    
                    var bodyBytes: [UInt8] = []
                    if let data = data {
                        bodyBytes = [UInt8](data)
                    }
                    
                    let responseDict: [String: Any] = [
                        "status": status,
                        "statusText": HTTPURLResponse.localizedString(forStatusCode: status),
                        "headers": resHeaders,
                        "body": bodyBytes
                    ]
                    
                    resolve?.call(withArguments: [responseDict])
                }
                task.resume()
            }
        }
        context.setObject(nativeFetch, forKeyedSubscript: "__nativeFetch" as NSString)
        
        // 3. Native Cryptography: SecRandomCopyBytes & UUID
        let nativeGetRandomValues: @convention(block) (Int) -> [UInt8] = { byteLength in
            var bytes = [UInt8](repeating: 0, count: byteLength)
            let status = SecRandomCopyBytes(kSecRandomDefault, byteLength, &bytes)
            if status != errSecSuccess {
                // Fallback to SystemRandomNumberGenerator
                var rng = SystemRandomNumberGenerator()
                for i in 0..<byteLength {
                    bytes[i] = UInt8.random(in: 0...255, using: &rng)
                }
            }
            return bytes
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
                    let mac = HMAC<SHA256>.signature(for: data, using: key)
                    macBytes = Array(mac)
                case "SHA384", "SHA-384", "HMAC-SHA384":
                    let mac = HMAC<SHA384>.signature(for: data, using: key)
                    macBytes = Array(mac)
                case "SHA512", "SHA-512", "HMAC-SHA512":
                    let mac = HMAC<SHA512>.signature(for: data, using: key)
                    macBytes = Array(mac)
                default:
                    reject?.call(withArguments: ["Unsupported HMAC algorithm: \(algo)"])
                    return
                }
                resolve?.call(withArguments: [macBytes])
            }
        }
        context.setObject(nativeSubtleSign, forKeyedSubscript: "__nativeSubtleSign" as NSString)
        
        // 5. Native Timers (setTimeout, clearTimeout, setInterval, clearInterval)
        let nativeSetTimeout: @convention(block) (JSValue, Double) -> Int = { [weak self] callback, delayMs in
            guard let self = self else { return 0 }
            self.timerLock.lock()
            self.timerCounter += 1
            let id = self.timerCounter
            self.timerLock.unlock()
            
            let seconds = max(0.001, delayMs / 1000.0)
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                    callback.call(withArguments: [])
                    self?.clearTimer(id: id)
                }
                self.timerLock.lock()
                self.activeTimers[id] = timer
                self.timerLock.unlock()
            }
            return id
        }
        context.setObject(nativeSetTimeout, forKeyedSubscript: "__nativeSetTimeout" as NSString)
        
        let nativeClearTimeout: @convention(block) (Int) -> Void = { [weak self] id in
            self?.clearTimer(id: id)
        }
        context.setObject(nativeClearTimeout, forKeyedSubscript: "__nativeClearTimeout" as NSString)
        
        let nativeSetInterval: @convention(block) (JSValue, Double) -> Int = { [weak self] callback, delayMs in
            guard let self = self else { return 0 }
            self.timerLock.lock()
            self.timerCounter += 1
            let id = self.timerCounter
            self.timerLock.unlock()
            
            let seconds = max(0.001, delayMs / 1000.0)
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
                    callback.call(withArguments: [])
                }
                self.timerLock.lock()
                self.activeTimers[id] = timer
                self.timerLock.unlock()
            }
            return id
        }
        context.setObject(nativeSetInterval, forKeyedSubscript: "__nativeSetInterval" as NSString)
        
        let nativeClearInterval: @convention(block) (Int) -> Void = { [weak self] id in
            self?.clearTimer(id: id)
        }
        context.setObject(nativeClearInterval, forKeyedSubscript: "__nativeClearInterval" as NSString)
        
        // 6. High-Precision Performance Clock
        let nativePerformanceNow: @convention(block) () -> Double = {
            #if canImport(QuartzCore)
            return CACurrentMediaTime() * 1000.0
            #else
            return Date().timeIntervalSince1970 * 1000.0
            #endif
        }
        context.setObject(nativePerformanceNow, forKeyedSubscript: "__nativePerformanceNow" as NSString)
    }
    
    private func clearTimer(id: Int) {
        timerLock.lock()
        defer { timerLock.unlock() }
        if let timer = activeTimers[id] {
            timer.invalidate()
            activeTimers.removeValue(forKey: id)
        }
    }
}
