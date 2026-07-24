// Swift/JSCYoutubeClient.swift
import Foundation
import JavaScriptCore

public class JSCYoutubeClient: ObservableObject {
    private let context: JSContext
    private let bridge: JSCPolyfillBridge
    
    @Published public var isReady: Bool = false
    @Published public var lastError: String? = nil
    
    public var onLog: ((String, String) -> Void)? {
        didSet {
            bridge.onLog = onLog
        }
    }
    
    public init() {
        self.context = JSContext()!
        self.bridge = JSCPolyfillBridge(context: context)
    }
    
    public func loadPolyfillsAndBundle(polyfillScriptPaths: [String], bundlePath: String) throws {
        bridge.registerNativeBridges()
        
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
        let nativeInitCB: @convention(block) (Bool, String) -> Void = { [weak self] success, errMsg in
            DispatchQueue.main.async {
                if success {
                    self?.isReady = true
                    self?.onLog?("LOG", "Native init callback success! Launching UI...")
                    completion(.success(()))
                } else {
                    self?.lastError = errMsg
                    self?.onLog?("ERROR", "Native init callback failed: \(errMsg)")
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -10, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                }
            }
        }
        context.setObject(nativeInitCB, forKeyedSubscript: "__nativeCompleteInit" as NSString)
        
        let script = """
        (async () => {
            try {
                if (!globalThis.ytInstance) {
                    console.log("[JSC] Creating Innertube instance...");
                    globalThis.ytInstance = await Innertube.create({
                        cache: new UniversalCache(false)
                    });
                    console.log("[JSC] Innertube initialized successfully!");
                }
                __nativeCompleteInit(true, "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] Innertube initialization failed:", msg);
                __nativeCompleteInit(false, msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
    
    public func searchMusic(query: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
        
        let nativeSearchCB: @convention(block) (String, String) -> Void = { [weak self] jsonStr, errMsg in
            DispatchQueue.main.async {
                if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let tracks = try? JSONDecoder().decode([Track].self, from: data) {
                    completion(.success(tracks))
                } else if !errMsg.isEmpty {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -11, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -12, userInfo: [NSLocalizedDescriptionKey: "Search returned no tracks"])))
                }
            }
        }
        context.setObject(nativeSearchCB, forKeyedSubscript: "__nativeCompleteSearch" as NSString)
        
        let script = """
        (async () => {
            try {
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
                __nativeCompleteSearch(JSON.stringify(tracks), "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] Search failed:", msg);
                __nativeCompleteSearch("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
    
    public func getAudioStreamUrl(videoId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let nativeStreamCB: @convention(block) (String, String) -> Void = { [weak self] streamUrl, errMsg in
            DispatchQueue.main.async {
                if !streamUrl.isEmpty {
                    completion(.success(streamUrl))
                } else {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -13, userInfo: [NSLocalizedDescriptionKey: errMsg.isEmpty ? "Failed to resolve stream URL" : errMsg])))
                }
            }
        }
        context.setObject(nativeStreamCB, forKeyedSubscript: "__nativeCompleteStream" as NSString)
        
        let script = """
        (async () => {
            try {
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
                __nativeCompleteStream(url, "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] Stream URL resolution failed:", msg);
                __nativeCompleteStream("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
}
