// YTJSMusic/Models/Track.swift
import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: String
    public let thumbnail: String
    
    public init(id: String, title: String, artist: String, album: String, duration: String, thumbnail: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.thumbnail = thumbnail
    }
    
    /// Returns the track duration converted into seconds (e.g. "3:30" -> 210.0)
    public var durationInSeconds: Double {
        let parts = duration.components(separatedBy: ":").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 2 {
            return parts[0] * 60.0 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]
        } else if parts.count == 1 {
            return parts[0]
        }
        return 0.0
    }
    
    public var recordingKey: String {
        let normArtist = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let durSec = Int(durationInSeconds)
        return "\(normArtist)|\(normTitle)|\(durSec)"
    }
}
