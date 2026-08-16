// YTJSMusic/Views/PlayerDetailView.swift
import SwiftUI

struct PlayerDetailView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isEditingSlider: Bool = false
    @State private var editingSliderValue: Double = 0.0
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var showAddToPlaylist: Bool = false
    @State private var showShareSheet: Bool = false
    
    var body: some View {
        ScrollViewReader { mainScrollProxy in
            VStack(spacing: 0) {
                // Fixed Top Navigation Header Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    if let track = audioManager.currentTrack {
                        Menu {
                            Button(action: {
                                audioManager.playNext(track: track)
                            }) {
                                Label("Play Next", systemImage: "text.insert")
                            }
                            
                            Button(action: {
                                audioManager.appendQueue(track: track)
                            }) {
                                Label("Add to Queue", systemImage: "text.append")
                            }
                            
                            Button(action: {
                                showAddToPlaylist = true
                            }) {
                                Label("Add to Playlist...", systemImage: "plus")
                            }
                            
                            Button(action: {
                                shareTrack(track)
                            }) {
                                Label("Share Song", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    } else {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .id("playerTop")
                
                if let error = audioManager.lastPlayerError {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button(action: {
                            showDebugLogs = true
                        }) {
                            Label("View Diagnostic Logs", systemImage: "text.justify.left")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Artwork Image
                        if let track = audioManager.currentTrack {
                            AsyncImage(url: URL(string: track.thumbnail)) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(Image(systemName: "music.note").font(.largeTitle))
                                }
                            }
                            .frame(width: 250, height: 250)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                            .padding(.top, 8)
                            
                            // Track Title & Artist
                            VStack(spacing: 6) {
                                Text(track.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 20)
                                
                                Text(track.artist)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Progress Scrubber
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { isEditingSlider ? editingSliderValue : audioManager.currentTime },
                                    set: { newValue in
                                        isEditingSlider = true
                                        editingSliderValue = newValue
                                    }
                                ),
                                in: 0...(max(audioManager.duration, 1.0)),
                                onEditingChanged: { editing in
                                    if !editing {
                                        audioManager.seek(to: editingSliderValue)
                                        isEditingSlider = false
                                    }
                                }
                            )
                            .accentColor(.red)
                            .padding(.horizontal, 20)
                            
                            HStack {
                                Text(formatTime(isEditingSlider ? editingSliderValue : audioManager.currentTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(audioManager.duration > 0 ? formatTime(audioManager.duration) : (audioManager.currentTrack?.duration ?? "0:00"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Primary Playback Controls
                        HStack(spacing: 36) {
                            Button(action: {
                                audioManager.toggleShuffle()
                            }) {
                                Image(systemName: "shuffle")
                                    .font(.title3)
                                    .foregroundColor(audioManager.isShuffle ? .red : .gray)
                            }
                            
                            Button(action: {
                                audioManager.previousTrack()
                            }) {
                                Image(systemName: "backward.fill")
                                    .font(.title)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: {
                                audioManager.togglePlayPause()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 64, height: 64)
                                    
                                    if audioManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            
                            Button(action: {
                                audioManager.nextTrack()
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.title)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: {
                                audioManager.toggleRepeat()
                            }) {
                                Image(systemName: "repeat")
                                    .font(.title3)
                                    .foregroundColor(audioManager.isRepeat ? .red : .gray)
                            }
                        }
                        
                        // Bottom Toolbar (Lyrics & Queue Pills)
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showLyrics.toggle()
                                    if showLyrics {
                                        mainScrollProxy.scrollTo("lyricsSection", anchor: .top)
                                    } else {
                                        mainScrollProxy.scrollTo("playerTop", anchor: .top)
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                                        .font(.title3)
                                    Text("Lyrics")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(showLyrics ? Color.red.opacity(0.15) : Color.gray.opacity(0.12)))
                                .foregroundColor(showLyrics ? .red : .primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showQueue = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet")
                                        .font(.title3)
                                    Text("Queue")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if !audioManager.upcomingQueue.isEmpty {
                                        Text("\(audioManager.upcomingQueue.count)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(5)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.gray.opacity(0.12)))
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Spotify/Apple Music Style Lyrics Card Below Controls
                        if showLyrics {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundColor(.red)
                                    Text("Lyrics")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("Powered by LRCLIB")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                
                                LyricsView(audioManager: audioManager)
                                    .frame(height: 380)
                                    .padding(.bottom, 8)
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                            .id("lyricsSection")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
        }
        .sheet(isPresented: $showQueue) {
            QueueView(audioManager: audioManager)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            if let track = audioManager.currentTrack {
                AddTrackToPlaylistSheet(track: track, playlistManager: playlistManager)
            }
        }
    }
    
    private func shareTrack(_ track: Track) {
        let text = "Listening to \(track.title) - \(track.artist) https://youtu.be/\(track.id)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true, completion: nil)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct AddTrackToPlaylistSheet: View {
    let track: Track
    @ObservedObject var playlistManager: PlaylistManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Playlist")) {
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
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.red)
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
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
