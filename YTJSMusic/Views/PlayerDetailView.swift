// YTJSMusic/Views/PlayerDetailView.swift
import SwiftUI

struct PlayerDetailView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isEditingSlider: Bool = false
    @State private var editingSliderValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Top Bar
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
                Spacer().frame(width: 24)
            }
            .padding(.top, 16)
            .padding(.horizontal)
            
            if let error = audioManager.lastPlayerError {
                ScrollView {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
                .frame(maxHeight: 100)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Artwork
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
                .frame(width: 260, height: 260)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            }
            
            Spacer()
            
            // Track Info
            if let track = audioManager.currentTrack {
                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                    
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
                .padding(.horizontal)
                
                HStack {
                    Text(formatTime(isEditingSlider ? editingSliderValue : audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(audioManager.duration > 0 ? formatTime(audioManager.duration) : (audioManager.currentTrack?.duration ?? "0:00"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            
            // Player Controls
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
            .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
