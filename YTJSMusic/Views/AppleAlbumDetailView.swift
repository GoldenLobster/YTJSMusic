// YTJSMusic/Views/AppleAlbumDetailView.swift
import SwiftUI

struct AppleAlbumDetailView: View {
    let albumId: String
    @ObservedObject var jscClient: JSCYoutubeClient
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    
    @State private var albumContainer: AppleAlbumDetailContainer? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var trackForPlaylist: AppleMusicTrack? = nil
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Album Details...")
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
            } else if let container = albumContainer {
                VStack(spacing: 20) {
                    // Album Cover Artwork
                    AsyncImage(url: URL(string: container.album.artworkUrl)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(Image(systemName: "square.stack").font(.largeTitle))
                        }
                    }
                    .frame(width: 220, height: 220)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .padding(.top, 16)
                    
                    // Album Info Header
                    VStack(spacing: 6) {
                        Text(container.album.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(container.album.artist)
                            .font(.title3)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        
                        Text("Album • \(container.album.releaseYear) • \(container.tracks.count) Songs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons: Play All & Shuffle
                    HStack(spacing: 16) {
                        Button(action: {
                            playAlbum(tracks: container.tracks, startIndex: 0)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            let shuffled = container.tracks.shuffled()
                            playAlbum(tracks: shuffled, startIndex: 0)
                        }) {
                            HStack {
                                Image(systemName: "shuffle")
                                Text("Shuffle")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Tracks List
                    LazyVStack(spacing: 0) {
                        ForEach(0..<container.tracks.count, id: \.self) { index in
                            let track = container.tracks[index]
                            HStack(spacing: 14) {
                                HStack(spacing: 14) {
                                    Text("\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(track.title)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            
                                            if track.isExplicit {
                                                Image(systemName: "e.square.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playAlbum(tracks: container.tracks, startIndex: index)
                                }
                                
                                Spacer()
                                
                                Text(track.durationFormatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Menu {
                                     Button(action: {
                                         playAlbum(tracks: container.tracks, startIndex: index)
                                     }) {
                                         Label("Play Track", systemImage: "play.circle")
                                     }
                                     Button(action: {
                                         trackForPlaylist = track
                                     }) {
                                         Label("Add to Playlist", systemImage: "plus")
                                     }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(.gray)
                                        .padding(8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
            }
        }
        .navigationTitle(albumContainer?.album.title ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAlbumDetails()
        }
        .sheet(item: $trackForPlaylist) { track in
            AddAppleTrackToPlaylistSheet(track: track, playlistManager: playlistManager)
        }
    }
    
    private func loadAlbumDetails() {
        isLoading = true
        jscClient.getAppleAlbumDetails(albumId: albumId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let container):
                    self.albumContainer = container
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func playAlbum(tracks: [AppleMusicTrack], startIndex: Int) {
        guard startIndex < tracks.count else { return }
        let selected = tracks[startIndex]
        jscClient.resolveAppleTrackToYouTube(track: selected) { result in
            DispatchQueue.main.async {
                if case .success(let res) = result, !res.primaryVideoId.isEmpty {
                    let ytTrack = Track(
                        id: res.primaryVideoId,
                        title: selected.title,
                        artist: selected.artist,
                        album: selected.album,
                        duration: selected.durationFormatted,
                        thumbnail: selected.artworkUrl
                    )
                    self.audioManager.playTrack(track: ytTrack)
                }
            }
        }
    }
}
