# YouTube.js in iOS JavaScriptCore (JSC) Polyfills & Swift Integration

This project provides a complete, modular polyfill system and Swift native bridge to run **YouTube.js** (`youtubei.js`) inside iOS `JavaScriptCore` (`JSContext`) without requiring a `WKWebView`.

## Architecture & Modular Polyfills

iOS `JavaScriptCore` is a pure ECMAScript runtime that lacks DOM and Web APIs. Following an **iterative library-outward design**, YouTube.js was loaded into a bare JSC context, and missing Web APIs were identified one-by-one and implemented in isolated, modular polyfill files:

| Modular Polyfill | Included Web APIs / Specs | Backed By Native Swift Bridge? |
| :--- | :--- | :--- |
| `polyfills/00-console.js` | `console.log`, `info`, `warn`, `error`, `debug` | Swift `__nativeLog` |
| `polyfills/01-events.js` | `Event`, `CustomEvent`, `EventTarget` | Pure JS |
| `polyfills/02-text-encoding.js` | `TextEncoder`, `TextDecoder` (UTF-8, ASCII) | Pure JS |
| `polyfills/03-base64.js` | `atob`, `btoa` | Pure JS |
| `polyfills/04-url.js` | `URL`, `URLSearchParams` | Pure JS |
| `polyfills/05-fetch.js` | `fetch`, `Headers`, `Request`, `Response` | Swift `__nativeFetch` (`URLSession`) |
| `polyfills/06-crypto.js` | `crypto.getRandomValues`, `randomUUID`, `subtle` | Swift `__nativeGetRandomValues`, `SecRandomCopyBytes`, `CryptoKit` |
| `polyfills/07-timers.js` | `setTimeout`, `clearTimeout`, `setInterval`, `clearInterval`, `queueMicrotask` | Swift `__nativeSetTimeout`, `DispatchQueue` |
| `polyfills/08-performance.js` | `performance.now()` | Swift `__nativePerformanceNow` (`CACurrentMediaTime`) |
| `polyfills/09-abort.js` | `AbortController`, `AbortSignal` | Pure JS |
| `polyfills/10-streams.js` | `ReadableStream`, `WritableStream`, `TransformStream` | WHATWG Streams Standard |

---

## Directory Structure

```
youtube-jsc-test/
├── package.json               # Node setup & esbuild bundler script
├── entry.js                   # Entry point importing youtubei.js/web.bundle
├── runtime.bundle.js          # IIFE bundle of YouTube.js generated for JSC
├── run.js                     # Bare JSC runner harness (simulating iOS JSContext)
├── polyfills/                 # Modular polyfills loaded on-demand
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
└── Swift/                     # Native iOS Swift backing & client bridge
    ├── JSCPolyfillBridge.swift
    └── JSCYoutubeClient.swift
```

---

## Desktop Testing (Simulating iOS JavaScriptCore)

To test the bundle and polyfills on Fedora desktop or any system with Node:

```bash
# 1. Install dependencies
npm install

# 2. Bundle YouTube.js
npm run bundle

# 3. Run bare JSC test simulation
npm test
```

### What `npm test` Validates:
- Loads all `polyfills/*.js` files in order into a bare `vm.createContext({})` with zero Node globals.
- Loads `runtime.bundle.js`.
- Initializes `Innertube.create()`.
- Executes video search (`yt.search("Swift iOS")`).
- Retrieves video metadata (`yt.getInfo(videoId)`).
- Deciphers adaptive audio/video stream URLs.

---

## iOS Swift Integration Guide

To use YouTube.js inside your iOS application:

1. **Add `runtime.bundle.js` and `polyfills/*.js`** to your Xcode app bundle.
2. **Add `JSCPolyfillBridge.swift` and `JSCYoutubeClient.swift`** to your Swift project.
3. **Usage in Swift**:

```swift
import Foundation
import JavaScriptCore

let client = JSCYoutubeClient()

// 1. Load polyfills & YouTube.js bundle
let polyfillPaths = Bundle.main.paths(forResourcesOfType: "js", inDirectory: "polyfills")
let bundlePath = Bundle.main.path(forResource: "runtime.bundle", ofType: "js")!

try client.loadPolyfillsAndBundle(polyfillScriptPaths: polyfillPaths.sorted(), bundlePath: bundlePath)

// 2. Initialize Innertube
client.initializeInnertube { result in
    switch result {
    case .success:
        print("YouTube.js initialized in JSC!")
        
        // 3. Search videos
        client.search(query: "Swift UI") { searchResult in
            if case .success(let videos) = searchResult {
                print("Found \(videos.count) videos!")
                if let firstVideo = videos.first, let videoId = firstVideo["id"] as? String {
                    
                    // 4. Get video info & decipher stream URL
                    client.getStreamingUrl(videoId: videoId, type: "audio") { urlResult in
                        if case .success(let streamUrl) = urlResult {
                            print("Playable Audio Stream URL:", streamUrl)
                        }
                    }
                }
            }
        }
        
    case .failure(let error):
        print("Initialization failed:", error)
    }
}
```
