// YTJSMusic/Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @ObservedObject var jscClient: JSCYoutubeClient
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    
    @State private var selectedTab: Int = 0
    @State private var showPlayerDetail: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                MusicSearchView(jscClient: jscClient, audioManager: audioManager, playlistManager: playlistManager)
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("YT Search")
                    }
                    .tag(0)
                
                AppleSearchView(jscClient: jscClient)
                    .tabItem {
                        Image(systemName: "applelogo")
                        Text("Apple Search")
                    }
                    .tag(1)
                
                PlaylistsView(playlistManager: playlistManager, audioManager: audioManager)
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Playlists")
                    }
                    .tag(2)
            }
            
            // Persistent Mini Player Overlay
            VStack {
                Spacer()
                MiniPlayerView(audioManager: audioManager) {
                    showPlayerDetail = true
                }
                .padding(.bottom, 50) // Floating above TabBar
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(isPresented: $showPlayerDetail) {
            PlayerDetailView(audioManager: audioManager)
        }
    }
}
