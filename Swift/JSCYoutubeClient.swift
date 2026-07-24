// Swift/JSCYoutubeClient.swift
import Foundation
import JavaScriptCore

public class JSCYoutubeClient: ObservableObject {
    private let context: JSContext
    private let bridge: JSCPolyfillBridge
    
    @Published public var isReady: Bool = false
    @Published public var lastError: String? = nil
    
    public init() {
        self.context = JSContext()!
        self.bridge = JSCPolyfillBridge(context: context)
    }
    
    public func loadPolyfillsAndBundle(polyfillScriptPaths: [String], bundlePath: String) throws {
        bridge.setupPolyfills()
        
        for path in polyfillScriptPaths {
            guard let script = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            context.evaluateScript(script, withSourceURL: URL(fileURLWithPath: path))
        }
        
        guard let bundleScript = try? String(contentsOfFile: bundlePath, encoding: .utf8) else {
            throw NSError(domain: "JSCYoutubeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read runtime.bundle.js from path: \(bundlePath)"])
        }
        
        context.evaluateScript(bundleScript, withSourceURL: URL(fileURLWithPath: bundlePath))
    }
    
    public func initializeInnertube(completion: @escaping (Result<Void, Error>) -> Void) {
        let script = """
        (async () => {
            if (globalThis.ytInstance) return true;
            console.log("[JSC] Creating Innertube instance...");
            globalThis.ytInstance = await Innertube.create({
                cache: new UniversalCache(false)
            });
            console.log("[JSC] Pre-fetching YouTube player script...");
            await globalThis.ytInstance.session.player;
            console.log("[JSC] Innertube initialized successfully!");
            return true;
        })()
        """
        
        evaluatePromise(script: script) { (result: Result<Bool, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isReady = true
                    completion(.success(()))
                case .failure(let error):
                    self.lastError = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func searchMusic(query: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (async () => {
            console.log("[JSC] Searching music for query: '\(escapedQuery)'");
            const searchResults = await globalThis.ytInstance.music.search("\(escapedQuery)", { type: 'song' });
            const contents = searchResults.results || searchResults.contents || [];
            
            const tracks = [];
            for (const item of contents) {
                if (!item.id || !item.title) continue;
                
                let thumbUrl = "https://i.ytimg.com/vi/" + item.id + "/hqdefault.jpg";
                if (item.thumbnails && item.thumbnails.length > 0) {
                    const bestThumb = item.thumbnails[item.thumbnails.length - 1];
                    thumbUrl = bestThumb.url || thumbUrl;
                    if (thumbUrl.includes('=w') || thumbUrl.includes('=h')) {
                        thumbUrl = thumbUrl.replace(/=w\\d+-h\\d+[^&]*/, '=w512-h512-l90-rj');
                    }
                }
                
                let artistName = "Unknown Artist";
                if (item.artists && item.artists.length > 0) {
                    artistName = item.artists.map(a => a.name).join(", ");
                } else if (item.author) {
                    artistName = typeof item.author === 'string' ? item.author : (item.author.name || "Unknown Artist");
                }
                
                let albumTitle = "Single";
                if (item.album && item.album.name) {
                    albumTitle = item.album.name;
                }
                
                let durationStr = "0:00";
                if (item.duration && item.duration.text) {
                    durationStr = item.duration.text;
                } else if (item.duration && typeof item.duration === 'string') {
                    durationStr = item.duration;
                }
                
                tracks.push({
                    id: item.id,
                    title: item.title,
                    artist: artistName,
                    album: albumTitle,
                    duration: durationStr,
                    thumbnail: thumbUrl
                });
            }
            console.log("[JSC] Transformed search tracks count:", tracks.length);
            return tracks;
        })()
        """
        
        evaluatePromise(script: script, completion: completion)
    }
    
    public func getAudioStreamUrl(videoId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let script = """
        (async () => {
            console.log("[JSC] Fetching getBasicInfo for videoId: '\(videoId)'...");
            let info;
            try {
                info = await globalThis.ytInstance.getBasicInfo("\(videoId)", { client: 'IOS' });
            } catch (e) {
                console.log("[JSC] IOS client failed, falling back to ANDROID client:", e.message);
                info = await globalThis.ytInstance.getBasicInfo("\(videoId)", { client: 'ANDROID' });
            }
            
            const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
            const regularFormats = info.streaming_data?.formats || [];
            const allFormats = [...adaptiveFormats, ...regularFormats];
            
            console.log("[JSC] Total formats found:", allFormats.length);
            
            // Prefer AAC / M4A (audio/mp4) or Opus (audio/webm)
            let format = allFormats.find(f => f.has_audio && !f.has_video && (f.mime_type?.includes('mp4') || f.mime_type?.includes('m4a')));
            if (!format) {
                format = allFormats.find(f => f.has_audio && !f.has_video);
            }
            if (!format) {
                format = allFormats.find(f => f.has_audio);
            }
            
            if (!format) {
                throw new Error("No audio format available for track ID: " + "\(videoId)");
            }
            
            let url = format.url;
            if (format.decipher) {
                try {
                    const player = await globalThis.ytInstance.session.player;
                    url = await format.decipher(player);
                } catch (e) {
                    console.log("[JSC] Decipher fallback:", e.message);
                }
            }
            
            if (!url) {
                throw new Error("Resolved format has no playable URL for track ID: " + "\(videoId)");
            }
            
            console.log("[JSC] Stream URL resolved successfully, length:", url.length);
            return url;
        })()
        """
        evaluatePromise(script: script, completion: completion)
    }
    
    // Helper to evaluate promise scripts in JSContext safely using JSValue callbacks
    private func evaluatePromise<T>(script: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let promiseVal = context.evaluateScript(script) else {
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to evaluate script in JSContext"])))
            return
        }
        
        let onResolve: @convention(block) (JSValue) -> Void = { val in
            if let resultObj = val.toObject() as? T {
                completion(.success(resultObj))
            } else if T.self == String.self, let strVal = val.toString() as? T {
                completion(.success(strVal))
            } else if T.self == Bool.self {
                completion(.success(true as! T))
            } else if let jsonStr = context.evaluateScript("JSON.stringify")?.call(withArguments: [val])?.toString(),
                      let jsonData = jsonStr.data(using: .utf8),
                      let decoded = try? JSONDecoder().decode(T.self, from: jsonData) {
                completion(.success(decoded))
            } else {
                completion(.failure(NSError(domain: "JSCYoutubeClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSValue to type \(T.self)"])))
            }
        }
        
        let onReject: @convention(block) (JSValue) -> Void = { err in
            let errMsg = err.objectForKeyedSubscript("message")?.toString() ?? err.toString() ?? "JS Promise Rejected"
            let errStack = err.objectForKeyedSubscript("stack")?.toString() ?? ""
            print("[JSC PROMISE REJECTED] Error:", errMsg, "\nStack:", errStack)
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -5, userInfo: [NSLocalizedDescriptionKey: errMsg])))
        }
        
        let onResolveVal = JSValue(object: onResolve, in: context)
        let onRejectVal = JSValue(object: onReject, in: context)
        
        if let thenFunc = promiseVal.objectForKeyedSubscript("then"), thenFunc.isObject {
            thenFunc.call(withArguments: [onResolveVal, onRejectVal])
        } else {
            completion(.failure(NSError(domain: "JSCYoutubeClient", code: -6, userInfo: [NSLocalizedDescriptionKey: "Evaluated script did not return a Promise"])))
        }
    }
}

// Model representing search result track
public struct Track: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: String
    public let thumbnail: String
}
