// YTJSMusic/Managers/AVPlayerPlaybackBackend.swift
import Foundation
import AVFoundation
import Combine

public class AVPlayerPlaybackBackend: NSObject, AudioPlaybackBackend {
    public weak var delegate: AudioPlaybackBackendDelegate?
    
    private var player: AVPlayer?
    private var streamResourceLoader: YTStreamResourceLoader?
    private var timeObserverToken: Any?
    private var statusObserverToken: NSKeyValueObservation?
    private var durationObserverToken: NSKeyValueObservation?
    private var likelyToKeepUpObserverToken: NSKeyValueObservation?
    private var bufferEmptyObserverToken: NSKeyValueObservation?
    
    private(set) public var isPlaying: Bool = false
    private(set) public var currentTime: Double = 0.0
    private(set) public var duration: Double = 0.0
    
    private let jscClient: JSCYoutubeClient
    
    public init(jscClient: JSCYoutubeClient) {
        self.jscClient = jscClient
        super.init()
    }
    
    public func play(track: Track, resolvedURL: URL, cacheKey: AudioStreamCacheKey) {
        stop()
        
        let loader = YTStreamResourceLoader(streamURL: resolvedURL, track: track, cacheKey: cacheKey, jscClient: jscClient)
        self.streamResourceLoader = loader
        
        guard let customURL = loader.getCustomSchemeURL() else {
            delegate?.playbackDidFail(error: "Failed to construct custom scheme URL")
            return
        }
        
        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(loader, queue: DispatchQueue.main)
        
        let item = AVPlayerItem(asset: asset)
        setupItemObservers(item: item)
        
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        self.player = newPlayer
        
        setupTimeObserver(player: newPlayer)
        
        newPlayer.play()
        self.isPlaying = true
    }
    
    public func pause() {
        player?.pause()
        isPlaying = false
    }
    
    public func resume() {
        player?.play()
        isPlaying = true
    }
    
    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    public func stop() {
        if let token = timeObserverToken, let p = player {
            p.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObserverToken?.invalidate()
        durationObserverToken?.invalidate()
        likelyToKeepUpObserverToken?.invalidate()
        bufferEmptyObserverToken?.invalidate()
        
        player?.pause()
        player = nil
        streamResourceLoader = nil
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
    }
    
    private func setupItemObservers(item: AVPlayerItem) {
        statusObserverToken = item.observe(\AVPlayerItem.status, options: [.new]) { [weak self] item, change in
            DispatchQueue.main.async {
                if item.status == .failed {
                    let err = item.error?.localizedDescription ?? "Playback error"
                    self?.delegate?.playbackDidFail(error: err)
                }
            }
        }
        
        durationObserverToken = item.observe(\AVPlayerItem.duration, options: [.new]) { [weak self] item, change in
            DispatchQueue.main.async {
                let secs = item.duration.seconds
                if !secs.isNaN && !secs.isInfinite && secs > 0 {
                    self?.duration = secs
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.delegate?.playbackDidEndTrack()
        }
    }
    
    private func setupTimeObserver(player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let secs = time.seconds
            if !secs.isNaN && !secs.isInfinite && secs >= 0 {
                self.currentTime = secs
                self.delegate?.playbackDidUpdateTime(currentTime: secs, duration: self.duration)
            }
        }
    }
}
