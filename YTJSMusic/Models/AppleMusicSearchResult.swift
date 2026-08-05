// YTJSMusic/Models/AppleMusicSearchResult.swift
import Foundation

public struct AppleMusicTrack: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let durationMs: Int
    public let artworkUrl: String
    public let releaseDate: String
    public let isrc: String
    public let genre: String
    public let isExplicit: Bool
    
    public init(id: String, title: String, artist: String, album: String, durationMs: Int, artworkUrl: String, releaseDate: String, isrc: String, genre: String, isExplicit: Bool) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.artworkUrl = artworkUrl
        self.releaseDate = releaseDate
        self.isrc = isrc
        self.genre = genre
        self.isExplicit = isExplicit
    }
    
    public var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var durationSeconds: Double {
        return Double(durationMs) / 1000.0
    }
    
    public var recordingKey: String {
        let normArtist = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let durSec = durationMs / 1000
        return "\(normArtist)|\(normTitle)|\(durSec)"
    }
}

public struct AppleMusicArtist: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let artworkUrl: String
    public let genre: String
    
    public init(id: String, name: String, artworkUrl: String, genre: String) {
        self.id = id
        self.name = name
        self.artworkUrl = artworkUrl
        self.genre = genre
    }
}

public struct AppleMusicAlbum: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let artworkUrl: String
    public let trackCount: Int
    public let releaseYear: String
    
    public init(id: String, title: String, artist: String, artworkUrl: String, trackCount: Int, releaseYear: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkUrl = artworkUrl
        self.trackCount = trackCount
        self.releaseYear = releaseYear
    }
}

public struct AppleMusicSearchContainer: Codable, Equatable {
    public let songs: [AppleMusicTrack]
    public let albums: [AppleMusicAlbum]
    public let artists: [AppleMusicArtist]
    
    public init(songs: [AppleMusicTrack] = [], albums: [AppleMusicAlbum] = [], artists: [AppleMusicArtist] = []) {
        self.songs = songs
        self.albums = albums
        self.artists = artists
    }
}

public struct AppleAlbumDetailContainer: Codable, Equatable {
    public let album: AppleMusicAlbum
    public let tracks: [AppleMusicTrack]
    
    public init(album: AppleMusicAlbum, tracks: [AppleMusicTrack] = []) {
        self.album = album
        self.tracks = tracks
    }
}

public struct AppleArtistDetailContainer: Codable, Equatable {
    public let artist: AppleMusicArtist
    public let topSongs: [AppleMusicTrack]
    public let albums: [AppleMusicAlbum]
    
    public init(artist: AppleMusicArtist, topSongs: [AppleMusicTrack] = [], albums: [AppleMusicAlbum] = []) {
        self.artist = artist
        self.topSongs = topSongs
        self.albums = albums
    }
}

// MARK: - Resolution Result Models

public enum ConfidenceLevel: String, Codable, Equatable {
    case high
    case medium
    case low
}

public struct ScoreBreakdown: Codable, Equatable {
    public let title: Int
    public let artist: Int
    public let duration: Int
    public let official: Int
    public let album: Int
    public let penalties: Int
    
    public init(title: Int = 0, artist: Int = 0, duration: Int = 0, official: Int = 0, album: Int = 0, penalties: Int = 0) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.official = official
        self.album = album
        self.penalties = penalties
    }
}

public struct YoutubeTrackCandidate: Codable, Equatable {
    public let videoId: String
    public let title: String
    public let artist: String
    public let duration: Int
    public let thumbnail: String
    
    public init(videoId: String, title: String, artist: String, duration: Int, thumbnail: String) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.duration = duration
        self.thumbnail = thumbnail
    }
}

public struct ResolutionResult: Codable, Equatable {
    public let primaryVideoId: String
    public let fallbackVideoIds: [String]
    public let score: Int
    public let confidence: ConfidenceLevel
    public let matchedCandidate: YoutubeTrackCandidate?
    public let scoreBreakdown: ScoreBreakdown
    
    public init(primaryVideoId: String, fallbackVideoIds: [String] = [], score: Int = 0, confidence: ConfidenceLevel = .low, matchedCandidate: YoutubeTrackCandidate? = nil, scoreBreakdown: ScoreBreakdown = ScoreBreakdown()) {
        self.primaryVideoId = primaryVideoId
        self.fallbackVideoIds = fallbackVideoIds
        self.score = score
        self.confidence = confidence
        self.matchedCandidate = matchedCandidate
        self.scoreBreakdown = scoreBreakdown
    }
}
