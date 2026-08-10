// YTJSMusic/Managers/AudioPlaybackBackend.swift
import Foundation

public protocol AudioPlaybackBackendDelegate: AnyObject {
    func playbackDidUpdateTime(currentTime: Double, duration: Double)
    func playbackDidEndTrack()
    func playbackDidFail(error: String)
}

public protocol AudioPlaybackBackend: AnyObject {
    var delegate: AudioPlaybackBackendDelegate? { get set }
    var isPlaying: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    
    func play(track: Track, resolvedURL: URL, cacheKey: AudioStreamCacheKey)
    func pause()
    func resume()
    func seek(to time: Double)
    func stop()
}
