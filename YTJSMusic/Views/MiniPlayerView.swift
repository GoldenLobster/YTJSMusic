// YTJSMusic/Views/MiniPlayerView.swift
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    let onTap: () -> Void
    
    var body: some View {
        if let track = audioManager.currentTrack {
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if audioManager.isLoading {
                    ProgressView()
                        .padding(.trailing, 8)
                } else {
                    Button(action: {
                        audioManager.togglePlayPause()
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .padding(8)
                    }
                }
                
                Button(action: {
                    audioManager.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 12)
            .onTapGesture {
                onTap()
            }
        }
    }
}
