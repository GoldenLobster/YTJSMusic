// YTJSMusic/Views/AppleArtistDetailView.swift
import SwiftUI

struct AppleArtistDetailView: View {
    let artistId: String
    @ObservedObject var jscClient: JSCYoutubeClient
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    
    @State private var artistContainer: AppleArtistDetailContainer? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Artist Details...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
            } else if let container = artistContainer {
                VStack(alignment: .leading, spacing: 20) {
                    // Artist Header Avatar
                    HStack(spacing: 16) {
                        AsyncImage(url: URL(string: container.artist.artworkUrl)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(Image(systemName: "person.fill").font(.largeTitle))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(container.artist.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if !container.artist.genre.isEmpty {
                                Text(container.artist.genre)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Albums Discography Grid / List
                    if !container.albums.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Albums & Releases")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(container.albums) { album in
                                NavigationLink(destination: AppleAlbumDetailView(albumId: album.id, jscClient: jscClient, audioManager: audioManager, playlistManager: playlistManager)) {
                                    AlbumRowView(album: album)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(artistContainer?.artist.name ?? "Artist")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadArtistDetails()
        }
    }
    
    private func loadArtistDetails() {
        isLoading = true
        jscClient.getAppleArtistDetails(artistId: artistId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let container):
                    self.artistContainer = container
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Add To Playlist Modal Sheet

struct AddAppleTrackToPlaylistSheet: View {
    let track: AppleMusicTrack
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Playlist")) {
                    ForEach(playlistManager.playlists) { playlist in
                        Button(action: {
                            let converted = Track(
                                id: track.id,
                                title: track.title,
                                artist: track.artist,
                                album: track.album,
                                duration: track.durationFormatted,
                                thumbnail: track.artworkUrl
                            )
                            playlistManager.addTrackToPlaylist(track: converted, playlistId: playlist.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.red)
                                Text(playlist.name)
                                    .font(.body)
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
