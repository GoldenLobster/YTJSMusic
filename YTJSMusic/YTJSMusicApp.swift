// YTJSMusic/YTJSMusicApp.swift
import SwiftUI

@main
struct YTJSMusicApp: App {
    @StateObject private var jscClient: JSCYoutubeClient
    @StateObject private var audioManager: AudioPlayerManager
    @StateObject private var playlistManager: PlaylistManager
    
    @State private var isBundleLoaded: Bool = false
    @State private var initError: String? = nil
    
    init() {
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
                } else if let error = initError {
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                        Text("Initialization Error")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Initializing YouTube Music Engine...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        loadEngine()
                    }
                }
            }
        }
    }
    
    private func loadEngine() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var polyfillPaths: [String] = []
                
                // Find polyfills in bundle
                if let polyfillsFolder = Bundle.main.path(forResource: "polyfills", ofType: nil) {
                    let files = try FileManager.default.contentsOfDirectory(atPath: polyfillsFolder)
                    polyfillPaths = files.filter { $0.hasSuffix(".js") }.sorted().map { (polyfillsFolder as NSString).appendingPathComponent($0) }
                } else {
                    // Fallback to top-level resources
                    for i in 0...10 {
                        let name = String(format: "%02d", i)
                        if let res = Bundle.main.path(forResource: name, ofType: "js") {
                            polyfillPaths.append(res)
                        }
                    }
                }
                
                guard let bundlePath = Bundle.main.path(forResource: "runtime.bundle", ofType: "js") else {
                    throw NSError(domain: "YTJSMusicApp", code: -1, userInfo: [NSLocalizedDescriptionKey: "runtime.bundle.js missing from app bundle"])
                }
                
                try jscClient.loadPolyfillsAndBundle(polyfillScriptPaths: polyfillPaths, bundlePath: bundlePath)
                
                jscClient.initializeInnertube { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self.isBundleLoaded = true
                        case .failure(let err):
                            self.initError = err.localizedDescription
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.initError = error.localizedDescription
                }
            }
        }
    }
}
