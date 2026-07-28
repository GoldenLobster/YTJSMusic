# YTJSMusic

**YTJSMusic** is a native iOS music streaming application powered by **YouTube.js** (`youtubei.js` / InnerTube API) running inside iOS **JavaScriptCore** (`JSContext`). It streams music directly from YouTube without requiring a `WKWebView`, external backend servers, or third-party proxy services.

---

## Key Features

- **Native SwiftUI Music Player**: Modern music player interface complete with search, interactive queue management, full-screen player detail view, persistent mini-player, and local playlist creation/management.
- **Embedded JavaScriptCore Runtime**: Runs `youtubei.js` directly inside an isolated iOS `JSContext` (pure ECMAScript environment), providing fast startup times and low footprint compared to web view wrappers.
- **Custom Web API Polyfill Subsystem**: Implements missing browser/Node Web APIs (such as `fetch`, `crypto.getRandomValues`, `TextEncoder`/`TextDecoder`, WHATWG `Streams`, timers) backed by native Swift `URLSession`, `CryptoKit`, and `DispatchQueue`.
- **Advanced YouTube CDN Stream Loader (`YTStreamResourceLoader`)**: Custom `AVAssetResourceLoaderDelegate` that intercepts `AVPlayer` HTTP requests to:
  - Enforce mandatory `Range` headers required by YouTube CDN (`rqh=1` stream signature).
  - Stream audio in 64KB adaptive chunks to bypass YouTube CDN anti-bulk-download `HTTP 403 Forbidden` restrictions.
  - Map audio MIME types to native Apple Uniform Type Identifiers (`com.apple.m4a-audio`) to ensure smooth hardware-accelerated playback.
- **In-App Live Diagnostic Drawer**: Integrated terminal logger (`SystemLogger`) accessible directly from the player interface for real-time JSContext, network fetch, and stream loader diagnostic logs.

---

## System Architecture

```
YTJSMusic/
├── YTJSMusic/                       # SwiftUI App & Audio Management
│   ├── YTJSMusicApp.swift           # Application entry point & lifecycle
│   ├── Managers/
│   │   ├── AudioPlayerManager.swift # Queue, playback controls, AVPlayer integration
│   │   ├── YTStreamResourceLoader.swift # AVAssetResourceLoaderDelegate for CDN streaming
│   │   └── PlaylistManager.swift    # Local playlist storage & management
│   ├── Models/
│   │   ├── Track.swift              # Audio track model
│   │   ├── Playlist.swift           # Playlist model
│   │   └── SystemLogger.swift       # In-app diagnostic logging singleton
│   └── Views/
│       ├── MainTabView.swift        # Main application navigation container
│       ├── MusicSearchView.swift    # Search interface & track listings
│       ├── PlaylistsView.swift      # User playlist collection views
│       ├── PlayerDetailView.swift   # Full-screen player view & diagnostic logs drawer
│       └── MiniPlayerView.swift     # Bottom floating mini-player bar
├── Swift/                           # Native JavaScriptCore Engine & Client Bridge
│   ├── JSCPolyfillBridge.swift      # Exposes Swift native methods (fetch, crypto, timers) to JSC
│   ├── JSCYoutubeClient.swift       # Swift wrapper around Innertube JS instance
│   └── LocalAudioProxyServer.swift  # Fallback HTTP audio proxy server
├── polyfills/                       # Modular Web API Polyfills for JavaScriptCore
│   ├── 00-console.js
│   ├── 01-events.js
│   ├── 02-text-encoding.js
│   ├── 03-base64.js
│   ├── 04-url.js
│   ├── 05-fetch.js
│   ├── 06-crypto.js
│   ├── 07-timers.js
│   ├── 08-performance.js
│   ├── 09-abort.js
│   └── 10-streams.js
├── entry.js                         # Webpack/esbuild entry importing youtubei.js
├── runtime.bundle.js                # Bundled YouTube.js runtime IIFE for JavaScriptCore
├── test_music.js                    # Node/bare JSC test harness for music search & formats
├── test_stream_playback.js          # Stream deciphering & chunk validation test harness
└── package.json                     # Node dependencies & build scripts
```

---

## How It Works

### 1. Engine Initialization
When the app launches, `JSCYoutubeClient` creates an isolated iOS `JSContext`. It registers native Swift bridge functions (`__nativeFetch`, `__nativeGetRandomValues`, `__nativeLog`) and executes the `polyfills/*.js` files in order, followed by `runtime.bundle.js`. Once loaded, it initializes the `Innertube` instance in JS.

### 2. Search & Metadata Extraction
When searching for songs, queries are dispatched to the `youtubei.js` instance (`music.search` / `search`). Search results are transformed into strongly-typed Swift `Track` objects and returned to the SwiftUI views.

### 3. Stream Resolution & Deciphering
Upon playing a track, `getAudioStreamUrl` requests track info (`getBasicInfo`) across client fallbacks (`IOS` → `ANDROID` → `YTMUSIC`). It selects the optimal audio format (`audio/mp4` / `m4a`) and deciphers stream signatures if required.

### 4. Custom AVPlayer Stream Loading
Direct YouTube CDN audio URLs require specific header constraints and byte-range behaviors. The app utilizes `YTStreamResourceLoader`:
- It replaces standard `https://` URLs with a custom `ytaudio://` scheme, routing all byte requests to `YTStreamResourceLoader`.
- Each request is split into 64KB chunks and fetched via an ephemeral `URLSession` with YouTube's iOS `User-Agent`.
- Content metadata is reported to `AVPlayer` using the UTI `com.apple.m4a-audio`.

---

## Modular Web API Polyfills

Because iOS `JavaScriptCore` is a bare ECMAScript environment without DOM or browser APIs, the polyfill layer provides full compliance for YouTube.js requirements:

| Polyfill File | Web APIs Implemented | Swift Native Backing |
| :--- | :--- | :--- |
| `polyfills/00-console.js` | `console.log`, `warn`, `error`, `debug` | Swift `__nativeLog` |
| `polyfills/01-events.js` | `Event`, `CustomEvent`, `EventTarget` | Pure JS |
| `polyfills/02-text-encoding.js` | `TextEncoder`, `TextDecoder` (UTF-8, ASCII) | Pure JS |
| `polyfills/03-base64.js` | `atob`, `btoa` | Pure JS |
| `polyfills/04-url.js` | `URL`, `URLSearchParams` | Pure JS |
| `polyfills/05-fetch.js` | `fetch`, `Headers`, `Request`, `Response` | Swift `__nativeFetch` (`URLSession`) |
| `polyfills/06-crypto.js` | `crypto.getRandomValues`, `randomUUID`, `subtle` | Swift `SecRandomCopyBytes`, `CryptoKit` |
| `polyfills/07-timers.js` | `setTimeout`, `clearTimeout`, `setInterval`, `clearInterval` | Swift `DispatchQueue` |
| `polyfills/08-performance.js` | `performance.now()` | Swift `CACurrentMediaTime` |
| `polyfills/09-abort.js` | `AbortController`, `AbortSignal` | Pure JS |
| `polyfills/10-streams.js` | `ReadableStream`, `WritableStream`, `TransformStream` | WHATWG Streams Standard |

---

## Desktop Testing & Bundle Creation

To bundle `youtubei.js` or run JSC simulation tests locally:

```bash
# 1. Install dependencies
npm install

# 2. Bundle YouTube.js for JavaScriptCore
npm run bundle

# 3. Run bare JSC test simulation harness
npm test

# 4. Test music search & stream resolution logic
node test_music.js

# 5. Test audio stream playback & byte range loader logic
node test_stream_playback.js
```

---

## Building the iOS App

1. Open `YTJSMusic.xcodeproj` in Xcode.
2. Select target `YTJSMusic` and your target iOS device or simulator (iOS 15.0+ supported).
3. Build & Run (`Cmd + R`).

---

## License

This project is open source and available under the [MIT License](LICENSE).
