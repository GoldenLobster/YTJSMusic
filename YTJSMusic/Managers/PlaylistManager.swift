// YTJSMusic/Managers/PlaylistManager.swift
import Foundation
import Combine

public class PlaylistManager: ObservableObject {
    @Published public var playlists: [Playlist] = []
    
    private let saveUrl: URL
    
    public init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.saveUrl = docs.appendingPathComponent("user_playlists.json")
        loadPlaylists()
    }
    
    public func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        savePlaylists()
    }
    
    public func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        savePlaylists()
    }
    
    public func addTrackToPlaylist(track: Track, playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
            playlists[index].tracks.append(track)
            savePlaylists()
        }
    }
    
    public func removeTrackFromPlaylist(trackId: String, playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].tracks.removeAll(where: { $0.id == trackId })
        savePlaylists()
    }
    
    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: saveUrl)
        } catch {
            print("Failed to save playlists:", error)
        }
    }
    
    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: saveUrl.path) else { return }
        do {
            let data = try Data(contentsOf: saveUrl)
            self.playlists = try JSONDecoder().decode([Playlist].self, from: data)
        } catch {
            print("Failed to load playlists:", error)
        }
    }
}
