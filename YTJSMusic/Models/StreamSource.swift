// YTJSMusic/Models/StreamSource.swift
import Foundation

public enum CacheCoverage {
    case none
    case partial
    case complete
}

public struct CachedStreamReference {
    public let key: AudioStreamCacheKey
    public let contentLength: Int64
    public let mimeType: String
    public let coverage: CacheCoverage
    
    public init(key: AudioStreamCacheKey, contentLength: Int64, mimeType: String, coverage: CacheCoverage) {
        self.key = key
        self.contentLength = contentLength
        self.mimeType = mimeType
        self.coverage = coverage
    }
}

public struct RemoteStreamReference {
    public let key: AudioStreamCacheKey
    public let initialURL: URL
    public let contentLength: Int64?
    public let mimeType: String?
    
    public init(key: AudioStreamCacheKey, initialURL: URL, contentLength: Int64? = nil, mimeType: String? = nil) {
        self.key = key
        self.initialURL = initialURL
        self.contentLength = contentLength
        self.mimeType = mimeType
    }
}

public enum StreamSource {
    case cached(CachedStreamReference)
    case remote(RemoteStreamReference)
    
    public var key: AudioStreamCacheKey {
        switch self {
        case .cached(let ref): return ref.key
        case .remote(let ref): return ref.key
        }
    }
}
