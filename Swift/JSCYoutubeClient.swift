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
                    self?.onLog?("LOG", "Search callback successfully decoded \(tracks.count) tracks")
                    print("[SEARCH LOG] Search callback successfully decoded \(tracks.count) tracks")
                    completion(.success(tracks))
                } else if !errMsg.isEmpty {
                    self?.onLog?("ERROR", "Search callback error: \(errMsg)")
                    print("[SEARCH ERROR] Search callback error: \(errMsg)")
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -11, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    self?.onLog?("WARN", "Search callback returned no tracks")
                    print("[SEARCH WARN] Search callback returned no tracks")
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -12, userInfo: [NSLocalizedDescriptionKey: "Search returned no tracks"])))
                }
            }
        }
        context.setObject(nativeSearchCB, forKeyedSubscript: "__nativeCompleteSearch" as NSString)
        
        let script = """
        (async () => {
            try {
                console.log("[JSC] Searching music for query: '\(escapedQuery)'");
                let items = [];
                
                try {
                    const musicRes = await globalThis.ytInstance.music.search("\(escapedQuery)", { type: 'song' });
                    if (musicRes.songs && Array.isArray(musicRes.songs) && musicRes.songs.length > 0) {
                        items = musicRes.songs;
                    } else if (musicRes.contents) {
                        const shelves = Array.isArray(musicRes.contents) ? musicRes.contents : [musicRes.contents];
                        for (const shelf of shelves) {
                            if (shelf.contents && Array.isArray(shelf.contents)) {
                                items.push(...shelf.contents);
                            } else if (shelf.items && Array.isArray(shelf.items)) {
                                items.push(...shelf.items);
                            }
                        }
                    }
                } catch (e) {
                    console.log("[JSC] music.search error, trying general search fallback:", e.message);
                }
                
                if (!items || items.length === 0) {
                    console.log("[JSC] Performing general YouTube search fallback...");
                    const genRes = await globalThis.ytInstance.search("\(escapedQuery)");
                    if (genRes.videos && Array.isArray(genRes.videos)) {
                        items = genRes.videos;
                    } else if (genRes.results && Array.isArray(genRes.results)) {
                        items = genRes.results;
                    }
                }
                
                console.log("[JSC] Extracted raw items count:", items ? items.length : 0);
                
                const tracks = [];
                if (items && Array.isArray(items)) {
                    for (const item of items) {
                        const id = item.id || item.video_id;
                        if (!id) continue;
                        
                        let titleStr = "";
                        if (typeof item.title === 'string') {
                            titleStr = item.title;
                        } else if (item.title && item.title.text) {
                            titleStr = item.title.text;
                        } else if (item.title && item.title.toString) {
                            titleStr = item.title.toString();
                        }
                        
                        if (!titleStr) continue;
                        
                        let artistStr = "Unknown Artist";
                        if (item.author) {
                            if (typeof item.author === 'string') {
                                artistStr = item.author;
                            } else if (item.author.name) {
                                artistStr = item.author.name;
                            }
                        } else if (item.artists && Array.isArray(item.artists) && item.artists.length > 0) {
                            artistStr = item.artists.map(a => a.name || a.text || "").filter(Boolean).join(", ");
                        }
                        
                        let albumTitle = "YouTube Music";
                        if (item.album && item.album.name) {
                            albumTitle = item.album.name;
                        }
                        
                        let durationStr = "0:00";
                        if (item.duration && item.duration.text) {
                            durationStr = item.duration.text;
                        } else if (item.length_text && item.length_text.text) {
                            durationStr = item.length_text.text;
                        } else if (typeof item.duration === 'string') {
                            durationStr = item.duration;
                        }
                        
                        let thumbUrl = "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg";
                        if (item.thumbnails && Array.isArray(item.thumbnails) && item.thumbnails.length > 0) {
                            const best = item.thumbnails[item.thumbnails.length - 1];
                            thumbUrl = best.url || thumbUrl;
                        }
                        
                        tracks.push({
                            id: id,
                            title: titleStr,
                            artist: artistStr,
                            album: albumTitle,
                            duration: durationStr,
                            thumbnail: thumbUrl
                        });
                    }
                }
                
                console.log("[JSC] Transformed valid search tracks count:", tracks.length);
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
                    self?.onLog?("LOG", "Resolved audio stream URL successfully (\(streamUrl.count) chars)")
                    print("[STREAM LOG] Resolved audio stream URL successfully (\(streamUrl.count) chars)")
                    completion(.success(streamUrl))
                } else {
                    self?.onLog?("ERROR", "Stream URL resolution error: \(errMsg)")
                    print("[STREAM ERROR] Stream URL resolution error: \(errMsg)")
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
                
                let streamUrl = format.url;
                if (!streamUrl && typeof format.decipher === 'function') {
                    console.log("[JSC] format.url missing, deciphering format signature with player...");
                    try {
                        const player = await globalThis.ytInstance.session.player;
                        streamUrl = await format.decipher(player);
                    } catch (e) {
                        console.log("[JSC WARN] Decipher fallback failed:", e.message);
                    }
                }
                
                if (!streamUrl) {
                    throw new Error("Failed to resolve stream URL for track ID: " + "\(videoId)");
                }
                
                console.log("[JSC] Stream URL resolved successfully, length:", streamUrl.length);
                __nativeCompleteStream(streamUrl, "");
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
