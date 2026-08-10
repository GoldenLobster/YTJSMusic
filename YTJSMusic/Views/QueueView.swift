// YTJSMusic/Views/QueueView.swift
import SwiftUI

struct QueueView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @Environment(\.presentationMode) var presentationMode
    
    private var upcoming: [Track] {
        audioManager.upcomingQueue
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    // Now Playing Section
                    if let current = audioManager.currentTrack {
                        Section(header: Text("Now Playing").font(.caption).fontWeight(.bold).foregroundColor(.secondary)) {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: current.thumbnail)) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(Image(systemName: "music.note"))
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(current.title)
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                        .lineLimit(1)
                                    Text(current.artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "waveform")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Up Next Section
                    Section(header:
                        HStack {
                            Text("Up Next (\(upcoming.count))")
                                .font(.caption)
                                .fontWeight(.bold)
                            Spacer()
                            if !upcoming.isEmpty {
                                Button("Clear") {
                                    audioManager.clearUpcomingQueue()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    ) {
                        if upcoming.isEmpty {
                            Text("No upcoming tracks in queue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(upcoming) { track in
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: track.thumbnail)) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .overlay(Image(systemName: "music.note"))
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(6)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(track.duration)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let idx = upcoming.firstIndex(of: track) {
                                        audioManager.jumpToQueueTrack(at: audioManager.currentIndex + 1 + idx)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                for offset in offsets.sorted(by: >) {
                                    audioManager.removeUpcomingTrack(atRelativeIndex: offset)
                                }
                            }
                            .onMove { source, destination in
                                audioManager.reorderUpcomingQueue(fromOffsets: source, toOffset: destination)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Playing Queue")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: EditButton(),
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
