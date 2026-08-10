// YTJSMusic/Models/AudioStreamCacheKey.swift
import Foundation

public struct AudioStreamCacheKey: Hashable, Codable {
    public let videoID: String
    public let itag: Int
    public let mimeType: String
    public let codec: String
    public let container: String
    
    public init(videoID: String, itag: Int, mimeType: String, codec: String, container: String) {
        self.videoID = videoID
        self.itag = itag
        self.mimeType = mimeType
        self.codec = codec
        self.container = container
    }
    
    public var storageString: String {
        let safeCodec = codec.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "\"", with: "")
        let safeContainer = container.replacingOccurrences(of: "/", with: "_")
        return "\(videoID)_\(itag)_\(safeCodec)_\(safeContainer)"
    }
}
