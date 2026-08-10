// YTJSMusic/Services/AudioStreamCacheManager.swift
import Foundation

public struct CacheStreamEntry: Codable {
    public let streamKey: String
    public var totalBytes: Int64
    public var contentLength: Int64
    public var lastAccessDate: Date
    public var cachedRanges: [String] // Array of "start-end" strings
    
    public init(streamKey: String, totalBytes: Int64, contentLength: Int64 = 0, lastAccessDate: Date, cachedRanges: [String]) {
        self.streamKey = streamKey
        self.totalBytes = totalBytes
        self.contentLength = contentLength
        self.lastAccessDate = lastAccessDate
        self.cachedRanges = cachedRanges
    }
}

public actor AudioStreamCacheManager {
    public static let shared = AudioStreamCacheManager()
    
    private let cacheDirectory: URL
    private let metadataFileURL: URL
    private var streamEntries: [String: CacheStreamEntry] = [:]
    
    public var maxCacheSizeBytes: Int64 = 500 * 1024 * 1024 // 500 MB
    
    // Performance & Diagnostic counters
    public private(set) var hitCount: Int = 0
    public private(set) var missCount: Int = 0
    public private(set) var prefetchedBytes: Int64 = 0
    public private(set) var avoidedCDNRequests: Int = 0
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = caches.appendingPathComponent("AudioStreamCache", isDirectory: true)
        let metaURL = cacheDir.appendingPathComponent("cache_index.json")
        self.cacheDirectory = cacheDir
        self.metadataFileURL = metaURL
        
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        if FileManager.default.fileExists(atPath: metaURL.path),
           let data = try? Data(contentsOf: metaURL),
           let decoded = try? JSONDecoder().decode([String: CacheStreamEntry].self, from: data) {
            self.streamEntries = decoded
        }
    }
    
    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(streamEntries) else { return }
        try? data.write(to: metadataFileURL, options: .atomic)
    }
    
    public func updateContentLength(key: AudioStreamCacheKey, length: Int64) {
        guard length > 0 else { return }
        let streamKey = key.storageString
        var entry = streamEntries[streamKey] ?? CacheStreamEntry(streamKey: streamKey, totalBytes: 0, contentLength: length, lastAccessDate: Date(), cachedRanges: [])
        entry.contentLength = length
        streamEntries[streamKey] = entry
        saveIndex()
    }
    
    public func getContentLength(key: AudioStreamCacheKey) -> Int64 {
        let streamKey = key.storageString
        return streamEntries[streamKey]?.contentLength ?? 0
    }
    
    public func readChunk(key: AudioStreamCacheKey, requestedRange: NSRange) -> Data? {
        let streamKey = key.storageString
        guard var entry = streamEntries[streamKey] else {
            missCount += 1
            return nil
        }
        
        let reqStart = requestedRange.location
        let reqEnd = requestedRange.location + requestedRange.length - 1
        
        // Find chunk file matching requested range exactly or covering it
        let streamDir = cacheDirectory.appendingPathComponent(streamKey, isDirectory: true)
        
        for rangeStr in entry.cachedRanges {
            let parts = rangeStr.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                let chunkStart = parts[0]
                let chunkEnd = parts[1]
                
                if reqStart >= chunkStart && reqEnd <= chunkEnd {
                    let fileURL = streamDir.appendingPathComponent("\(chunkStart)-\(chunkEnd).chunk")
                    if let fileData = try? Data(contentsOf: fileURL) {
                        let offset = reqStart - chunkStart
                        let length = requestedRange.length
                        if offset + length <= fileData.count {
                            entry.lastAccessDate = Date()
                            streamEntries[streamKey] = entry
                            saveIndex()
                            
                            hitCount += 1
                            avoidedCDNRequests += 1
                            return fileData.subdata(in: offset..<(offset + length))
                        }
                    }
                }
            }
        }
        
        missCount += 1
        return nil
    }
    
    public func writeChunk(key: AudioStreamCacheKey, range: NSRange, data: Data, isPrefetch: Bool = false) {
        guard !data.isEmpty else { return }
        let streamKey = key.storageString
        let streamDir = cacheDirectory.appendingPathComponent(streamKey, isDirectory: true)
        try? FileManager.default.createDirectory(at: streamDir, withIntermediateDirectories: true)
        
        let start = range.location
        let end = range.location + data.count - 1
        let rangeStr = "\(start)-\(end)"
        let fileURL = streamDir.appendingPathComponent("\(rangeStr).chunk")
        
        try? data.write(to: fileURL, options: .atomic)
        
        var entry = streamEntries[streamKey] ?? CacheStreamEntry(streamKey: streamKey, totalBytes: 0, lastAccessDate: Date(), cachedRanges: [])
        if !entry.cachedRanges.contains(rangeStr) {
            entry.cachedRanges.append(rangeStr)
            entry.totalBytes += Int64(data.count)
        }
        entry.lastAccessDate = Date()
        streamEntries[streamKey] = entry
        
        if isPrefetch {
            prefetchedBytes += Int64(data.count)
        }
        
        saveIndex()
        enforceLRU()
    }
    
    public func getCachedRanges(key: AudioStreamCacheKey) -> [NSRange] {
        let streamKey = key.storageString
        guard let entry = streamEntries[streamKey] else { return [] }
        var result: [NSRange] = []
        for r in entry.cachedRanges {
            let parts = r.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                result.append(NSRange(location: parts[0], length: parts[1] - parts[0] + 1))
            }
        }
        return result
    }
    
    public func enforceLRU() {
        var currentTotal: Int64 = streamEntries.values.reduce(0) { $0 + $1.totalBytes }
        guard currentTotal > maxCacheSizeBytes else { return }
        
        // Sort streams by least recently accessed
        let sortedEntries = streamEntries.values.sorted { $0.lastAccessDate < $1.lastAccessDate }
        
        for entry in sortedEntries {
            let streamDir = cacheDirectory.appendingPathComponent(entry.streamKey, isDirectory: true)
            try? FileManager.default.removeItem(at: streamDir)
            currentTotal -= entry.totalBytes
            streamEntries.removeValue(forKey: entry.streamKey)
            
            if currentTotal <= maxCacheSizeBytes {
                break
            }
        }
        saveIndex()
    }
    
    public func clearCache() {
        let contents = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in contents {
            try? FileManager.default.removeItem(at: file)
        }
        streamEntries.removeAll()
        hitCount = 0
        missCount = 0
        prefetchedBytes = 0
        avoidedCDNRequests = 0
        saveIndex()
    }
    
    public func getStats() -> (usedBytes: Int64, maxBytes: Int64, streamCount: Int, hitCount: Int, missCount: Int, avoidedCDNRequests: Int) {
        let used = streamEntries.values.reduce(0) { $0 + $1.totalBytes }
        return (used, maxCacheSizeBytes, streamEntries.count, hitCount, missCount, avoidedCDNRequests)
    }
}
