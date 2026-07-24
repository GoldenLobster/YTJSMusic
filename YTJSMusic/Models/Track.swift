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
}
