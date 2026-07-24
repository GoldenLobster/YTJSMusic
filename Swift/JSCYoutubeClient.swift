// Swift/JSCYoutubeClient.swift
// High-level Swift client for running YouTube.js & YouTube Music inside iOS JavaScriptCore

import Foundation
import JavaScriptCore

public class JSCYoutubeClient: ObservableObject {
    public let context: JSContext
    public let bridge: JSCPolyfillBridge
    @Published public var isInitialized: Bool = false
    @Published public var lastLog: String = "Ready"
    
    public init() {
        guard let context = JSContext() else {
            fatalError("Failed to create JavaScriptCore JSContext")
        }
        self.context = context
        self.bridge = JSCPolyfillBridge(context: context)
        
        // Capture uncaught JS exceptions
        self.context.exceptionHandler = { [weak self] _, exception in
            let errMsg = exception?.toString() ?? "Unknown JS Exception"
            print("[JSC EXCEPTION] \(errMsg)")
            DispatchQueue.main.async {
                self?.lastLog = "[JS ERROR] \(errMsg)"
            }
        }
    }
    
    /// Loads all modular polyfills and the bundled runtime.bundle.js into JavaScriptCore
    public func loadPolyfillsAndBundle(polyfillScriptPaths: [String], bundlePath: String) throws {
        for path in polyfillScriptPaths {
            let script = try String(contentsOfFile: path, encoding: .utf8)
            context.evaluateScript(script, withSourceURL: URL(fileURLWithPath: path))
        }
        let bundleScript = try String(contentsOfFile: bundlePath, encoding: .utf8)
        context.evaluateScript(bundleScript, withSourceURL: URL(fileURLWithPath: bundlePath))
    }
    
    /// Initializes Innertube instance inside JavaScriptCore
    public func initializeInnertube(completion: @escaping (Result<Void, Error>) -> Void) {
        let script = """
        (async () => {
            if (!globalThis.Innertube) throw new Error("Innertube is not loaded on globalThis");
            globalThis.ytInstance = await Innertube.create({
                cache: new UniversalCache(false)
            });
            return true;
        })()
        """
        
        evaluatePromise(script: script) { [weak self] (result: Result<Bool, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isInitialized = true
                }
                completion(.success(()))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    /// Search YouTube Music specifically for official songs & tracks with High Quality album art
    public func searchMusic(query: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        (async () => {
            function upscaleThumbnail(url) {
                if (!url) return "";
                if (url.includes("googleusercontent.com") || url.includes("ggpht.com")) {
                    return url.replace(/=w\\d+-h\\d+[^=]*/, "=w512-h512-l90-rj");
                }
                if (url.includes("ytimg.com")) {
                    return url.replace("/default.jpg", "/hqdefault.jpg").replace("/sddefault.jpg", "/maxresdefault.jpg");
                }
                return url;
            }

            const results = await globalThis.ytInstance.music.search("\(escapedQuery)", { type: 'song' });
            const songs = results.songs?.contents || results.results || [];
            
            return songs.map(s => {
                let rawThumb = "";
                if (s.thumbnails && s.thumbnails.length > 0) {
                    rawThumb = s.thumbnails[s.thumbnails.length - 1].url || "";
                } else if (s.thumbnail?.url) {
                    rawThumb = s.thumbnail.url;
                }
                
                return {
                    id: s.id || "",
                    title: s.title || s.name || (s.title?.text || "Unknown Track"),
                    artist: s.artists ? s.artists.map(a => a.name).join(", ") : (s.author?.name || "Unknown Artist"),
                    album: s.album?.name || "",
                    duration: s.duration?.text || s.duration || "0:00",
                    thumbnail: upscaleThumbnail(rawThumb)
                };
            }).filter(s => s.id.length > 0);
        })()
        """
        evaluatePromise(script: script, completion: completion)
    }
    
    /// Get deciphered audio-only stream URL for a music track
    public func getAudioStreamUrl(videoId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let script = """
        (async () => {
            console.log("[JSC] getAudioStreamUrl for videoId:", "\(videoId)");
            const info = await globalThis.ytInstance.getInfo("\(videoId)", { client: 'IOS' });
            const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
            const regularFormats = info.streaming_data?.formats || [];
            const allFormats = [...adaptiveFormats, ...regularFormats];
            
            // Prefer AAC / M4A (audio/mp4) or Opus (audio/webm)
            let format = allFormats.find(f => f.has_audio && !f.has_video && (f.mime_type?.includes('mp4') || f.mime_type?.includes('m4a')));
            if (!format) {
                format = allFormats.find(f => f.has_audio && !f.has_video);
            }
            if (!format) {
                format = allFormats.find(f => f.has_audio);
            }
            
            if (!format) throw new Error("No audio format available for track ID " + "\(videoId)");
            
            let url = format.url;
            if (!url && format.decipher) {
                url = await format.decipher(globalThis.ytInstance.session.player);
            }
            
            console.log("[JSC] Stream URL resolved for", "\(videoId)", ":", url ? url.substring(0, 60) + "..." : "EMPTY");
            return url || "";
        })()
        """
        evaluatePromise(script: script, completion: completion)
    }
    
    // Helper to evaluate promise scripts in JSContext safely using JSValue callbacks
    private func evaluatePromise<T>(script: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let promiseVal = context.evaluateScript(script) else {
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to evaluate script"])))
            return
        }
        
        let onResolve: @convention(block) (JSValue) -> Void = { val in
            if let resultObj = val.toObject() as? T {
                completion(.success(resultObj))
            } else if T.self == String.self, let strVal = val.toString() as? T {
                completion(.success(strVal))
            } else if T.self == Bool.self {
                completion(.success(true as! T))
            } else {
                completion(.failure(NSError(domain: "JSCYoutubeClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to cast JS return value to expected type"])))
            }
        }
        
        let onReject: @convention(block) (JSValue) -> Void = { err in
            let errMsg = err.toString() ?? "Promise rejected in JSContext"
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -5, userInfo: [NSLocalizedDescriptionKey: errMsg])))
        }
        
        guard let resolveVal = JSValue(object: onResolve, in: context),
              let rejectVal = JSValue(object: onReject, in: context) else {
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSValue closure wrappers"])))
            return
        }
        
        promiseVal.invokeMethod("then", withArguments: [resolveVal])
        promiseVal.invokeMethod("catch", withArguments: [rejectVal])
    }
}
