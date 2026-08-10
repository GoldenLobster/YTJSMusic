// YTJSMusic/Services/NetworkPathMonitor.swift
import Foundation
import Network
import Combine

public enum PrefetchPolicy {
    case aggressive  // 2 MB on Wi-Fi unconstrained
    case balanced    // 256 KB on Cellular
    case conservative// 128 KB on Constrained/Expensive
    case offline     // Cache only
    
    public var prefetchBytes: Int64 {
        switch self {
        case .aggressive: return 2 * 1024 * 1024
        case .balanced: return 256 * 1024
        case .conservative: return 128 * 1024
        case .offline: return 0
        }
    }
}

public class NetworkPathMonitor: ObservableObject {
    public static let shared = NetworkPathMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.antigravity.networkmonitor")
    
    @Published public var isConnected: Bool = true
    @Published public var isWiFi: Bool = true
    @Published public var isExpensive: Bool = false
    @Published public var isConstrained: Bool = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.isWiFi = path.usesInterfaceType(.wifi)
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
            }
        }
        monitor.start(queue: queue)
    }
    
    public var currentPolicy: PrefetchPolicy {
        guard isConnected else { return .offline }
        if isConstrained || isExpensive {
            return .conservative
        } else if isWiFi {
            return .aggressive
        } else {
            return .balanced
        }
    }
}
