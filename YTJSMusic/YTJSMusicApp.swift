// YTJSMusic/YTJSMusicApp.swift
import SwiftUI

@main
struct YTJSMusicApp: App {
    @StateObject private var jscClient: JSCYoutubeClient
    @StateObject private var audioManager: AudioPlayerManager
    @StateObject private var playlistManager: PlaylistManager
    
    @State private var isBundleLoaded: Bool = false
    @State private var logs: [String] = ["Initializing YouTube Music Engine..."]
    @State private var initError: String? = nil
    
    init() {
        // Start Local HTTP Proxy Server on 127.0.0.1:8080 for AVPlayer stream requests
        LocalAudioProxyServer.shared.start()
        
        let client = JSCYoutubeClient()
        let audioMgr = AudioPlayerManager(jscClient: client)
        let playlistMgr = PlaylistManager()
        
        _jscClient = StateObject(wrappedValue: client)
        _audioManager = StateObject(wrappedValue: audioMgr)
        _playlistManager = StateObject(wrappedValue: playlistMgr)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isBundleLoaded {
                    MainTabView(jscClient: jscClient, audioManager: audioManager, playlistManager: playlistManager)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Engine Startup")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.bottom, 8)
                        
                        if let error = initError {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Initialization Failed", systemImage: "xmark.octagon.fill")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Text("System Logs:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(logs.enumerated()), id: \.offset) { idx, log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(log.contains("ERROR") || log.contains("Failed") ? .red : .primary)
                                            .id(idx)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .onChange(of: logs.count) { newCount in
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                    .padding(24)
                    .onAppear {
                        loadEngine()
                    }
                }
            }
        }
    }
    
    private func appendLog(_ message: String) {
        DispatchQueue.main.async {
            print("[APP LOG]", message)
            self.logs.append(message)
        }
    }
    
    private func loadEngine() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.appendLog("Step 1: Locating polyfill files in main bundle...")
                var polyfillPaths: [String] = []
                
                if let polyfillsFolder = Bundle.main.path(forResource: "polyfills", ofType: nil) {
                    let files = try FileManager.default.contentsOfDirectory(atPath: polyfillsFolder)
                    polyfillPaths = files.filter { $0.hasSuffix(".js") }.sorted().map { (polyfillsFolder as NSString).appendingPathComponent($0) }
                    self.appendLog("Found \(polyfillPaths.count) polyfill scripts in polyfills/ folder.")
                } else {
                    self.appendLog("polyfills/ folder not found, checking top-level bundle resources...")
                    let paths = Bundle.main.paths(forResourcesOfType: "js", inDirectory: nil)
                    polyfillPaths = paths.filter { !$0.contains("runtime.bundle") }.sorted()
                    self.appendLog("Found \(polyfillPaths.count) polyfill scripts in bundle root.")
                }
                
                guard let bundlePath = Bundle.main.path(forResource: "runtime.bundle", ofType: "js") else {
                    throw NSError(domain: "YTJSMusicApp", code: -1, userInfo: [NSLocalizedDescriptionKey: "runtime.bundle.js is missing from app bundle resources!"])
                }
                self.appendLog("Step 2: Located runtime.bundle.js (\((try? FileManager.default.attributesOfItem(atPath: bundlePath)[.size] as? Int64) ?? 0) bytes)")
                
                self.appendLog("Step 3: Loading polyfills and runtime bundle into JavaScriptCore...")
                try jscClient.loadPolyfillsAndBundle(polyfillScriptPaths: polyfillPaths, bundlePath: bundlePath)
                self.appendLog("Polyfills and bundle loaded into JSContext cleanly!")
                
                self.appendLog("Step 4: Calling Innertube.create()...")
                jscClient.initializeInnertube { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self.appendLog("Innertube initialized successfully! Launching UI...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.isBundleLoaded = true
                            }
                        case .failure(let err):
                            self.appendLog("ERROR: Innertube initialization failed: \(err.localizedDescription)")
                            self.initError = err.localizedDescription
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.appendLog("ERROR: Engine setup failed: \(error.localizedDescription)")
                    self.initError = error.localizedDescription
                }
            }
        }
    }
}
