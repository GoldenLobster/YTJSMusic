// YTJSMusic/Models/PlaybackStartupTrace.swift
import Foundation
import QuartzCore

public enum PlaybackStartupResult {
    case playing
    case failed
    case timedOut
}

public struct PlaybackStartupTrace {
    public let trackID: String
    public let t0Tap: CFTimeInterval
    
    public var t1PlayInvoked: CFTimeInterval?
    public var t2CacheLookup: CFTimeInterval?
    public var t3ItemCreated: CFTimeInterval?
    public var t4FirstResourceRequest: CFTimeInterval?
    public var t5FirstBytesSupplied: CFTimeInterval?
    public var t6ReadyToPlay: CFTimeInterval?
    public var t7AVPlayerPlaying: CFTimeInterval?
    
    public var result: PlaybackStartupResult = .timedOut
    public var source: StreamSource?
    public var coverage: CacheCoverage = .none
    public var networkRequests: Int = 0
    public var bytesServedFromDisk: Int64 = 0
    public var bytesFetchedFromCDN: Int64 = 0
    
    public init(trackID: String) {
        self.trackID = trackID
        self.t0Tap = CACurrentMediaTime()
    }
    
    public func printSummary() {
        let now = t7AVPlayerPlaying ?? CACurrentMediaTime()
        let total = (now - t0Tap) * 1000
        
        let sourceStr: String
        if let src = source {
            switch src {
            case .cached: sourceStr = "CACHED"
            case .remote: sourceStr = "REMOTE"
            }
        } else {
            sourceStr = "UNKNOWN"
        }
        
        let log = """
        [STARTUP TRACE] Track: \(trackID) | Result: \(result) | Source: \(sourceStr) | Coverage: \(coverage)
          T0 tap                    0.000 ms
          T1 play invoked           \(fmt(t1PlayInvoked)) ms
          T2 cache lookup           \(fmt(t2CacheLookup)) ms
          T3 item created           \(fmt(t3ItemCreated)) ms
          T4 resource request       \(fmt(t4FirstResourceRequest)) ms
          T5 first bytes            \(fmt(t5FirstBytesSupplied)) ms
          T6 readyToPlay           \(fmt(t6ReadyToPlay)) ms
          T7 player playing        \(fmt(t7AVPlayerPlaying)) ms
          TOTAL                     \(String(format: "%.3f", total)) ms
          Metrics: DiskBytes=\(bytesServedFromDisk)b | CDNBytes=\(bytesFetchedFromCDN)b | CDNReqs=\(networkRequests)
        """
        print(log)
        SystemLogger.shared.append(log)
    }
    
    private func fmt(_ time: CFTimeInterval?) -> String {
        guard let t = time else { return "N/A" }
        return String(format: "%.3f", (t - t0Tap) * 1000)
    }
}
