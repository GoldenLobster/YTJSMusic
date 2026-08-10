// YTJSMusic/Views/AppleSearchView.swift
import SwiftUI

struct AppleSearchView: View {
    @ObservedObject var jscClient: JSCYoutubeClient
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var playlistManager: PlaylistManager
    
    @State private var searchText: String = ""
    @State private var suggestions: [String] = []
    @State private var searchResults: AppleMusicSearchContainer = AppleMusicSearchContainer()
    @State private var isLoading: Bool = false
    @State private var selectedCategory: SearchCategory = .top
    @State private var searchDebounceWorkItem: DispatchWorkItem? = nil
    @State private var isEditingSearch: Bool = false
    @State private var resolvingTrackId: String? = nil
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case preview(AppleMusicTrack)
        case playlist(AppleMusicTrack)
        
        var id: String {
            switch self {
            case .preview(let track): return "preview_\(track.id)"
            case .playlist(let track): return "playlist_\(track.id)"
            }
        }
    }
    
    enum SearchCategory: String, CaseIterable, Identifiable {
        case top = "Top"
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar Input
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Artists, Songs, Lyrics, and More", text: $searchText, onEditingChanged: { editing in
                            isEditingSearch = editing
                        }, onCommit: {
                            performFullSearch(query: searchText)
                        })
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchText, perform: { newValue in
                            onSearchTextChange(newValue)
                        })
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                suggestions = []
                                searchResults = AppleMusicSearchContainer()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    if isEditingSearch || !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            suggestions = []
                            isEditingSearch = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundColor(.red)
                        .padding(.leading, 6)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                
                // Content View Stack: Live Suggestions vs Full Search Results
                ZStack {
                    Color(UIColor.systemBackground).ignoresSafeArea()
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Searching Apple Music Catalog...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !suggestions.isEmpty && isEditingSearch {
                        // Live Autocomplete Suggestions List
                        List {
                            Section(header: Text("Search Hints").font(.caption).fontWeight(.semibold)) {
                                ForEach(suggestions, id: \.self) { hint in
                                    Button(action: {
                                        searchText = hint
                                        isEditingSearch = false
                                        performFullSearch(query: hint)
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(hint)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else if !searchResults.songs.isEmpty || !searchResults.albums.isEmpty || !searchResults.artists.isEmpty {
                        // Category Segment Selector
                        VStack(spacing: 0) {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(SearchCategory.allCases) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            // Results List
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    if selectedCategory == .top || selectedCategory == .songs {
                                        if !searchResults.songs.isEmpty {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text("Songs")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal)
                                                
                                                ForEach(selectedCategory == .top ? Array(searchResults.songs.prefix(5)) : searchResults.songs) { track in
                                                    SongRowView(
                                                        track: track,
                                                        isResolving: resolvingTrackId == track.id,
                                                        onTap: {
                                                            playAppleTrack(track)
                                                        },
                                                        onPlayNext: {
                                                            resolveAndPlayNext(track)
                                                        },
                                                        onAppendQueue: {
                                                            resolveAndAppendQueue(track)
                                                        },
                                                        onInfoTap: {
                                                            activeSheet = .preview(track)
                                                        },
                                                        onAddToPlaylist: {
                                                            activeSheet = .playlist(track)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    
                                    if selectedCategory == .top || selectedCategory == .albums {
                                        if !searchResults.albums.isEmpty {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text("Albums")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal)
                                                
                                                ForEach(selectedCategory == .top ? Array(searchResults.albums.prefix(4)) : searchResults.albums) { album in
                                                    NavigationLink(destination: AppleAlbumDetailView(albumId: album.id, jscClient: jscClient, audioManager: audioManager, playlistManager: playlistManager)) {
                                                        AlbumRowView(album: album)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                    }
                                    
                                    if selectedCategory == .top || selectedCategory == .artists {
                                        if !searchResults.artists.isEmpty {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text("Artists")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal)
                                                
                                                ForEach(selectedCategory == .top ? Array(searchResults.artists.prefix(3)) : searchResults.artists) { artist in
                                                    NavigationLink(destination: AppleArtistDetailView(artistId: artist.id, jscClient: jscClient, audioManager: audioManager, playlistManager: playlistManager)) {
                                                        ArtistRowView(artist: artist)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    } else if !searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                            Text("No results for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Initial Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text("Apple Music Catalog Search")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Search songs, artists, and albums with real-time autocomplete suggestions and instant entity resolution.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { item in
                switch item {
                case .preview(let track):
                    AppleTrackPreviewSheet(track: track)
                case .playlist(let track):
                    AddAppleTrackToPlaylistSheet(track: track, playlistManager: playlistManager)
                }
            }
        }
    }
    
    // MARK: - Search & Play Actions
    
    private func onSearchTextChange(_ query: String) {
        searchDebounceWorkItem?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            suggestions = []
            return
        }
        
        let workItem = DispatchWorkItem {
            jscClient.searchAppleMusicSuggestions(query: trimmed) { result in
                DispatchQueue.main.async {
                    if case .success(let list) = result {
                        self.suggestions = list
                    }
                }
            }
        }
        searchDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func performFullSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isLoading = true
        suggestions = []
        
        jscClient.searchAppleMusic(query: trimmed) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let container):
                    self.searchResults = container
                case .failure(let error):
                    print("[APPLE SEARCH ERROR]", error.localizedDescription)
                }
            }
        }
    }
    
    private func playAppleTrack(_ track: AppleMusicTrack) {
        resolvingTrackId = track.id
        jscClient.resolveAppleTrackToYouTube(track: track) { result in
            DispatchQueue.main.async {
                self.resolvingTrackId = nil
                switch result {
                case .success(let res):
                    if !res.primaryVideoId.isEmpty {
                        let ytTrack = Track(
                            id: res.primaryVideoId,
                            title: track.title,
                            artist: track.artist,
                            album: track.album,
                            duration: track.durationFormatted,
                            thumbnail: track.artworkUrl
                        )
                        self.audioManager.playTrack(track: ytTrack)
                    } else {
                        print("[RESOLVER] No candidate video found for track: \(track.title)")
                    }
                case .failure(let error):
                    print("[RESOLVER ERROR]", error.localizedDescription)
                }
            }
        }
    }
    
    private func resolveAndPlayNext(_ track: AppleMusicTrack) {
        resolvingTrackId = track.id
        jscClient.resolveAppleTrackToYouTube(track: track) { result in
            DispatchQueue.main.async {
                self.resolvingTrackId = nil
                if case .success(let res) = result, !res.primaryVideoId.isEmpty {
                    let ytTrack = Track(
                        id: res.primaryVideoId,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: track.durationFormatted,
                        thumbnail: track.artworkUrl
                    )
                    self.audioManager.playNext(track: ytTrack)
                }
            }
        }
    }
    
    private func resolveAndAppendQueue(_ track: AppleMusicTrack) {
        resolvingTrackId = track.id
        jscClient.resolveAppleTrackToYouTube(track: track) { result in
            DispatchQueue.main.async {
                self.resolvingTrackId = nil
                if case .success(let res) = result, !res.primaryVideoId.isEmpty {
                    let ytTrack = Track(
                        id: res.primaryVideoId,
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        duration: track.durationFormatted,
                        thumbnail: track.artworkUrl
                    )
                    self.audioManager.appendQueue(track: ytTrack)
                }
            }
        }
    }
}

// MARK: - Row Subviews

struct SongRowView: View {
    let track: AppleMusicTrack
    let isResolving: Bool
    let onTap: () -> Void
    let onPlayNext: () -> Void
    let onAppendQueue: () -> Void
    let onInfoTap: () -> Void
    let onAddToPlaylist: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: track.artworkUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                    }
                }
                .frame(width: 56, height: 56)
                .cornerRadius(8)
                
                if isResolving {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if track.isExplicit {
                        Image(systemName: "e.square.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                Text("\(track.artist) • \(track.album)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(track.durationFormatted)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Menu {
                Button(action: onTap) {
                    Label("Play Track", systemImage: "play.circle")
                }
                Button(action: onPlayNext) {
                    Label("Play Next", systemImage: "text.insert")
                }
                Button(action: onAppendQueue) {
                    Label("Add to Queue", systemImage: "text.append")
                }
                Button(action: onAddToPlaylist) {
                    Label("Add to Playlist", systemImage: "plus")
                }
                Button(action: onInfoTap) {
                    Label("Resolution Debug Info", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Track Preview Sheet

struct AppleTrackPreviewSheet: View {
    let track: AppleMusicTrack
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Track Details")) {
                    HStack {
                        Text("Title")
                        Spacer()
                        Text(track.title).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Artist")
                        Spacer()
                        Text(track.artist).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Album")
                        Spacer()
                        Text(track.album).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(track.durationFormatted).foregroundColor(.secondary)
                    }
                    if !track.isrc.isEmpty {
                        HStack {
                            Text("ISRC")
                            Spacer()
                            Text(track.isrc).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    if !track.genre.isEmpty {
                        HStack {
                            Text("Genre")
                            Spacer()
                            Text(track.genre).foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Explicit")
                        Spacer()
                        Text(track.isExplicit ? "Yes" : "No").foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Apple Track ID")) {
                    Text(track.id)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Track Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Album & Artist Row Views

struct AlbumRowView: View {
    let album: AppleMusicAlbum
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: album.artworkUrl)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "square.stack").foregroundColor(.gray))
                }
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(album.artist) • \(album.releaseYear)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ArtistRowView: View {
    let artist: AppleMusicArtist
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: artist.artworkUrl)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if !artist.genre.isEmpty {
                    Text(artist.genre)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}


