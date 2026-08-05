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
        
        let nativeSuggestionsCB: @convention(block) (String, String) -> Void = { jsonStr, errMsg in
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
        
        let nativeAMSearchCB: @convention(block) (String, String) -> Void = { jsonStr, errMsg in
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
    
    public func resolveAppleTrackToYouTube(track: AppleMusicTrack, completion: @escaping (Result<ResolutionResult, Error>) -> Void) {
        let recordingKey = track.recordingKey
        if let cached = SongResolverCacheManager.shared.get(appleId: track.id, recordingKey: recordingKey) {
            let res = ResolutionResult(
                primaryVideoId: cached.primaryVideoId,
                fallbackVideoIds: cached.fallbackVideoIds,
                score: cached.score,
                confidence: cached.confidence,
                matchedCandidate: cached.matchedCandidate,
                scoreBreakdown: cached.scoreBreakdown
            )
            completion(.success(res))
            return
        }
        
        ResolverCoordinator.shared.resolve(appleId: track.id, executeTask: { [weak self] innerCompletion in
            guard let self = self else { return }
            
            let nativeResolveCB: @convention(block) (String, String) -> Void = { jsonStr, errMsg in
                DispatchQueue.main.async {
                    if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let result = try? JSONDecoder().decode(ResolutionResult.self, from: data) {
                        SongResolverCacheManager.shared.set(appleId: track.id, recordingKey: recordingKey, result: result)
                        innerCompletion(.success(result))
                    } else if !errMsg.isEmpty {
                        innerCompletion(.failure(NSError(domain: "JSCYoutubeClient", code: -30, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                    } else {
                        SongResolverCacheManager.shared.setNotFound(appleId: track.id, recordingKey: recordingKey)
                        innerCompletion(.success(ResolutionResult(primaryVideoId: "")))
                    }
                }
            }
            self.context.setObject(nativeResolveCB, forKeyedSubscript: "__nativeCompleteAMResolve" as NSString)
            
            let escapedTitle = track.title.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
            let escapedArtist = track.artist.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
            let escapedAlbum = track.album.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
            let isrc = track.isrc
            let durationMs = track.durationMs
            
            let script = """
            (async () => {
                try {
                    function normalize(str) {
                        if (!str) return "";
                        let s = str.toLowerCase();
                        const phrases = ["(remastered", "(explicit", "(clean", "(official audio", "(official video", "feat.", "ft."];
                        for (const p of phrases) {
                            const idx = s.indexOf(p);
                            if (idx !== -1) s = s.substring(0, idx);
                        }
                        return s.replace(/[^a-z0-9]/g, " ").replace(/[ ]+/g, " ").trim();
                    }
                    
                    const appleTrack = {
                        title: "\(escapedTitle)",
                        artist: "\(escapedArtist)",
                        album: "\(escapedAlbum)",
                        isrc: "\(isrc)",
                        durationMs: \(durationMs)
                    };
                    
                    const normAppleTitle = normalize(appleTrack.title);
                    const normAppleArtist = normalize(appleTrack.artist);
                    const normAppleAlbum = normalize(appleTrack.album);
                    
                    let candidates = [];
                    let isrcFound = false;
                    
                    if (appleTrack.isrc && appleTrack.isrc.length > 5) {
                        try {
                            const isrcRes = await globalThis.ytInstance.music.search(appleTrack.isrc, { type: "song" });
                            const isrcList = isrcRes.songs?.contents || isrcRes.results || [];
                            if (isrcList.length > 0) {
                                candidates.push(...isrcList);
                                isrcFound = true;
                            }
                        } catch (e) {
                            console.log("[JSC RESOLVER] ISRC search skipped/failed:", e.message);
                        }
                    }
                    
                    if (candidates.length === 0) {
                        const q1 = appleTrack.artist + " " + appleTrack.title;
                        console.log("[JSC RESOLVER] Searching YT Music for:", q1);
                        const res1 = await globalThis.ytInstance.music.search(q1, { type: "song" });
                        const list1 = res1.songs?.contents || res1.results || [];
                        candidates.push(...list1);
                    }
                    
                    function scoreCandidate(c) {
                        const ytTitle = c.title?.text || c.title || "";
                        const ytArtist = c.author?.name || c.author || c.artists?.[0]?.name || "";
                        const ytAlbum = c.album?.name || "";
                        const normYtTitle = normalize(ytTitle);
                        const normYtArtist = normalize(ytArtist);
                        const normYtAlbum = normalize(ytAlbum);
                        
                        let score = 0;
                        const bd = { title: 0, artist: 0, duration: 0, official: 0, album: 0, penalties: 0 };
                        
                        if (isrcFound && (normYtTitle.includes(normAppleTitle) || normYtArtist.includes(normAppleArtist))) {
                            score += 500;
                        }
                        
                        if (normYtTitle.includes(normAppleTitle) || normAppleTitle.includes(normYtTitle)) {
                            bd.title = 50;
                            score += 50;
                        }
                        
                        if (normYtArtist.includes(normAppleArtist) || normAppleArtist.includes(normYtArtist) || normYtTitle.includes(normAppleArtist)) {
                            bd.artist = 50;
                            score += 50;
                        }
                        
                        const appleDurSec = appleTrack.durationMs / 1000;
                        const ytDurSec = c.duration?.seconds || (typeof c.duration === 'number' ? c.duration : 0);
                        if (ytDurSec > 0) {
                            const delta = Math.abs(appleDurSec - ytDurSec);
                            if (delta <= 2) { bd.duration = 30; score += 30; }
                            else if (delta <= 5) { bd.duration = 20; score += 20; }
                            else if (delta > 15) { bd.duration = -40; score -= 40; }
                        }
                        
                        if (normYtAlbum.length > 0) {
                            if (normYtAlbum.includes(normAppleAlbum) || normAppleAlbum.includes(normYtAlbum)) {
                                bd.album = 20;
                                score += 20;
                            } else {
                                bd.album = -10;
                                score -= 10;
                            }
                        }
                        
                        if (ytArtist.includes("- Topic") || c.author?.is_verified || c.author?.is_official_artist) {
                            bd.official = 20;
                            score += 20;
                        }
                        
                        const lowerApple = appleTrack.title.toLowerCase();
                        const lowerYt = ytTitle.toLowerCase();
                        if (!lowerApple.includes("remix") && lowerYt.includes("remix")) { bd.penalties -= 40; score -= 40; }
                        if (!lowerApple.includes("live") && lowerYt.includes("live")) { bd.penalties -= 50; score -= 50; }
                        if (!lowerApple.includes("slowed") && (lowerYt.includes("slowed") || lowerYt.includes("reverb"))) { bd.penalties -= 50; score -= 50; }
                        if (!lowerApple.includes("cover") && lowerYt.includes("cover")) { bd.penalties -= 40; score -= 40; }
                        
                        const videoId = c.id || c.video_id || "";
                        const thumb = c.thumbnails?.[0]?.url || c.thumbnail || "";
                        return {
                            videoId: videoId,
                            title: ytTitle,
                            artist: ytArtist,
                            duration: Math.round(ytDurSec),
                            thumbnail: thumb,
                            score: score,
                            scoreBreakdown: bd
                        };
                    }
                    
                    const scored = candidates.map(scoreCandidate).filter(c => c.videoId).sort((a, b) => b.score - a.score);
                    if (scored.length === 0) {
                        __nativeCompleteAMResolve(JSON.stringify({ primaryVideoId: "", fallbackVideoIds: [], score: 0, confidence: "low" }), "");
                        return;
                    }
                    
                    const winner = scored[0];
                    const fallbacks = scored.slice(1, 4).map(c => c.videoId);
                    let confidence = "low";
                    if (winner.score >= 150) confidence = "high";
                    else if (winner.score >= 100) confidence = "medium";
                    
                    const res = {
                        primaryVideoId: winner.videoId,
                        fallbackVideoIds: fallbacks,
                        score: winner.score,
                        confidence: confidence,
                        matchedCandidate: {
                            videoId: winner.videoId,
                            title: winner.title,
                            artist: winner.artist,
                            duration: winner.duration,
                            thumbnail: winner.thumbnail
                        },
                        scoreBreakdown: winner.scoreBreakdown
                    };
                    
                    console.log("[JSC RESOLVER SUCCESS] Winner videoId:", winner.videoId, "score:", winner.score, "confidence:", confidence);
                    __nativeCompleteAMResolve(JSON.stringify(res), "");
                } catch (err) {
                    const msg = err.message || String(err);
                    console.log("[JSC ERROR] AM Resolve failed:", msg);
                    __nativeCompleteAMResolve("", msg);
                }
            })()
            """
            self.context.evaluateScript(script)
        }, completion: completion)
    }
    
    public func getAppleAlbumDetails(albumId: String, completion: @escaping (Result<AppleAlbumDetailContainer, Error>) -> Void) {
        let nativeAlbumDetailsCB: @convention(block) (String, String) -> Void = { jsonStr, errMsg in
            DispatchQueue.main.async {
                if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let container = try? JSONDecoder().decode(AppleAlbumDetailContainer.self, from: data) {
                    completion(.success(container))
                } else if !errMsg.isEmpty {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -31, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -31, userInfo: [NSLocalizedDescriptionKey: "Album not found"])))
                }
            }
        }
        context.setObject(nativeAlbumDetailsCB, forKeyedSubscript: "__nativeCompleteAMAlbumDetails" as NSString)
        
        let script = """
        (async () => {
            try {
                if (!globalThis.amInstance && globalThis.AppleMusic) {
                    globalThis.amInstance = new globalThis.AppleMusic({ region: globalThis.Region.US, authType: globalThis.AuthType.Scraped });
                    await globalThis.amInstance.init();
                }
                const albRes = await globalThis.amInstance.Albums.get({ id: "\(albumId)" });
                const albObj = albRes?.data?.[0] || {};
                const albAttr = albObj.attributes || {};
                let artUrl = albAttr.artwork?.url || "";
                if (artUrl) artUrl = artUrl.replace('{w}', '600').replace('{h}', '600').replace('{f}', 'jpg');
                
                const album = {
                    id: albObj.id || "\(albumId)",
                    title: albAttr.name || "",
                    artist: albAttr.artistName || "",
                    artworkUrl: artUrl,
                    trackCount: albAttr.trackCount || 0,
                    releaseYear: albAttr.releaseDate ? albAttr.releaseDate.substring(0, 4) : ""
                };
                
                const tracksRes = await globalThis.amInstance.Albums.getRelationship({ id: "\(albumId)", relationship: "tracks" });
                const trackList = tracksRes?.data || [];
                const tracks = [];
                for (const tr of trackList) {
                    const attr = tr.attributes || {};
                    let trArtUrl = attr.artwork?.url || artUrl;
                    if (trArtUrl) trArtUrl = trArtUrl.replace('{w}', '300').replace('{h}', '300').replace('{f}', 'jpg');
                    tracks.push({
                        id: tr.id || attr.playParams?.id || "",
                        title: attr.name || "",
                        artist: attr.artistName || album.artist,
                        album: album.title,
                        durationMs: attr.durationInMillis || 0,
                        artworkUrl: trArtUrl,
                        releaseDate: attr.releaseDate || albAttr.releaseDate || "",
                        isrc: attr.isrc || "",
                        genre: Array.isArray(attr.genreNames) ? attr.genreNames[0] || "" : "",
                        isExplicit: attr.contentRating === 'explicit'
                    });
                }
                
                __nativeCompleteAMAlbumDetails(JSON.stringify({ album, tracks }), "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] AM Album Details failed:", msg);
                __nativeCompleteAMAlbumDetails("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
    
    public func getAppleArtistDetails(artistId: String, completion: @escaping (Result<AppleArtistDetailContainer, Error>) -> Void) {
        let nativeArtistDetailsCB: @convention(block) (String, String) -> Void = { jsonStr, errMsg in
            DispatchQueue.main.async {
                if !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8), let container = try? JSONDecoder().decode(AppleArtistDetailContainer.self, from: data) {
                    completion(.success(container))
                } else if !errMsg.isEmpty {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -32, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else {
                    completion(.failure(NSError(domain: "JSCYoutubeClient", code: -32, userInfo: [NSLocalizedDescriptionKey: "Artist not found"])))
                }
            }
        }
        context.setObject(nativeArtistDetailsCB, forKeyedSubscript: "__nativeCompleteAMArtistDetails" as NSString)
        
        let script = """
        (async () => {
            try {
                if (!globalThis.amInstance && globalThis.AppleMusic) {
                    globalThis.amInstance = new globalThis.AppleMusic({ region: globalThis.Region.US, authType: globalThis.AuthType.Scraped });
                    await globalThis.amInstance.init();
                }
                const artRes = await globalThis.amInstance.Artists.get({ id: "\(artistId)" });
                const artObj = artRes?.data?.[0] || {};
                const artAttr = artObj.attributes || {};
                let artUrl = artAttr.artwork?.url || "";
                if (artUrl) artUrl = artUrl.replace('{w}', '600').replace('{h}', '600').replace('{f}', 'jpg');
                
                const artist = {
                    id: artObj.id || "\(artistId)",
                    name: artAttr.name || "",
                    artworkUrl: artUrl,
                    genre: Array.isArray(artAttr.genreNames) ? artAttr.genreNames[0] || "" : ""
                };
                
                const albumsRes = await globalThis.amInstance.Artists.getRelationship({ id: "\(artistId)", relationship: "albums" });
                const albumList = albumsRes?.data || [];
                const albums = [];
                for (const alb of albumList) {
                    const attr = alb.attributes || {};
                    let aUrl = attr.artwork?.url || "";
                    if (aUrl) aUrl = aUrl.replace('{w}', '300').replace('{h}', '300').replace('{f}', 'jpg');
                    albums.push({
                        id: alb.id || "",
                        title: attr.name || "",
                        artist: artist.name,
                        artworkUrl: aUrl,
                        trackCount: attr.trackCount || 0,
                        releaseYear: attr.releaseDate ? attr.releaseDate.substring(0, 4) : ""
                    });
                }
                
                __nativeCompleteAMArtistDetails(JSON.stringify({ artist, topSongs: [], albums }), "");
            } catch (err) {
                const msg = err.message || String(err);
                console.log("[JSC ERROR] AM Artist Details failed:", msg);
                __nativeCompleteAMArtistDetails("", msg);
            }
        })()
        """
        context.evaluateScript(script)
    }
}
