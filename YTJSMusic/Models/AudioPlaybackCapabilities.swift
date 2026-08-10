// YTJSMusic/Models/AudioPlaybackCapabilities.swift
import Foundation

public struct AudioPlaybackCapabilities {
    public let preferredCodecs: [String]
    public let supportedCodecs: Set<String>
    public let supportedContainers: Set<String>
    
    public init(preferredCodecs: [String], supportedCodecs: Set<String>, supportedContainers: Set<String>) {
        self.preferredCodecs = preferredCodecs
        self.supportedCodecs = supportedCodecs
        self.supportedContainers = supportedContainers
    }
    
    public static let defaultAVPlayer = AudioPlaybackCapabilities(
        preferredCodecs: ["mp4a.40.2"],
        supportedCodecs: ["mp4a.40.2"],
        supportedContainers: ["m4a"]
    )
}
