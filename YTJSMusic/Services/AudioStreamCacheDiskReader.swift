// YTJSMusic/Services/AudioStreamCacheDiskReader.swift
import Foundation

public struct DiskReadResult {
    public let data: Data
    public let coveredRange: Range<Int64>
    public let isCompleteRequest: Bool
}

public final class AudioStreamCacheDiskReader {
    public static let shared = AudioStreamCacheDiskReader()
    
    private let cacheDirectory: URL
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("AudioStreamCache", isDirectory: true)
    }
    
    public func readChunkSync(key: AudioStreamCacheKey, requestedRange: NSRange) -> DiskReadResult? {
        guard let info = AudioStreamCacheIndex.shared.getStreamInfo(key: key) else { return nil }
        
        let reqStart = Int64(requestedRange.location)
        let reqEnd = Int64(requestedRange.location + requestedRange.length - 1)
        
        let streamDir = cacheDirectory.appendingPathComponent(key.storageString, isDirectory: true)
        
        // Find cached ranges that overlap starting from reqStart
        var currentOffset = reqStart
        var combinedData = Data()
        
        // Sort cached ranges by start offset
        let sortedRanges = info.cachedRanges.sorted { $0.location < $1.location }
        
        for r in sortedRanges {
            let rStart = Int64(r.location)
            let rEnd = Int64(r.location + r.length - 1)
            
            if currentOffset >= rStart && currentOffset <= rEnd {
                // Found next contiguous chunk! Read file
                let chunkURL = streamDir.appendingPathComponent("\(rStart)-\(rEnd).chunk")
                guard let fileData = try? Data(contentsOf: chunkURL) else { break }
                
                let fileOffset = Int(currentOffset - rStart)
                let remainingReqLength = Int(reqEnd - currentOffset + 1)
                let availableLength = fileData.count - fileOffset
                
                let bytesToCopy = min(remainingReqLength, availableLength)
                if bytesToCopy > 0 {
                    let sub = fileData.subdata(in: fileOffset..<(fileOffset + bytesToCopy))
                    combinedData.append(sub)
                    currentOffset += Int64(bytesToCopy)
                }
                
                if currentOffset > reqEnd {
                    break // Whole requested range served!
                }
            }
        }
        
        guard !combinedData.isEmpty else { return nil }
        
        let covered = reqStart..<currentOffset
        let isComplete = currentOffset > reqEnd
        return DiskReadResult(data: combinedData, coveredRange: covered, isCompleteRequest: isComplete)
    }
}
