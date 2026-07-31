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
