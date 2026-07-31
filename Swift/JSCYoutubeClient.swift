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
                if (!globalThis.amInstance && globalThis.AppleMusic) {
                    console.log("[JSC] Creating AppleMusic client instance...");
                    globalThis.amInstance = new globalThis.AppleMusic({ region: globalThis.Region.US, authType: globalThis.AuthType.Scraped });
                    await globalThis.amInstance.init();
                    console.log("[JSC] AppleMusic initialized successfully!");
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
                        
                        let thumbs = [];
                        if (item.thumbnail && item.thumbnail.contents && Array.isArray(item.thumbnail.contents)) {
                            thumbs = item.thumbnail.contents;
                        } else if (item.thumbnails && Array.isArray(item.thumbnails)) {
                            thumbs = item.thumbnails;
                        } else if (item.thumbnail && Array.isArray(item.thumbnail)) {
                            thumbs = item.thumbnail;
                        }
                        
                        let thumbUrl = "";
                        if (thumbs.length > 0) {
                            const sorted = [...thumbs].sort((a, b) => (b.width || 0) - (a.width || 0));
                            thumbUrl = sorted[0].url || "";
                        }
                        
                        if (!thumbUrl) {
                            thumbUrl = "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg";
                        }
                        
                        // Upgrade Google / YouTube Music thumbnail dimensions to crisp 544x544 high-resolution artwork
                        if (thumbUrl.includes("googleusercontent.com") || thumbUrl.includes("ggpht.com")) {
                            thumbUrl = thumbUrl.split("=")[0] + "=w544-h544-l90-rj";
                        } else if (thumbUrl.includes("i.ytimg.com") || thumbUrl.includes("ytimg.com")) {
                            if (!thumbUrl.includes("hqdefault.jpg") && !thumbUrl.includes("maxresdefault.jpg")) {
                                thumbUrl = "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg";
                            }
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
                    info = await globalThis.ytInstance.getBasicInfo("\(videoId)", { client: 'ANDROID_VR' });
                } catch (e) {
                    console.log("[JSC] ANDROID_VR client failed, falling back to IOS client:", e.message);
                    try {
                        info = await globalThis.ytInstance.getBasicInfo("\(videoId)", { client: 'IOS' });
                    } catch (e2) {
                        console.log("[JSC] IOS client failed, falling back to YTMUSIC client:", e2.message);
                        info = await globalThis.ytInstance.getBasicInfo("\(videoId)", { client: 'YTMUSIC' });
                    }
                }
                
                const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
                const regularFormats = info.streaming_data?.formats || [];
                const allFormats = [...adaptiveFormats, ...regularFormats];
                
                console.log("[JSC] Total formats found:", allFormats.length);
                
                // Filter for audio-only MP4/M4A (AAC) formats natively supported by AVPlayer
                const m4aAudioFormats = allFormats.filter(f => f.has_audio && !f.has_video && (f.mime_type?.includes('mp4') || f.mime_type?.includes('m4a')));
                
                // Sort descending by bitrate to select the highest quality AAC stream (e.g. itag 140 @ ~128kbps over itag 139 @ ~48kbps)
                m4aAudioFormats.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
                
                let format = m4aAudioFormats[0];
                
                if (!format) {
                    console.log("[JSC WARN] No MP4/M4A audio format found, searching all audio-only formats...");
                    const audioOnly = allFormats.filter(f => f.has_audio && !f.has_video);
                    audioOnly.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
                    format = audioOnly[0];
                }
                if (!format) {
                    format = allFormats.find(f => f.has_audio);
                }
                
                if (!format) {
                    throw new Error("No audio format available for track ID: " + "\(videoId)");
                }
                
                console.log("[JSC SUCCESS] Selected audio format: itag=" + format.itag + ", mime=" + format.mime_type + ", bitrate=" + format.bitrate + ", quality=" + (format.audio_quality || 'N/A'));
                
                let streamUrl = format.url;
                if (!streamUrl && typeof format.decipher === 'function') {
                    console.log("[JSC] format.url missing, deciphering signature with player...");
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
                
                console.log("[JSC SUCCESS] Stream URL resolved (\(videoId)), length:", streamUrl.length);
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
    
    public func searchAppleMusicSuggestions(query: String, completion: @escaping (Result<[String], Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
        
        let nativeSuggestionsCB: @convention(block) (String, String) -> Void = { [weak self] jsonStr, errMsg in
            DispatchQueue.main.async {
                if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let suggestions = try? JSONDecoder().decode([String].self, from: data) {
                    completion(.success(suggestions))
                } else if !errMsg.isEmpty {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -20, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    completion(.success([]))
                }
            }
        }
        context.setObject(nativeSuggestionsCB, forKeyedSubscript: "__nativeCompleteAMSuggestions" as NSString)
        
        let script = """
        (async () => {
            try {
                if (!globalThis.amInstance && globalThis.AppleMusic) {
                    globalThis.amInstance = new globalThis.AppleMusic({ region: globalThis.Region.US, authType: globalThis.AuthType.Scraped });
                    await globalThis.amInstance.init();
                }
                if (!globalThis.amInstance) {
                    __nativeCompleteAMSuggestions(JSON.stringify([]), "");
                    return;
                }
                const res = await globalThis.amInstance.Suggestions.suggestions({ term: "\(escapedQuery)", limit: 8 });
                const suggestions = [];
                const rawList = res?.results?.suggestions || [];
                for (const item of rawList) {
                    if (typeof item === 'string') {
                        suggestions.push(item);
                    } else if (item && typeof item === 'object') {
                        if (item.searchTerm) suggestions.push(item.searchTerm);
                        else if (item.displayTerm) suggestions.push(item.displayTerm);
                    }
                }
                __nativeCompleteAMSuggestions(JSON.stringify(suggestions), "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] AM Suggestions failed:", msg);
                __nativeCompleteAMSuggestions("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
    
    public func searchAppleMusic(query: String, completion: @escaping (Result<AppleMusicSearchContainer, Error>) -> Void) {
        let escapedQuery = query.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
        
        let nativeAMSearchCB: @convention(block) (String, String) -> Void = { [weak self] jsonStr, errMsg in
            DispatchQueue.main.async {
                if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let container = try? JSONDecoder().decode(AppleMusicSearchContainer.self, from: data) {
                    completion(.success(container))
                } else if !errMsg.isEmpty {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -21, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    completion(.success(AppleMusicSearchContainer()))
                }
            }
        }
        context.setObject(nativeAMSearchCB, forKeyedSubscript: "__nativeCompleteAMSearch" as NSString)
        
        let script = """
        (async () => {
            try {
                if (!globalThis.amInstance && globalThis.AppleMusic) {
                    globalThis.amInstance = new globalThis.AppleMusic({ region: globalThis.Region.US, authType: globalThis.AuthType.Scraped });
                    await globalThis.amInstance.init();
                }
                if (!globalThis.amInstance) {
                    __nativeCompleteAMSearch(JSON.stringify({ songs: [], albums: [], artists: [] }), "");
                    return;
                }
                const res = await globalThis.amInstance.Search.search({ term: "\(escapedQuery)", types: ["songs", "albums", "artists"], limit: 15 });
                const results = res?.results || {};
                
                // Parse songs
                const songs = [];
                const songsDict = results.songs?.data || results.songs || {};
                const songList = Array.isArray(songsDict) ? songsDict : Object.values(songsDict);
                for (const song of songList) {
                    const attr = song.attributes || {};
                    let artUrl = attr.artwork?.url || "";
                    if (artUrl) artUrl = artUrl.replace('{w}', '300').replace('{h}', '300').replace('{f}', 'jpg');
                    songs.push({
                        id: song.id || attr.playParams?.id || "",
                        title: attr.name || "",
                        artist: attr.artistName || "",
                        album: attr.albumName || "",
                        durationMs: attr.durationInMillis || 0,
                        artworkUrl: artUrl,
                        releaseDate: attr.releaseDate || "",
                        isrc: attr.isrc || "",
                        genre: Array.isArray(attr.genreNames) ? attr.genreNames[0] || "" : "",
                        isExplicit: attr.contentRating === 'explicit'
                    });
                }
                
                // Parse albums
                const albums = [];
                const albumsDict = results.albums?.data || results.albums || {};
                const albumList = Array.isArray(albumsDict) ? albumsDict : Object.values(albumsDict);
                for (const alb of albumList) {
                    const attr = alb.attributes || {};
                    let artUrl = attr.artwork?.url || "";
                    if (artUrl) artUrl = artUrl.replace('{w}', '300').replace('{h}', '300').replace('{f}', 'jpg');
                    albums.push({
                        id: alb.id || "",
                        title: attr.name || "",
                        artist: attr.artistName || "",
                        artworkUrl: artUrl,
                        trackCount: attr.trackCount || 0,
                        releaseYear: attr.releaseDate ? attr.releaseDate.substring(0, 4) : ""
                    });
                }
                
                // Parse artists
                const artists = [];
                const artistsDict = results.artists?.data || results.artists || {};
                const artistList = Array.isArray(artistsDict) ? artistsDict : Object.values(artistsDict);
                for (const art of artistList) {
                    const attr = art.attributes || {};
                    let artUrl = attr.artwork?.url || "";
                    if (artUrl) artUrl = artUrl.replace('{w}', '300').replace('{h}', '300').replace('{f}', 'jpg');
                    artists.push({
                        id: art.id || "",
                        name: attr.name || "",
                        artworkUrl: artUrl,
                        genre: Array.isArray(attr.genreNames) ? attr.genreNames[0] || "" : ""
                    });
                }
                
                const container = { songs, albums, artists };
                __nativeCompleteAMSearch(JSON.stringify(container), "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] AM Search failed:", msg);
                __nativeCompleteAMSearch("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
}
