// YTJSMusic/Views/AppleSearchView.swift
import SwiftUI

struct AppleSearchView: View {
    @ObservedObject var jscClient: JSCYoutubeClient
    
    @State private var searchText: String = ""
    @State private var suggestions: [String] = []
    @State private var searchResults: AppleMusicSearchContainer = AppleMusicSearchContainer()
    @State private var isLoading: Bool = false
    @State private var isSearchingSuggestions: Bool = false
    @State private var selectedCategory: SearchCategory = .top
    @State private var selectedTrackForPreview: AppleMusicTrack? = nil
    @State private var searchDebounceWorkItem: DispatchWorkItem? = nil
    @State private var isEditingSearch: Bool = false
    
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
                        .onChange(of: searchText) { newValue in
                            onSearchTextChange(newValue)
                        }
                        
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
                                                    SongRowView(track: track) {
                                                        selectedTrackForPreview = track
                                                    }
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
                                                    AlbumRowView(album: album)
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
                                                    ArtistRowView(artist: artist)
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
                            Image(systemName: "music.note.slash")
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
                            Text("Search songs, artists, and albums with real-time autocomplete suggestions.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Apple Search")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedTrackForPreview) { track in
                AppleTrackPreviewSheet(track: track)
            }
        }
    }
    
    // MARK: - Search Actions
    
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
}

// MARK: - Row Subviews

struct SongRowView: View {
    let track: AppleMusicTrack
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct AlbumRowView: View {
    let album: AppleMusicAlbum
    
    var body: some View {
        HStack(spacing: 12) {
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
            .frame(width: 60, height: 60)
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
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
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
            .frame(width: 54, height: 54)
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
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview Detail Sheet

struct AppleTrackPreviewSheet: View {
    let track: AppleMusicTrack
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: track.artworkUrl)) { phase in
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
                    .frame(width: 220, height: 220)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    VStack(spacing: 6) {
                        HStack {
                            Text(track.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            if track.isExplicit {
                                Image(systemName: "e.square.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(track.artist)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text(track.album)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Apple Music Catalog Metadata")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        MetadataRow(label: "ISRC Code", value: track.isrc.isEmpty ? "N/A" : track.isrc)
                        MetadataRow(label: "Exact Duration", value: "\(track.durationMs) ms (\(track.durationFormatted))")
                        MetadataRow(label: "Release Date", value: track.releaseDate.isEmpty ? "N/A" : track.releaseDate)
                        MetadataRow(label: "Genre", value: track.genre.isEmpty ? "N/A" : track.genre)
                        MetadataRow(label: "Apple Music ID", value: track.id)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                            Text("Phase 1 Preview Mode")
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                        
                        Text("In Phase 2, this track metadata will be used to score and match the exact audio stream on YouTube with high precision.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}
