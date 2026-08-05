// YTJSMusic/Managers/ResolverCoordinator.swift
import Foundation

public class ResolverCoordinator {
    public static let shared = ResolverCoordinator()
    
    private var inFlightRequests: [String: [(Result<ResolutionResult, Error>) -> Void]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Executes a resolution action or attaches to an existing in-flight resolution for the specified appleId
    public func resolve(appleId: String, executeTask: @escaping (@escaping (Result<ResolutionResult, Error>) -> Void) -> Void, completion: @escaping (Result<ResolutionResult, Error>) -> Void) {
        lock.lock()
        if inFlightRequests[appleId] != nil {
            inFlightRequests[appleId]?.append(completion)
            lock.unlock()
            print("[RESOLVER COORDINATOR] Attached to existing in-flight resolution for: \(appleId)")
            return
        }
        
        inFlightRequests[appleId] = [completion]
        lock.unlock()
        
        executeTask { [weak self] result in
            self?.lock.lock()
            let callbacks = self?.inFlightRequests.removeValue(forKey: appleId) ?? []
            self?.lock.unlock()
            
            for cb in callbacks {
                cb(result)
            }
        }
    }
}
