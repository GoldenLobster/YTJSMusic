// YTJSMusic/Managers/SongResolverCacheManager.swift
import Foundation

public struct CacheRecord: Codable, Equatable {
    public let primaryVideoId: String
    public let fallbackVideoIds: [String]
    public let score: Int
    public let confidence: ConfidenceLevel
    public let status: String // "resolved" or "not_found"
    public let scoreBreakdown: ScoreBreakdown
    public let matchedCandidate: YoutubeTrackCandidate?
    public let timestamp: TimeInterval
    
    public init(primaryVideoId: String, fallbackVideoIds: [String] = [], score: Int, confidence: ConfidenceLevel, status: String = "resolved", scoreBreakdown: ScoreBreakdown = ScoreBreakdown(), matchedCandidate: YoutubeTrackCandidate? = nil, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.primaryVideoId = primaryVideoId
        self.fallbackVideoIds = fallbackVideoIds
        self.score = score
        self.confidence = confidence
        self.status = status
        self.scoreBreakdown = scoreBreakdown
        self.matchedCandidate = matchedCandidate
        self.timestamp = timestamp
    }
    
    public var isExpired: Bool {
        // Low confidence scores (< 120) expire after 30 days
        if score < 120 {
            let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
            return Date().timeIntervalSince1970 - timestamp > thirtyDays
        }
        return false
    }
}

public class SongResolverCacheManager {
    public static let shared = SongResolverCacheManager()
    
    private let userDefaultsKey = "apple_to_youtube_cache_v2"
    private let overridesKey = "apple_to_youtube_overrides"
    
    private var cache: [String: CacheRecord] = [:]
    private var manualOverrides: [String: String] = [:]
    private let lock = NSLock()
    
    private init() {
        loadFromDisk()
    }
    
    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: CacheRecord].self, from: data) {
            cache = decoded
        }
        
        if let dict = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] {
            manualOverrides = dict
        }
    }
    
    private func saveToDisk() {
        lock.lock()
        defer { lock.unlock() }
        
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        UserDefaults.standard.set(manualOverrides, forKey: overridesKey)
    }
    
    // MARK: - API
    
    public func get(appleId: String, recordingKey: String) -> CacheRecord? {
        lock.lock()
        defer { lock.unlock() }
        
        // 1. Check manual overrides
        if let overrideVideoId = manualOverrides[appleId] {
            return CacheRecord(primaryVideoId: overrideVideoId, fallbackVideoIds: [], score: 500, confidence: .high, status: "resolved")
        }
        
        // 2. Check appleId direct hit
        if let record = cache[appleId], !record.isExpired {
            return record
        }
        
        // 3. Check recordingKey fallback hit
        if let record = cache[recordingKey], !record.isExpired {
            return record
        }
        
        return nil
    }
    
    public func set(appleId: String, recordingKey: String, result: ResolutionResult) {
        let record = CacheRecord(
            primaryVideoId: result.primaryVideoId,
            fallbackVideoIds: result.fallbackVideoIds,
            score: result.score,
            confidence: result.confidence,
            status: result.primaryVideoId.isEmpty ? "not_found" : "resolved",
            scoreBreakdown: result.scoreBreakdown,
            matchedCandidate: result.matchedCandidate,
            timestamp: Date().timeIntervalSince1970
        )
        
        lock.lock()
        cache[appleId] = record
        cache[recordingKey] = record
        lock.unlock()
        
        saveToDisk()
    }
    
    public func setNotFound(appleId: String, recordingKey: String) {
        let record = CacheRecord(
            primaryVideoId: "",
            fallbackVideoIds: [],
            score: 0,
            confidence: .low,
            status: "not_found",
            timestamp: Date().timeIntervalSince1970
        )
        
        lock.lock()
        cache[appleId] = record
        cache[recordingKey] = record
        lock.unlock()
        
        saveToDisk()
    }
    
    public func setManualOverride(appleId: String, youtubeVideoId: String) {
        lock.lock()
        manualOverrides[appleId] = youtubeVideoId
        lock.unlock()
        
        saveToDisk()
    }
}
