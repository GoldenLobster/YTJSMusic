# 🛠️ Development & CI/CD Guide

This guide covers building the runtime bundle, running desktop simulation test harnesses, configuring Xcode, and deploying via GitHub Actions.

---

## 1. Prerequisites & Environment Setup

- **macOS Sonoma / Sequoia**
- **Xcode 15.0+** (with iOS 15.0+ SDK)
- **Node.js 18+** & **npm**
- **Git**

---

## 2. Bundling YouTube.js (`runtime.bundle.js`)

The JavaScript runtime bundle encapsulates `youtubei.js` into a standalone IIFE (Immediately Invoked Function Expression) for execution inside iOS `JSContext`.

### Build Script:
```bash
# Install node dependencies
npm install

# Bundle entry.js into runtime.bundle.js using esbuild
npm run bundle
```

### Configuration Details (`package.json`):
```json
{
  "scripts": {
    "bundle": "esbuild entry.js --bundle --format=iife --global-name=YTJSBundle --outfile=runtime.bundle.js --target=safari15 --platform=neutral"
  }
}
```

---

## 3. Desktop Test Harnesses

YTJSMusic includes simulation scripts to test JavaScriptCore and InnerTube streaming logic on desktop before compiling for iOS:

### Test 1: Bare JSC Music Search & Formats
```bash
node test_music.js
```
*Validates YouTube Music catalog queries, client emulation, and track metadata transformation.*

### Test 2: Audio Stream Deciphering & Playback
```bash
node test_stream_playback.js
```
*Validates InnerTube stream extraction, signature deciphering, and byte range responses.*

### Test 3: Complete InnerTube Flow Simulation
```bash
node test_youtube_flow.js
```
*Simulates the full Swift `JSCYoutubeClient` environment using Node's `vm` module and the 11 polyfill scripts.*

---

## 4. Xcode Project Configuration

1. Open `YTJSMusic.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**:
   - Ensure your Development Team is selected.
   - Verify **Background Modes** has **Audio, AirPlay, and Picture in Picture** checked.
3. Verify that `runtime.bundle.js` and all files in `polyfills/` are included in the **Copy Bundle Resources** build phase.
4. Select `YTJSMusic` scheme $\to$ Choose your iOS Device or Simulator $\to$ Build & Run (`Cmd + R`).

---

## 5. GitHub Actions Automated CI/CD

YTJSMusic includes a GitHub Actions workflow (`.github/workflows/build-ipa.yml`) configured for automated compilation and artifact archiving on every push to `master`:

```yaml
name: Build iOS IPA
on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install dependencies & bundle JS
        run: |
          npm ci
          npm run bundle
      - name: Build Xcode Project
        run: |
          xcodebuild -project YTJSMusic.xcodeproj \
                     -scheme YTJSMusic \
                     -sdk iphonesimulator \
                     -configuration Release \
                     CODE_SIGN_IDENTITY="" \
                     CODE_SIGNING_REQUIRED=NO \
                     CODE_SIGNING_ALLOWED=NO \
                     build
```
