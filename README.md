<div align="center">

# 🎵 YTJSMusic

### High-Performance Native iOS Music Player Powered by YouTube.js & Apple Music Discovery

[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0%2B-blue.svg?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138.svg?style=flat-square&logo=swift)](https://swift.org)
[![YouTube.js](https://img.shields.io/badge/YouTube.js-v18.0.0-FF0000.svg?style=flat-square&logo=youtube)](https://github.com/LuanRT/YouTube.js)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

*An all-in-one, privacy-focused iOS music streaming application with zero-network cache playback, real-time karaoke synchronized lyrics, Apple Music catalog discovery, and native hardware-accelerated playback without WebViews or external servers.*

[**Explore Features**](#-key-features) • [**Quick Start**](#-quick-start) • [**System Architecture**](#-architecture-overview) • [**Documentation**](#-documentation)

---

</div>

## 🌟 Overview

**YTJSMusic** redefines what is possible on iOS by embedding the full **YouTube.js (InnerTube API)** engine directly into a native iOS `JSContext` (JavaScriptCore) with a custom Web API polyfill subsystem.

It combines the rich discovery and high-resolution metadata of the **Apple Music Catalog** with the vast streaming library of **YouTube Music**, resolving tracks on-the-fly and delivering an ultra-fast, native music player experience.

---

## ✨ Key Features

### 🔍 Apple Music Catalog Discovery & Search
- **Subscription-Free Catalog Access**: Browse and search millions of tracks, albums, and artists using the iTunes/Apple Music catalog without requiring an Apple Music account.
- **Smart Live Autocomplete**: Fast, debounced search suggestions as you type.
- **Rich Discography & Album Views**: High-resolution cover artwork, release metadata, track listings, and one-tap **Play All** or **Shuffle Play**.
- **Filter Chips**: Effortlessly switch between *Top Results*, *Songs*, *Albums*, and *Artists*.

### ⚡ Intelligent Song Matching & Instant Playback
- **Duration & Metadata-Weighted Matching**: Advanced fuzzy matching algorithms map Apple Music metadata (ISRC, title, artist, duration) to YouTube Music audio streams with high confidence scoring.
- **Persistent Resolution Cache**: Matched tracks are remembered across app launches, allowing instant $(<1\text{ms})$ subsequent stream resolution.
- **Zero-Network Resolution Cache Bypass**: When a track is already cached locally, YTJSMusic completely bypasses the YouTube network resolution round-trip, starting local playback in **under 20ms**.

### 🎤 Synchronized Karaoke Lyrics
- **Live Scrolling Time-Coded Lyrics**: Real-time karaoke-style synchronized lyrics powered by LRCLIB.
- **Tap to Seek**: Tap any lyric line to jump directly to that exact moment in the song.
- **Plain Lyrics & Instrumental Cues**: Seamless fallback for unsynced tracks and automatic indicators for instrumental breaks.

### 🚀 3-Tier Audio Cache & Adaptive Streaming
- **Tier 1 (In-Memory Index)**: Synchronous, lock-protected manifest index for sub-millisecond lookup.
- **Tier 2 (Coalesced Disk Reader)**: Dedicated serial disk reader for instant zero-stall local streaming.
- **Tier 3 (Persistent Storage)**: Background chunk caching that automatically caches streamed audio for offline playback.
- **Custom `ytaudio://` Resource Loader**: Custom `AVAssetResourceLoaderDelegate` supporting 256KB adaptive chunking, `Range` header enforcement, and automatic HTTP 403 token expiration recovery.

### ⏱️ Smart Duration-Based Prefetching
- **Gapless Song Transitions**: Dynamically calculates remaining playback time and pre-resolves and pre-buffers the next track before the current song finishes.
- **Adaptive Thresholds**: Triggers 20s, 30s, or 45s ahead based on the current song's total length.

### 🎛️ Native iOS Music Experience
- **Lock Screen & Control Center**: Full `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration with high-res artwork, scrubbable progress bar, and CarPlay support.
- **Persistent Floating Mini-Player**: Bottom mini-player with interactive play/pause controls, fluid tap-to-expand animation, and proper `safeAreaInset` scroll clearance across all views.
- **Interactive Queue Management**: Swipe-to-delete, drag-and-drop reordering, and "Play Next" / "Add to Queue" actions.
- **Local Playlists**: Create, edit, and manage custom playlists directly on your device.
- **Diagnostics & Storage Management**: Dedicated Settings tab with storage analytics, cache management, network status, and live in-app diagnostic logs.

---

## 📸 Interface Preview

```
┌───────────────────────────┐     ┌───────────────────────────┐     ┌───────────────────────────┐
│ 🔍 Apple Music Search     │     │ 🎵 Now Playing            │     │ 🎤 Live Synced Lyrics     │
│ ┌───────────────────────┐ │     │         ┌───────┐         │     │                           │
│ │ Search songs, albums  │ │     │         │  ART  │         │     │   Just close your eyes    │
│ └───────────────────────┘ │     │         │       │         │     │                           │
│ [Top] [Songs] [Albums]    │     │         └───────┘         │     │ ▶ The sun is going down   │
│                           │     │   Get Lucky - Daft Punk   │     │                           │
│ • Get Lucky - Daft Punk   │     │   ───●────────────── 3:42 │     │   You'll be alright...    │
│ • Starboy - The Weeknd    │     │      ⏮   ⏸   ⏭          │     │                           │
│ • Overnight - Parcels     │     │   🔀      💬      📋      │     │                           │
└───────────────────────────┘     └───────────────────────────┘     └───────────────────────────┘
```

---

## 🏗️ Architecture Overview

```
YTJSMusic
├── 📱 SwiftUI Interface Layer
│   ├── AppleSearchView          # Apple Music catalog search & filter chips
│   ├── AppleAlbumDetailView     # High-res album view & discography
│   ├── AppleArtistDetailView    # Artist releases & top tracks
│   ├── PlayerDetailView         # Full-screen player, artwork & 3-dots actions
│   ├── LyricsView               # Real-time karaoke synchronized lyrics
│   ├── QueueView                # Interactive drag-and-drop playback queue
│   ├── PlaylistsView            # Local playlist management
│   ├── MiniPlayerView           # Edge-to-edge floating mini-player bar
│   └── SettingsView             # Storage analytics & diagnostic log drawer
│
├── 🧠 Audio & Resolver Core
│   ├── AudioPlayerManager       # Queue, playback state, and background audio
│   ├── SongResolverCacheManager # Fuzzy matcher & persistent resolution index
│   ├── YTStreamResourceLoader   # Custom AVAssetResourceLoader (ytaudio://)
│   ├── AudioStreamCacheManager  # 3-tier cache subsystem & disk persistence
│   └── LrclibService            # LRCLIB synchronized lyrics client
│
└── ⚡ JavaScriptCore Subsystem
    ├── JSCPolyfillBridge        # Native Swift bridge (Fetch, Crypto, Timers)
    ├── JSCYoutubeClient         # YouTube.js InnerTube wrapper in JSContext
    └── polyfills/*.js           # 11 modular Web API polyfills
```

---

## 🚀 Quick Start

### Prerequisites
- **macOS** with **Xcode 15.0+**
- **iOS 15.0+** physical device or Simulator
- **Node.js 18+** (for bundling YouTube.js)

### 1. Clone the Repository
```bash
git clone https://github.com/GoldenLobster/YTJSMusic.git
cd YTJSMusic
```

### 2. Install Node Dependencies & Build Runtime Bundle
```bash
# Install npm dependencies
npm install

# Bundle YouTube.js for JavaScriptCore
npm run bundle
```

### 3. Run Test Simulation Harness
```bash
# Verify JavaScriptCore YouTube.js engine locally
node test_music.js

# Test stream deciphering & chunk validation
node test_stream_playback.js
```

### 4. Build & Run on iOS
1. Open `YTJSMusic.xcodeproj` in Xcode.
2. Select the `YTJSMusic` scheme and your connected iOS device or simulator.
3. Press **`Cmd + R`** to build and run.

---

## 📚 Documentation

Detailed technical documentation is available in the [`docs/`](docs/) directory and on the [**Documentation Website**](docs/index.html):

| Topic | Description |
| :--- | :--- |
| [**📖 Master Documentation Index**](docs/README.md) | Overview of all technical guides and references. |
| [**✨ Complete Feature Guide**](docs/features.md) | In-depth walkthrough of all user-facing features, search, and playback. |
| [**🏛️ System Architecture**](docs/architecture.md) | JavaScriptCore runtime, Swift bridge, modular polyfills, and audio backends. |
| [**⚡ Caching & Streaming Engine**](docs/caching-and-playback.md) | 3-tier cache subsystem, cache bypass, `YTStreamResourceLoader`, and prefetching. |
| [**🛠️ Development & CI/CD Guide**](docs/development-guide.md) | Building, bundling, testing scripts, and GitHub Actions IPA builds. |

---

## 🤝 Contributing

Contributions are always welcome! Whether reporting an issue, optimizing stream resolution, or improving UI animations:
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
