// YTJSMusic/Managers/AudioPlayerManager.swift
import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI

public class AudioPlayerManager: ObservableObject {
    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var isShuffle: Bool = false
    @Published public var isRepeat: Bool = false
    @Published public var lastPlayerError: String? = nil
    
    @Published public var queue: [Track] = []
    @Published public var currentIndex: Int = 0
    private var originalQueue: [Track] = []
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var statusObserverToken: NSKeyValueObservation?
    private var durationObserverToken: NSKeyValueObservation?
    private var likelyToKeepUpObserverToken: NSKeyValueObservation?
    private var bufferEmptyObserverToken: NSKeyValueObservation?
    
    // MUST retain the resource loader — AVURLAsset holds only a weak delegate reference
    private var streamResourceLoader: YTStreamResourceLoader?
    
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
    
    public func playNext(track: Track) {
        if queue.isEmpty {
            playTrack(track: track)
        } else {
            let insertIndex = min(currentIndex + 1, queue.count)
            queue.insert(track, at: insertIndex)
            originalQueue.append(track)
        }
    }
    
    public func appendQueue(track: Track) {
        if queue.isEmpty {
            playTrack(track: track)
        } else {
            queue.append(track)
            originalQueue.append(track)
        }
    }
    
    public func jumpToQueueTrack(at index: Int) {
        guard index >= 0, index < queue.count else { return }
        currentIndex = index
        loadAndPlayCurrentTrack()
    }
    
    public var upcomingQueue: [Track] {
        guard !queue.isEmpty, currentIndex + 1 < queue.count else { return [] }
        return Array(queue[(currentIndex + 1)...])
    }
    
    public func removeUpcomingTrack(atRelativeIndex relIndex: Int) {
        let absIndex = currentIndex + 1 + relIndex
        guard absIndex > currentIndex, absIndex < queue.count else { return }
        queue.remove(at: absIndex)
    }
    
    public func reorderUpcomingQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !queue.isEmpty, currentIndex < queue.count else { return }
        var upcoming = upcomingQueue
        upcoming.moveQueueElements(fromOffsets: source, toOffset: destination)
        var newQueue = Array(queue[0...currentIndex])
        newQueue.append(contentsOf: upcoming)
        queue = newQueue
    }
    
    public func clearUpcomingQueue() {
        guard !queue.isEmpty, currentIndex < queue.count else { return }
        queue = Array(queue[0...currentIndex])
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
        guard let player = player else { return }
        let maxDur = duration > 0 ? duration : timeInSeconds
        let targetTime = Swift.min(Swift.max(timeInSeconds, 0.0), maxDur)
        let cmTime = CMTime(seconds: targetTime, preferredTimescale: 1000)
        
        self.currentTime = targetTime
        self.isLoading = true
        
        player.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] finished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if finished {
                    if self.isPlaying {
                        self.player?.play()
                    }
                }
            }
        }
    }
    
    private func loadAndPlayCurrentTrack() {
        guard currentIndex >= 0, currentIndex < queue.count else { return }
        let track = queue[currentIndex]
        self.currentTrack = track
        self.isLoading = true
        self.isPlaying = false
        self.currentTime = 0.0
        self.duration = track.durationInSeconds
        self.lastPlayerError = nil
        self.hasPrefetchedNextTrack = false
        
        let msg = "[AUDIO MANAGER] Requesting stream URL for '\(track.title)' (\(track.id))..."
        print(msg)
        SystemLogger.shared.append(msg)
        
        jscClient.getAudioStreamUrl(videoId: track.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let streamUrl):
                    let resLog = "[AUDIO MANAGER] Resolved stream URL (\(streamUrl.count) chars)"
                    print(resLog)
                    SystemLogger.shared.append(resLog)
                    
                    guard let url = URL(string: streamUrl), !streamUrl.isEmpty else {
                        self.isLoading = false
                        self.lastPlayerError = "Empty stream URL returned from YouTube.js"
                        SystemLogger.shared.append("[AUDIO MANAGER ERROR] Empty stream URL returned")
                        return
                    }
                    self.startAVPlayer(url: url, track: track)
                case .failure(let error):
                    let errLog = "[AUDIO MANAGER ERROR] Failed to get audio stream URL: \(error.localizedDescription)"
                    print(errLog)
                    SystemLogger.shared.append(errLog)
                    self.isLoading = false
                    self.lastPlayerError = error.localizedDescription
                }
            }
        }
    }
    
    private func startAVPlayer(url: URL, track: Track) {
        removeObservers()
        streamResourceLoader = nil  // release previous loader
        
        // Prefer exact metadata duration from YouTube Music API ("3:30" -> 210.0s)
        self.duration = track.durationInSeconds
        
        let (asset, loader) = YTStreamResourceLoader.makeAsset(for: url)
        streamResourceLoader = loader  // retain strongly
        
        let playMsg = "[AUDIO MANAGER] Playing via YTStreamResourceLoader: \(url.host ?? "googlevideo.com")"
        print(playMsg)
        SystemLogger.shared.append(playMsg)
        
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
                    let okMsg = "[AVPLAYER] Stream readyToPlay!"
                    print(okMsg)
                    SystemLogger.shared.append(okMsg)
                    self.isLoading = false
                    self.isPlaying = true
                    if self.duration == 0 {
                        let durSeconds = item.duration.seconds
                        if !durSeconds.isNaN && !durSeconds.isInfinite && durSeconds > 0 {
                            self.duration = durSeconds
                        }
                    }
                    self.updateNowPlayingInfo()
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    
                    var errDesc = "AVPlayer stream load failed"
                    if let nsErr = item.error as NSError? {
                        let underlying = nsErr.userInfo["NSUnderlyingError"] as? NSError
                        errDesc = underlying?.localizedDescription ?? nsErr.localizedDescription
                        let failMsg = "[AVPLAYER FAILED] Domain: \(nsErr.domain) Code: \(nsErr.code) Details: \(nsErr.userInfo)"
                        print(failMsg)
                        SystemLogger.shared.append(failMsg)
                    }
                    self.lastPlayerError = errDesc
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // KVO observer on playerItem duration metadata updates (fallback if metadata duration was 0)
        durationObserverToken = playerItem.observe(\.duration, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.duration == 0 {
                    let durSeconds = item.duration.seconds
                    if !durSeconds.isNaN && !durSeconds.isInfinite && durSeconds > 0 {
                        self.duration = durSeconds
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
        
        // KVO observer on buffer likelihood - resumes play automatically after seeking or buffering
        likelyToKeepUpObserverToken = playerItem.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] (item: AVPlayerItem, _: NSKeyValueObservedChange<Bool>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.isPlaybackLikelyToKeepUp {
                    self.isLoading = false
                    if self.isPlaying {
                        self.player?.play()
                    }
                }
            }
        }
        
        // KVO observer on buffer empty state
        bufferEmptyObserverToken = playerItem.observe(\AVPlayerItem.isPlaybackBufferEmpty, options: [.new]) { [weak self] (item: AVPlayerItem, _: NSKeyValueObservedChange<Bool>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.isPlaybackBufferEmpty {
                    self.isLoading = true
                }
            }
        }
        
        // Add end of track observer
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        // Add periodic time observer for current playback position
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.checkPrefetchThreshold(currentTime: self.currentTime, duration: self.duration)
            
            // Auto advance if current time exceeds track duration
            if self.duration > 0 && self.currentTime >= self.duration - 0.5 {
                self.handleTrackEnded()
            } else {
                self.updateNowPlayingInfo()
            }
        }
        
        player?.play()
        updateNowPlayingInfo()
    }
    
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        handleTrackEnded()
    }
    
    private func handleTrackEnded() {
        DispatchQueue.main.async { [weak self] in
            self?.nextTrack()
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
        
        likelyToKeepUpObserverToken?.invalidate()
        likelyToKeepUpObserverToken = nil
        
        bufferEmptyObserverToken?.invalidate()
        bufferEmptyObserverToken = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // MARK: - Smart Two-Level Duration Prefetcher
    private var hasPrefetchedNextTrack: Bool = false
    
    private func checkPrefetchThreshold(currentTime: Double, duration: Double) {
        guard duration > 0, !hasPrefetchedNextTrack, let nextTrack = upcomingQueue.first else { return }
        
        let remainingSeconds = duration - currentTime
        let thresholdSeconds: Double
        if duration < 180 { // < 3 min
            thresholdSeconds = 20
        } else if duration < 480 { // 3-8 min
            thresholdSeconds = 30
        } else { // > 8 min
            thresholdSeconds = 45
        }
        
        if remainingSeconds <= thresholdSeconds {
            hasPrefetchedNextTrack = true
            prefetchNextTrack(nextTrack)
        }
    }
    
    private func prefetchNextTrack(_ track: Track) {
        SystemLogger.shared.append("[PREFETCH] Triggering two-level prefetch for '\(track.title)' (\(track.id))")
        jscClient.getAudioStreamUrl(videoId: track.id) { [weak self] result in
            if case .success(let urlString) = result, let url = URL(string: urlString) {
                SystemLogger.shared.append("[PREFETCH LEVEL 1 SUCCESS] Resolved stream URL for '\(track.title)'")
                
                let policy = NetworkPathMonitor.shared.currentPolicy
                let fetchBytes = policy.prefetchBytes
                guard fetchBytes > 0 else { return }
                
                let cacheKey = AudioStreamCacheKey(videoID: track.id, itag: 140, mimeType: "audio/mp4", codec: "mp4a.40.2", container: "m4a")
                let range = NSRange(location: 0, length: Int(fetchBytes))
                
                var req = URLRequest(url: url)
                req.setValue("bytes=0-\(fetchBytes - 1)", forHTTPHeaderField: "Range")
                URLSession.shared.dataTask(with: req) { data, _, _ in
                    if let data = data, !data.isEmpty {
                        Task {
                            await AudioStreamCacheManager.shared.writeChunk(key: cacheKey, range: range, data: data, isPrefetch: true)
                            SystemLogger.shared.append("[PREFETCH LEVEL 2 SUCCESS] Cached \(data.count) initial bytes for '\(track.title)'")
                        }
                    }
                }.resume()
            }
        }
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

extension Array {
    mutating func moveQueueElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        var movingElements = [Element]()
        for index in source {
            if index < count {
                movingElements.append(self[index])
            }
        }
        
        var result = [Element]()
        result.reserveCapacity(count)
        for (index, element) in self.enumerated() {
            if !source.contains(index) {
                result.append(element)
            }
        }
        
        let removedBeforeDest = source.filter { $0 < destination }.count
        let targetIndex = Swift.max(0, Swift.min(destination - removedBeforeDest, result.count))
        result.insert(contentsOf: movingElements, at: targetIndex)
        self = result
    }
}
