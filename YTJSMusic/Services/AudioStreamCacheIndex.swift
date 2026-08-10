// YTJSMusic/Services/AudioStreamCacheIndex.swift
import Foundation

public struct CachedStreamInfo {
    public let key: AudioStreamCacheKey
    public let contentLength: Int64
    public let cachedRanges: [NSRange]
    public let mimeType: String
    public let codec: String
    
    public var coverage: CacheCoverage {
        guard contentLength > 0 else { return .none }
        let totalCached = cachedRanges.reduce(0) { $0 + Int64($1.length) }
        if totalCached >= contentLength {
            return .complete
        } else if totalCached > 0 {
            return .partial
        } else {
            return .none
        }
    }
    
    public var hasInitialCachedRange: Bool {
        return cachedRanges.contains { $0.location == 0 && Int64($0.length) >= AudioStreamCacheIndex.minimumInitialRange }
    }
}

public final class AudioStreamCacheIndex {
    public static let shared = AudioStreamCacheIndex()
    public static let minimumInitialRange: Int64 = 64 * 1024
    
    private var lock = os_unfair_lock_s()
    private var streamEntries: [String: CacheStreamEntry] = [:]
    
    private init() {}
    
    public func updateEntries(_ entries: [String: CacheStreamEntry]) {
        os_unfair_lock_lock(&lock)
        self.streamEntries = entries
        os_unfair_lock_unlock(&lock)
    }
    
    public func updateEntry(_ entry: CacheStreamEntry) {
        os_unfair_lock_lock(&lock)
        self.streamEntries[entry.streamKey] = entry
        os_unfair_lock_unlock(&lock)
    }
    
    public func cachedPlayableStream(for videoID: String, capabilities: AudioPlaybackCapabilities) -> CachedStreamInfo? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // Find all cached entries matching videoID
        let matching = streamEntries.values.filter { $0.streamKey.hasPrefix("\(videoID)_") }
        
        // Try preferred codecs in order
        for preferred in capabilities.preferredCodecs {
            for entry in matching {
                let info = parseInfo(from: entry)
                if info.codec.contains(preferred) && capabilities.supportedContainers.contains(info.key.container) {
                    if info.hasInitialCachedRange {
                        return info
                    }
                }
            }
        }
        
        // Fallback to any supported codec
        for entry in matching {
            let info = parseInfo(from: entry)
            if capabilities.supportedCodecs.contains(info.codec) && capabilities.supportedContainers.contains(info.key.container) {
                if info.hasInitialCachedRange {
                    return info
                }
            }
        }
        
        return nil
    }
    
    public func getStreamInfo(key: AudioStreamCacheKey) -> CachedStreamInfo? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard let entry = streamEntries[key.storageString] else { return nil }
        return parseInfo(from: entry)
    }
    
    public func getCoverage(key: AudioStreamCacheKey) -> CacheCoverage {
        return getStreamInfo(key: key)?.coverage ?? .none
    }
    
    private func parseInfo(from entry: CacheStreamEntry) -> CachedStreamInfo {
        let parts = entry.streamKey.components(separatedBy: "_")
        let videoID = parts.first ?? ""
        let itag = parts.count > 1 ? (Int(parts[1]) ?? 140) : 140
        let codec = parts.count > 2 ? parts[2] : "mp4a.40.2"
        let container = parts.count > 3 ? parts[3] : "m4a"
        let mimeType = container == "webm" ? "audio/webm; codecs=\"\(codec)\"" : "audio/mp4; codecs=\"\(codec)\""
        
        let key = AudioStreamCacheKey(videoID: videoID, itag: itag, mimeType: mimeType, codec: codec, container: container)
        
        let ranges: [NSRange] = entry.cachedRanges.compactMap { rangeStr in
            let rParts = rangeStr.split(separator: "-").compactMap { Int($0) }
            if rParts.count == 2 {
                return NSRange(location: rParts[0], length: rParts[1] - rParts[0] + 1)
            }
            return nil
        }
        
        return CachedStreamInfo(
            key: key,
            contentLength: entry.contentLength,
            cachedRanges: ranges,
            mimeType: mimeType,
            codec: codec
        )
    }
}
