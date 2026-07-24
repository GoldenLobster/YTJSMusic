// YTJSMusic/Models/Playlist.swift
import Foundation

public struct Playlist: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var tracks: [Track]
    
    public init(id: UUID = UUID(), name: String, tracks: [Track] = []) {
        self.id = id
        self.name = name
        self.tracks = tracks
    }
}
