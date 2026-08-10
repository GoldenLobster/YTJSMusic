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
        ZStack {
            // Blurred Artwork Background
            if let track = audioManager.currentTrack {
                AsyncImage(url: URL(string: track.thumbnail)) { phase in
                    if let img = phase.image {
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.black
                    }
                }
                .ignoresSafeArea()
                .blur(radius: 40)
                .overlay(Color.black.opacity(0.65))
            } else {
                Color.black.ignoresSafeArea()
            }
            
            VStack {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Fetching Lyrics...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isInstrumental {
                    VStack(spacing: 16) {
                        Image(systemName: "guitars.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.8))
                        Text("This track is instrumental")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !lyricLines.isEmpty {
                    let activeId = currentActiveLyricId()
                    
                    ScrollViewReader { proxy in
                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 20) {
                                    Spacer().frame(height: 40)
                                    
                                    ForEach(lyricLines) { line in
                                        let isActive = isSynced && (line.id == activeId)
                                        
                                        Text(line.text)
                                            .font(.system(size: isActive ? 26 : 22, weight: isActive ? .bold : .semibold, design: .rounded))
                                            .foregroundColor(isActive ? .white : .white.opacity(0.45))
                                            .multilineTextAlignment(.leading)
                                            .blur(radius: isSynced && !isActive ? 0.3 : 0)
                                            .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
                                            .id(line.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if isSynced {
                                                    triggerUserScrollLockout()
                                                    audioManager.seek(to: line.timestamp)
                                                }
                                            }
                                    }
                                    
                                    Spacer().frame(height: 120)
                                }
                                .padding(.horizontal, 24)
                            }
                            .simultaneousGesture(
                                DragGesture().onChanged { _ in
                                    triggerUserScrollLockout()
                                }
                            )
                            .onChange(of: activeId) { newActiveId in
                                if isSynced && !isUserScrolling, let id = newActiveId {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                            
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
                                    .background(Capsule().fill(Color.white.opacity(0.25)).background(Capsule().blur(radius: 10)))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                }
                                .padding(.bottom, 20)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        Text(errorMessage ?? "No lyrics available for this track")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            loadLyricsForCurrentTrack()
        }
        .onChange(of: audioManager.currentTrack?.id) { _ in
            loadLyricsForCurrentTrack()
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
