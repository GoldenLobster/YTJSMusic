// Swift/JSCYoutubeClient.swift
// High-level Swift client for running YouTube.js & YouTube Music inside iOS JavaScriptCore

import Foundation
import JavaScriptCore

public class JSCYoutubeClient {
    public let context: JSContext
    public let bridge: JSCPolyfillBridge
    private var isInitialized: Bool = false
    
    public init() {
        guard let context = JSContext() else {
            fatalError("Failed to create JavaScriptCore JSContext")
        }
        self.context = context
        self.bridge = JSCPolyfillBridge(context: context)
    }
    
    /// Loads all modular polyfills and the bundled runtime.bundle.js into JavaScriptCore
    public func loadPolyfillsAndBundle(polyfillScriptPaths: [String], bundlePath: String) throws {
        // Load polyfills in order
        for path in polyfillScriptPaths {
            let script = try String(contentsOfFile: path, encoding: .utf8)
            context.evaluateScript(script, withSourceURL: URL(fileURLWithPath: path))
        }
        
        // Load YouTube.js runtime bundle
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
        
        guard let promiseVal = context.evaluateScript(script) else {
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to evaluate Innertube initialization"])))
            return
        }
        
        let onResolve: @convention(block) (JSValue) -> Void = { _ in
            self.isInitialized = true
            completion(.success(()))
        }
        
        let onReject: @convention(block) (JSValue) -> Void = { err in
            let errMsg = err.toString() ?? "Unknown error during Innertube initialization"
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -2, userInfo: [NSLocalizedDescriptionKey: errMsg])))
        }
        
        let thenFn = promiseVal.objectForKeyedSubscript("then")
        let catchFn = promiseVal.objectForKeyedSubscript("catch")
        thenFn?.call(withArguments: [unsafeBitCast(onResolve, to: AnyObject.self)])
        catchFn?.call(withArguments: [unsafeBitCast(onReject, to: AnyObject.self)])
    }
    
    /// Search YouTube Music specifically for official songs & tracks
    public func searchMusic(query: String, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        (async () => {
            const results = await globalThis.ytInstance.music.search("\(escapedQuery)", { type: 'song' });
            const songs = results.songs?.contents || results.results || [];
            
            return songs.map(s => {
                let thumbnail = "";
                if (s.thumbnails && s.thumbnails.length > 0) {
                    thumbnail = s.thumbnails[s.thumbnails.length - 1].url || "";
                } else if (s.thumbnail?.url) {
                    thumbnail = s.thumbnail.url;
                }
                
                return {
                    id: s.id || "",
                    title: s.title || s.name || (s.title?.text || "Unknown Track"),
                    artist: s.artists ? s.artists.map(a => a.name).join(", ") : (s.author?.name || "Unknown Artist"),
                    album: s.album?.name || "",
                    duration: s.duration?.text || s.duration || "0:00",
                    thumbnail: thumbnail
                };
            }).filter(s => s.id.length > 0);
        })()
        """
        evaluatePromise(script, completion: completion)
    }
    
    /// Get deciphered audio-only stream URL for a music track
    public func getAudioStreamUrl(videoId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let script = """
        (async () => {
            const info = await globalThis.ytInstance.getInfo("\(videoId)", { client: 'IOS' });
            const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
            
            // Prefer AAC / M4A (audio/mp4) or Opus (audio/webm)
            let format = adaptiveFormats.find(f => f.has_audio && !f.has_video && f.mime_type.includes('mp4'));
            if (!format) {
                format = adaptiveFormats.find(f => f.has_audio && !f.has_video);
            }
            
            if (!format) throw new Error("No audio format available for video " + "\(videoId)");
            
            let url = format.url;
            if (!url && format.decipher) {
                url = await format.decipher(globalThis.ytInstance.session.player);
            }
            
            return url || "";
        })()
        """
        evaluatePromise(script, completion: completion)
    }
    
    // Helper to evaluate promise scripts in JSContext
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
            } else {
                completion(.failure(NSError(domain: "JSCYoutubeClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to cast JS return value to expected type"])))
            }
        }
        
        let onReject: @convention(block) (JSValue) -> Void = { err in
            let errMsg = err.toString() ?? "Promise rejected in JSContext"
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -5, userInfo: [NSLocalizedDescriptionKey: errMsg])))
        }
        
        let thenFn = promiseVal.objectForKeyedSubscript("then")
        let catchFn = promiseVal.objectForKeyedSubscript("catch")
        thenFn?.call(withArguments: [unsafeBitCast(onResolve, to: AnyObject.self)])
        catchFn?.call(withArguments: [unsafeBitCast(onReject, to: AnyObject.self)])
    }
}
