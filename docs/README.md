# YTJSMusic Documentation

Welcome to the technical documentation for **YTJSMusic**, an all-in-one iOS music streaming application powered by **YouTube.js** inside **JavaScriptCore** with **Apple Music catalog discovery**.

---

## 📑 Table of Contents

### 1. [Feature Guide](features.md)
Comprehensive breakdown of every user-facing feature in the app:
- **Apple Music Catalog Search & Discovery**: Autocomplete, filtering chips, artist & album views.
- **Intelligent Song Matching Engine**: Duration-weighted fuzzy matching, confidence scoring, and persistent resolution cache.
- **Synchronized Karaoke Lyrics**: LRCLIB integration, live scrolling, seek-by-tapping, and instrumental detection.
- **Queue & Playlists**: Reordering, swipe-to-delete, shuffle, repeat, and local playlist persistence.
- **Lock Screen & Media Center**: `MPNowPlayingInfoCenter`, lock screen album artwork, and remote command controls.
- **In-App Diagnostics & Settings**: Storage analytics, cache hit ratio, and live debug logs.

### 2. [System Architecture](architecture.md)
In-depth look at how the app works under the hood:
- **Swift $\leftrightarrow$ JavaScriptCore Bridge**: Memory isolation, native bindings (`__nativeFetch`, `__nativeCrypto`, `__nativeTimers`).
- **Modular Web API Polyfill Subsystem**: 11 polyfill scripts providing full WHATWG compliance for YouTube.js without Node.js or browser DOM.
- **InnerTube API Engine**: Client emulation (`IOS`, `ANDROID`, `YTMUSIC`), format deciphering, and player token management.
- **Decoupled Audio Backend**: `AudioPlaybackBackend` abstraction, `AVPlayerPlaybackBackend`, and capability matrix.

### 3. [Caching & Streaming Engine](caching-and-playback.md)
Detailed specification of the audio streaming and caching pipeline:
- **Zero-Network Resolution Cache Bypass**: Direct `ytaudio://cached/<id>` routing skipping YouTube API round-trips for sub-20ms instant startup.
- **3-Tier Cache Architecture**:
  - *Tier 1*: `AudioStreamCacheIndex` (in-memory lock-protected manifest index).
  - *Tier 2*: `AudioStreamCacheDiskReader` (queue-isolated serial disk reader).
  - *Tier 3*: `AudioStreamCacheManager` (asynchronous persistence).
- **Custom `YTStreamResourceLoader`**: Handling YouTube CDN `rqh=1` constraints, 256KB adaptive chunks, Range headers, and 403 token renewal.
- **Startup Latency Profiling**: Microsecond benchmark telemetry with `PlaybackStartupTrace` ($t_0 \to t_7$).
- **Smart Duration-Based Prefetcher**: Proactive queue prefetching for seamless gapless playback.

### 4. [Development & CI/CD Guide](development-guide.md)
Instructions for contributors and developers:
- **Local Environment Setup**: Node.js dependencies, bundling `runtime.bundle.js` with esbuild/webpack.
- **Simulation Test Harnesses**: `test_music.js`, `test_stream_playback.js`, and `test_youtube_flow.js`.
- **Xcode Configuration & iOS Building**: Signing, capabilities, background audio mode.
- **GitHub Actions CI/CD**: Automated IPA builds and testing pipelines.

---

## 🌐 Interactive Documentation Website

A web version of this documentation is included directly in this repository:
- View locally: open [`docs/index.html`](index.html) in any modern browser.
- Hostable on **GitHub Pages**, **Vercel**, or **Netlify** with zero build configuration.
