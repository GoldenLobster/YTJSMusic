// YTJSMusic/Views/MusicSearchView.swift
import SwiftUI

struct MusicSearchView: View {
    @ObservedObject var jscClient: JSCYoutubeClient
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    
    @State private var query: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String? = nil
    
    @State private var selectedTrackForPlaylist: Track? = nil
    @State private var showPlaylistSheet: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Input Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search songs, artists, albums...", text: $query, onCommit: {
                        performSearch()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    if !query.isEmpty {
                        Button(action: {
                            query = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isSearching {
                    Spacer()
                    ProgressView("Searching YouTube Music...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Search for your favorite tracks")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(searchResults) { track in
                            TrackRow(
                                track: track,
                                isCurrent: audioManager.currentTrack?.id == track.id,
                                onPlay: {
                                    audioManager.playQueue(tracks: searchResults, startIndex: searchResults.firstIndex(of: track) ?? 0)
                                },
                                onPlayNext: {
                                    audioManager.playNext(track: track)
                                },
                                onAppendQueue: {
                                    audioManager.appendQueue(track: track)
                                },
                                onAddToPlaylist: {
                                    selectedTrackForPlaylist = track
                                    showPlaylistSheet = true
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Music Search")
            .sheet(isPresented: $showPlaylistSheet) {
                if let track = selectedTrackForPlaylist {
                    AddToPlaylistSheet(track: track, playlistManager: playlistManager)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        
        jscClient.searchMusic(query: query) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                switch result {
                case .success(let tracks):
                    self.searchResults = tracks
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool
    let onPlay: () -> Void
    let onPlayNext: () -> Void
    let onAppendQueue: () -> Void
    let onAddToPlaylist: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.thumbnail)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(6)
            .clipped()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrent ? .red : .primary)
                    .lineLimit(1)
                
                Text("\(track.artist) • \(track.duration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Menu {
                Button(action: onPlay) {
                    Label("Play Now", systemImage: "play.circle")
                }
                Button(action: onPlayNext) {
                    Label("Play Next", systemImage: "text.insert")
                }
                Button(action: onAppendQueue) {
                    Label("Add to Queue", systemImage: "text.append")
                }
                Button(action: onAddToPlaylist) {
                    Label("Add to Playlist", systemImage: "plus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }
}

struct AddToPlaylistSheet: View {
    let track: Track
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if playlistManager.playlists.isEmpty {
                    Text("No playlists created yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(playlistManager.playlists) { playlist in
                        Button(action: {
                            playlistManager.addTrackToPlaylist(track: track, playlistId: playlist.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(playlist.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(playlist.tracks.count) tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
