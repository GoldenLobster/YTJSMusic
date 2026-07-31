// YTJSMusic/Views/PlayerDetailView.swift
import SwiftUI

struct PlayerDetailView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isEditingSlider: Bool = false
    @State private var editingSliderValue: Double = 0.0
    @State private var showDebugLogs: Bool = false
    
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
                Button(action: {
                    showDebugLogs = true
                }) {
                    Image(systemName: "terminal")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal)
            
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
        .sheet(isPresented: $showDebugLogs) {
            DebugLogsView()
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

struct DebugLogsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isCopied: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(SystemLogger.shared.logs.enumerated()), id: \.offset) { idx, log in
                            Text(log)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(log.contains("ERROR") || log.contains("403") || log.contains("Failed") ? .red : (log.contains("PROXY") ? .blue : .primary))
                                .id(idx)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle("Diagnostic Logs")
            .navigationBarItems(
                leading: Button(action: {
                    let allLogs = SystemLogger.shared.logs.joined(separator: "\n")
                    UIPasteboard.general.string = allLogs
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied!" : "Copy All")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
