// YTJSMusic/Managers/AudioPlayerManager.swift
import Foundation
import AVFoundation
import MediaPlayer
import Combine

public class AudioPlayerManager: ObservableObject {
    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false
    @Published public var lastPlayerError: String? = nil
    
    public var queue: [Track] = []
    private var originalQueue: [Track] = []
    private var currentIndex: Int = 0
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var statusObserverToken: NSKeyValueObservation?
    private var durationObserverToken: NSKeyValueObservation?
    
    private let resourceLoaderDelegate = JSCStreamLoaderDelegate()
    private let jscClient: JSCYoutubeClient
    
    public init(jscClient: JSCYoutubeClient) {
        self.jscClient = jscClient
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to set AVAudioSession category:", error)
        }
    }
    
    public func playQueue(tracks: [Track], startIndex: Int = 0) {
        guard !tracks.isEmpty, startIndex >= 0, startIndex < tracks.count else { return }
        self.originalQueue = tracks
        
        if isShuffle {
            var shuffled = tracks
            let selected = shuffled.remove(at: startIndex)
            shuffled.shuffle()
            shuffled.insert(selected, at: 0)
            self.queue = shuffled
            self.currentIndex = 0
        } else {
            self.queue = tracks
            self.currentIndex = startIndex
        }
        
        loadAndPlayCurrentTrack()
    }
    
    public func playTrack(track: Track) {
        playQueue(tracks: [track], startIndex: 0)
    }
    
    public func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }
    
    public func nextTrack() {
        guard !queue.isEmpty else { return }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadAndPlayCurrentTrack()
        } else if isRepeat {
            currentIndex = 0
            loadAndPlayCurrentTrack()
        }
    }
    
    public func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0.0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlayCurrentTrack()
        }
    }
    
    public func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            if let current = currentTrack {
                var remaining = originalQueue.filter { $0.id != current.id }
                remaining.shuffle()
                remaining.insert(current, at: 0)
                queue = remaining
                currentIndex = 0
            }
        } else {
            queue = originalQueue
            if let current = currentTrack, let idx = queue.firstIndex(where: { $0.id == current.id }) {
                currentIndex = idx
            }
        }
    }
    
    public func toggleRepeat() {
        isRepeat.toggle()
    }
    
    public func seek(to timeInSeconds: Double) {
        let cmTime = CMTime(seconds: timeInSeconds, preferredTimescale: 1000)
        player?.seek(to: cmTime)
    }
    
    private func loadAndPlayCurrentTrack() {
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let track = queue[currentIndex]
        self.currentTrack = track
        self.isLoading = true
        self.isPlaying = false
        self.currentTime = 0.0
        self.duration = 0.0
        self.lastPlayerError = nil
        
        print("[AUDIO MANAGER] Requesting stream URL for \(track.title) (\(track.id))...")
        
        jscClient.getAudioStreamUrl(videoId: track.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let streamUrl):
                    print("[AUDIO MANAGER] Resolved stream URL length: \(streamUrl.count)")
                    guard let url = URL(string: streamUrl), !streamUrl.isEmpty else {
                        self.isLoading = false
                        self.lastPlayerError = "Empty stream URL returned from YouTube.js"
                        return
                    }
                    self.startAVPlayer(url: url, track: track)
                case .failure(let error):
                    print("[AUDIO MANAGER ERROR] Failed to get audio stream URL:", error)
                    self.isLoading = false
                    self.lastPlayerError = error.localizedDescription
                }
            }
        }
    }
    
    private func startAVPlayer(url: URL, track: Track) {
        removeObservers()
        
        // Convert https:// to custom-stream:// so JSCStreamLoaderDelegate intercepts and injects YouTube headers
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "custom-stream"
        
        guard let customURL = components?.url else {
            self.isLoading = false
            self.lastPlayerError = "Invalid custom-stream URL format"
            return
        }
        
        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: DispatchQueue.main)
        
        let playerItem = AVPlayerItem(asset: asset)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        // KVO observer on playerItem status (readyToPlay vs failed)
        statusObserverToken = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    print("[AVPLAYER] Stream readyToPlay!")
                    self.isLoading = false
                    self.isPlaying = true
                    let durSeconds = item.duration.seconds
                    if !durSeconds.isNaN && !durSeconds.isInfinite && durSeconds > 0 {
                        self.duration = durSeconds
                    }
                    self.updateNowPlayingInfo()
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    
                    var errDesc = "AVPlayer stream load failed"
                    if let nsErr = item.error as NSError? {
                        let underlying = nsErr.userInfo["NSUnderlyingError"] as? NSError
                        errDesc = underlying?.localizedDescription ?? nsErr.localizedDescription
                        print("[AVPLAYER FAILED] Domain: \(nsErr.domain) Code: \(nsErr.code) Details: \(nsErr.userInfo)")
                    }
                    self.lastPlayerError = errDesc
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // KVO observer on playerItem duration metadata updates
        durationObserverToken = playerItem.observe(\.duration, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let durSeconds = item.duration.seconds
                if !durSeconds.isNaN && !durSeconds.isInfinite && durSeconds > 0 {
                    self.duration = durSeconds
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        // Add end of track observer
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        // Add periodic time observer for current playback position
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let currentItem = self.player?.currentItem else { return }
            self.currentTime = time.seconds
            let dur = currentItem.duration.seconds
            if !dur.isNaN && !dur.isInfinite && dur > 0 {
                self.duration = dur
            }
            self.updateNowPlayingInfo()
        }
        
        player?.play()
        updateNowPlayingInfo()
    }
    
    @objc private func playerItemDidReachEnd() {
        DispatchQueue.main.async {
            self.nextTrack()
        }
    }
    
    private func removeObservers() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObserverToken?.invalidate()
        statusObserverToken = nil
        
        durationObserverToken?.invalidate()
        durationObserverToken = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // MARK: - Lock Screen Controls & Artwork Setup
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
