// YTJSMusic/Managers/AudioPlayerManager.swift
import Foundation
import AVFoundation
import MediaPlayer
import Combine
import SwiftUI
import UIKit

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
    
    private var currentArtworkImage: UIImage?
    private var currentArtworkTrackId: String?
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var statusObserverToken: NSKeyValueObservation?
    private var durationObserverToken: NSKeyValueObservation?
    private var likelyToKeepUpObserverToken: NSKeyValueObservation?
    private var bufferEmptyObserverToken: NSKeyValueObservation?
    private var timeControlStatusObserverToken: NSKeyValueObservation?
    
    // Playback Health Diagnostics
    private var watchdogTimer: Timer?
    
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
            stopWatchdog()
        } else {
            player.play()
            isPlaying = true
            startWatchdog()
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
    
    private var currentTrace: PlaybackStartupTrace?
    
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
        
        self.fetchArtwork(for: track)
        
        var trace = PlaybackStartupTrace(trackID: track.id)
        trace.t1PlayInvoked = CACurrentMediaTime()
        self.currentTrace = trace
        
        // 1. Check AudioStreamCacheIndex for playable stream (0ms network delay)
        if let cachedInfo = AudioStreamCacheIndex.shared.cachedPlayableStream(for: track.id, capabilities: .defaultAVPlayer) {
            trace.t2CacheLookup = CACurrentMediaTime()
            let ref = CachedStreamReference(key: cachedInfo.key, contentLength: cachedInfo.contentLength, mimeType: cachedInfo.mimeType, coverage: cachedInfo.coverage)
            let source = StreamSource.cached(ref)
            trace.source = source
            trace.coverage = cachedInfo.coverage
            
            let bypassMsg = "[AUDIO MANAGER CACHE BYPASS] Playable stream found in cache (\(cachedInfo.key.codec)). Starting local playback..."
            print(bypassMsg)
            SystemLogger.shared.append(bypassMsg)
            
            self.startAVPlayer(source: source, track: track, trace: trace)
            return
        }
        
        // 2. Uncached track: resolve stream URL via YouTube.js
        let msg = "[AUDIO MANAGER] Requesting stream URL for '\(track.title)' (\(track.id))..."
        print(msg)
        SystemLogger.shared.append(msg)
        
        jscClient.getAudioStreamUrl(videoId: track.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentTrace?.t2CacheLookup = CACurrentMediaTime()
                switch result {
                case .success(let streamUrl):
                    let resLog = "[AUDIO MANAGER] Resolved stream URL (\(streamUrl.count) chars)"
                    print(resLog)
                    SystemLogger.shared.append(resLog)
                    
                    guard let url = URL(string: streamUrl), !streamUrl.isEmpty else {
                        self.isLoading = false
                        self.lastPlayerError = "Empty stream URL returned from YouTube.js"
                        SystemLogger.shared.append("[AUDIO MANAGER ERROR] Empty stream URL returned")
                        self.currentTrace?.result = .failed
                        self.currentTrace?.printSummary()
                        return
                    }
                    
                    let defaultKey = AudioStreamCacheKey(videoID: track.id, itag: 140, mimeType: "audio/mp4; codecs=\"mp4a.40.2\"", codec: "mp4a.40.2", container: "m4a")
                    let ref = RemoteStreamReference(key: defaultKey, initialURL: url)
                    let source = StreamSource.remote(ref)
                    if var tr = self.currentTrace {
                        tr.source = source
                        tr.coverage = .none
                        self.currentTrace = tr
                        self.startAVPlayer(source: source, track: track, trace: tr)
                    }
                case .failure(let error):
                    let errLog = "[AUDIO MANAGER ERROR] Failed to get audio stream URL: \(error.localizedDescription)"
                    print(errLog)
                    SystemLogger.shared.append(errLog)
                    self.isLoading = false
                    self.lastPlayerError = error.localizedDescription
                    self.currentTrace?.result = .failed
                    self.currentTrace?.printSummary()
                }
            }
        }
    }
    
    private func startAVPlayer(source: StreamSource, track: Track, trace: PlaybackStartupTrace) {
        removeObservers()
        streamResourceLoader = nil  // release previous loader
        isTransitioningTrack = false
        hasPrefetchedNextTrack = false
        
        // Prefer exact metadata duration from YouTube Music API ("3:30" -> 210.0s)
        self.duration = track.durationInSeconds
        
        let loader = YTStreamResourceLoader(streamSource: source, track: track, jscClient: jscClient)
        loader.trace = trace
        streamResourceLoader = loader  // retain strongly
        
        let customURL = loader.customSchemeURL
        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        
        var mutTrace = trace
        mutTrace.t3ItemCreated = CACurrentMediaTime()
        self.currentTrace = mutTrace
        
        let playMsg = "[AUDIO MANAGER] Playing via YTStreamResourceLoader: \(customURL.absoluteString)"
        print(playMsg)
        SystemLogger.shared.append(playMsg)
        
        let playerItem = AVPlayerItem(asset: asset)
        if case .cached = source {
            playerItem.preferredForwardBufferDuration = 0.5
        }
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        if case .cached = source {
            player?.automaticallyWaitsToMinimizeStalling = false
        } else {
            player?.automaticallyWaitsToMinimizeStalling = true
        }
        
        // KVO observer on playerItem status (readyToPlay vs failed)
        statusObserverToken = playerItem.observe(\AVPlayerItem.status, options: NSKeyValueObservingOptions([.new, .initial])) { [weak self] (item: AVPlayerItem, change: NSKeyValueObservedChange<AVPlayerItem.Status>) in
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
                    
                    if var tr = self.currentTrace, tr.t6ReadyToPlay == nil {
                        tr.t6ReadyToPlay = CACurrentMediaTime()
                        tr.t7AVPlayerPlaying = CACurrentMediaTime()
                        tr.result = .playing
                        if let ldrTr = self.streamResourceLoader?.trace {
                            tr.networkRequests = ldrTr.networkRequests
                            tr.bytesServedFromDisk = ldrTr.bytesServedFromDisk
                            tr.bytesFetchedFromCDN = ldrTr.bytesFetchedFromCDN
                        }
                        tr.printSummary()
                        self.currentTrace = tr
                    }
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
                    
                    if var tr = self.currentTrace {
                        tr.result = .failed
                        tr.printSummary()
                    }
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        // KVO observer on playerItem duration metadata updates (fallback if metadata duration was 0)
        durationObserverToken = playerItem.observe(\AVPlayerItem.duration, options: NSKeyValueObservingOptions([.new])) { [weak self] (item: AVPlayerItem, change: NSKeyValueObservedChange<CMTime>) in
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
        likelyToKeepUpObserverToken = playerItem.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: NSKeyValueObservingOptions([.new])) { [weak self] (item: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) in
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
        bufferEmptyObserverToken = playerItem.observe(\AVPlayerItem.isPlaybackBufferEmpty, options: NSKeyValueObservingOptions([.new])) { [weak self] (item: AVPlayerItem, change: NSKeyValueObservedChange<Bool>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if item.isPlaybackBufferEmpty {
                    self.isLoading = true
                    SystemLogger.shared.append("[AVPLAYER BUFFER] Playback buffer empty at \(String(format: "%.1f", self.currentTime))s")
                }
            }
        }
        
        // KVO observer on player timeControlStatus
        timeControlStatusObserverToken = player?.observe(\AVPlayer.timeControlStatus, options: NSKeyValueObservingOptions([.new])) { [weak self] (p: AVPlayer, change: NSKeyValueObservedChange<AVPlayer.TimeControlStatus>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch p.timeControlStatus {
                case .paused:
                    break
                case .waitingToPlayAtSpecifiedRate:
                    let reason = p.reasonForWaitingToPlay?.rawValue ?? "unknown"
                    SystemLogger.shared.append("[AVPLAYER WAITING] Reason: \(reason) at \(String(format: "%.1f", self.currentTime))s")
                case .playing:
                    self.isLoading = false
                    self.isPlaying = true
                @unknown default:
                    break
                }
            }
        }
        
        // Add end of track and playback stall observers
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayerItemPlaybackStalled(_:)), name: .AVPlayerItemPlaybackStalled, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayerItemErrorLog(_:)), name: .AVPlayerItemNewErrorLogEntry, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlayerItemAccessLog(_:)), name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
        
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
        startWatchdog()
        updateNowPlayingInfo()
    }
    
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        handleTrackEnded()
    }
    
    @objc private func handlePlayerItemPlaybackStalled(_ notification: Notification) {
        SystemLogger.shared.append("[AVPLAYER STALLED] Playback stalled temporarily at \(String(format: "%.1f", currentTime))s (buffering...)")
    }
    
    @objc private func handlePlayerItemErrorLog(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, let errorLog = item.errorLog() else { return }
        for event in errorLog.events {
            SystemLogger.shared.append("[AVPLAYER ERROR LOG] Domain: \(event.errorDomain) Code: \(event.errorStatusCode) Comment: \(event.errorComment ?? "none")")
        }
    }
    
    @objc private func handlePlayerItemAccessLog(_ notification: Notification) {
        // Intentionally silent unless fatal
    }
    
    // MARK: - Playback Health Diagnostics (Passive & Safe)
    private var lastDiagnosticLogTime: CFTimeInterval = 0
    
    private func startWatchdog() {
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.watchdogCheck()
        }
    }
    
    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
    
    private func watchdogCheck() {
        guard let player = player, let item = player.currentItem, isPlaying else { return }
        
        let now = CACurrentMediaTime()
        let timeControl = player.timeControlStatus
        let isBufferEmpty = item.isPlaybackBufferEmpty
        
        if isBufferEmpty || timeControl == .waitingToPlayAtSpecifiedRate {
            if now - lastDiagnosticLogTime >= 15.0 {
                lastDiagnosticLogTime = now
                let reason = player.reasonForWaitingToPlay?.rawValue ?? "buffering"
                SystemLogger.shared.append("[PLAYBACK BUFFERING] Pos=\(String(format: "%.1f", currentTime))s | Status=\(reason)")
            }
        }
    }
    
    private var isTransitioningTrack: Bool = false
    
    private func handleTrackEnded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isTransitioningTrack else { return }
            self.isTransitioningTrack = true
            self.nextTrack()
        }
    }
    
    private func removeObservers() {
        stopWatchdog()
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
        
        timeControlStatusObserverToken?.invalidate()
        timeControlStatusObserverToken = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewErrorLogEntry, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemNewAccessLogEntry, object: nil)
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
        jscClient.getAudioStreamUrl(videoId: track.id) { result in
            if case .success(let urlString) = result, let url = URL(string: urlString) {
                SystemLogger.shared.append("[PREFETCH LEVEL 1 SUCCESS] Resolved stream URL for '\(track.title)'")
                
                let policy = NetworkPathMonitor.shared.currentPolicy
                let fetchBytes = policy.prefetchBytes
                guard fetchBytes > 0 else { return }
                
                let cacheKey = AudioStreamCacheKey(videoID: track.id, itag: 140, mimeType: "audio/mp4", codec: "mp4a.40.2", container: "m4a")
                let range = NSRange(location: 0, length: Int(fetchBytes))
                
                var req = URLRequest(url: url)
                req.setValue("bytes=0-\(fetchBytes - 1)", forHTTPHeaderField: "Range")
                URLSession.shared.dataTask(with: req) { data, response, _ in
                    if let data = data, !data.isEmpty {
                        var totalLen: Int64 = 0
                        if let http = response as? HTTPURLResponse {
                            for (k, v) in http.allHeaderFields {
                                if "\(k)".lowercased() == "content-range",
                                   let totalStr = "\(v)".components(separatedBy: "/").last,
                                   let parsed = Int64(totalStr.trimmingCharacters(in: .whitespaces)), parsed > 0 {
                                    totalLen = parsed
                                    break
                                }
                            }
                        }
                        let finalTotalLen = totalLen
                        Task {
                            await AudioStreamCacheManager.shared.writeChunk(key: cacheKey, range: range, data: data, isPrefetch: true)
                            if finalTotalLen > 0 {
                                await AudioStreamCacheManager.shared.updateContentLength(key: cacheKey, length: finalTotalLen)
                            }
                            SystemLogger.shared.append("[PREFETCH LEVEL 2 SUCCESS] Cached \(data.count) initial bytes (total \(finalTotalLen)b) for '\(track.title)'")
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
    
    private func fetchArtwork(for track: Track) {
        guard let url = URL(string: track.thumbnail), !track.thumbnail.isEmpty else {
            self.currentArtworkImage = nil
            self.currentArtworkTrackId = track.id
            self.updateNowPlayingInfo()
            return
        }
        
        if currentArtworkTrackId == track.id && currentArtworkImage != nil {
            return
        }
        
        currentArtworkTrackId = track.id
        currentArtworkImage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                if self.currentTrack?.id == track.id {
                    self.currentArtworkImage = image
                    self.updateNowPlayingInfo()
                }
            }
        }.resume()
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let image = currentArtworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
        }
        
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
