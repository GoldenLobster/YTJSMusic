// YTJSMusic/Views/LyricsView.swift
import SwiftUI

struct LyricsView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @StateObject private var lrclibService = LrclibService.shared
    
    @State private var lyricLines: [LyricLine] = []
    @State private var isSynced: Bool = false
    @State private var isInstrumental: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    @State private var isUserScrolling: Bool = false
    @State private var scrollTimerWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(1.1)
                    Text("Fetching Lyrics...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else if isInstrumental {
                VStack(spacing: 16) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("This track is instrumental")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else if !lyricLines.isEmpty {
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                Spacer().frame(height: 12)
                                
                                ForEach(lyricLines) { line in
                                    lyricLineView(line: line, activeId: activeId)
                                }
                                
                                Spacer().frame(height: 48)
                            }
                            .padding(.horizontal, 20)
                        }
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                triggerUserScrollLockout()
                            }
                        )
                        .onChange(of: activeId, perform: { newActiveId in
                            if isSynced && !isUserScrolling, let id = newActiveId {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        })
                        
                        // Re-sync Pill when user scrolled away
                        if isUserScrolling && isSynced {
                            Button(action: {
                                isUserScrolling = false
                                if let activeId = activeId {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        proxy.scrollTo(activeId, anchor: .center)
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text("Sync to Lyrics")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.primary.opacity(0.12)))
                                .foregroundColor(.primary)
                                .shadow(radius: 2)
                            }
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(errorMessage ?? "No lyrics available for this track")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadLyricsForCurrentTrack()
        }
        .onChange(of: audioManager.currentTrack?.id, perform: { _ in
            loadLyricsForCurrentTrack()
        })
    }
    
    private var activeId: UUID? {
        currentActiveLyricId()
    }
    
    @ViewBuilder
    private func lyricLineView(line: LyricLine, activeId: UUID?) -> some View {
        let isActive = isSynced && (line.id == activeId)
        Text(line.text)
            .font(.system(size: isActive ? 20 : 17, weight: isActive ? .bold : .medium, design: .rounded))
            .foregroundColor(isActive ? .red : .primary.opacity(0.65))
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeInOut(duration: 0.25), value: isActive)
            .id(line.id)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSynced {
                    triggerUserScrollLockout()
                    audioManager.seek(to: line.timestamp)
                }
            }
    }
    
    private func currentActiveLyricId() -> UUID? {
        guard isSynced && !lyricLines.isEmpty else { return nil }
        let currentTime = audioManager.currentTime
        var activeLine: LyricLine? = nil
        for line in lyricLines {
            if line.timestamp <= currentTime + 0.3 {
                activeLine = line
            } else {
                break
            }
        }
        return activeLine?.id ?? lyricLines.first?.id
    }
    
    private func triggerUserScrollLockout() {
        isUserScrolling = true
        scrollTimerWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation {
                isUserScrolling = false
            }
        }
        scrollTimerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: workItem)
    }
    
    private func loadLyricsForCurrentTrack() {
        guard let track = audioManager.currentTrack else {
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        lyricLines = []
        isSynced = false
        isInstrumental = false
        
        lrclibService.fetchLyrics(for: track) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let resp):
                    if resp.instrumental == true {
                        self.isInstrumental = true
                    } else if let synced = resp.syncedLyrics, !synced.isEmpty {
                        self.lyricLines = LrcParser.parseSyncedLyrics(synced)
                        self.isSynced = true
                    } else if let plain = resp.plainLyrics, !plain.isEmpty {
                        self.lyricLines = LrcParser.parsePlainLyrics(plain)
                        self.isSynced = false
                    } else {
                        self.errorMessage = "No lyrics found"
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
