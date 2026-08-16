// YTJSMusic/Views/PlaylistsView.swift
import SwiftUI

struct PlaylistsView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var audioManager: AudioPlayerManager
    
    @State private var showCreateAlert: Bool = false
    @State private var newPlaylistName: String = ""
    
    var body: some View {
        NavigationView {
            List {
                if playlistManager.playlists.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Playlists Yet")
                            .font(.headline)
                        Text("Tap + to create your first playlist.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(playlistManager.playlists) { playlist in
                        NavigationLink(destination: PlaylistDetailView(playlist: playlist, playlistManager: playlistManager, audioManager: audioManager)) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                    .frame(width: 40, height: 40)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.headline)
                                    Text("\(playlist.tracks.count) tracks")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: playlistManager.deletePlaylist)
                }
            }
            .navigationTitle("Playlists")
            .padding(.bottom, audioManager.currentTrack != nil ? 110 : 20)
            .navigationBarItems(trailing: Button(action: {
                newPlaylistName = ""
                showCreateAlert = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
            })
            .alert("New Playlist", isPresented: $showCreateAlert) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                        playlistManager.createPlaylist(name: newPlaylistName)
                    }
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var audioManager: AudioPlayerManager
    
    var body: some View {
        List {
            if playlist.tracks.isEmpty {
                Text("Playlist is empty. Add songs from Search!")
                    .foregroundColor(.secondary)
            } else {
                Section {
                    Button(action: {
                        audioManager.isShuffle = true
                        audioManager.playQueue(tracks: playlist.tracks, startIndex: 0)
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "shuffle")
                            Text("Shuffle Play")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Section(header: Text("Tracks")) {
                    ForEach(playlist.tracks) { track in
                        TrackRow(
                            track: track,
                            isCurrent: audioManager.currentTrack?.id == track.id,
                            onPlay: {
                                audioManager.playQueue(tracks: playlist.tracks, startIndex: playlist.tracks.firstIndex(of: track) ?? 0)
                            },
                            onPlayNext: {
                                audioManager.playNext(track: track)
                            },
                            onAppendQueue: {
                                audioManager.appendQueue(track: track)
                            },
                            onAddToPlaylist: {}
                        )
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let track = playlist.tracks[index]
                            playlistManager.removeTrackFromPlaylist(trackId: track.id, playlistId: playlist.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .padding(.bottom, audioManager.currentTrack != nil ? 110 : 20)
    }
}
