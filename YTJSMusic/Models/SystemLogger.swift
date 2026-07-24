// YTJSMusic/Models/SystemLogger.swift
import Foundation
import Combine

public class SystemLogger: ObservableObject {
    public static let shared = SystemLogger()
    
    @Published public var logs: [String] = ["App Starting..."]
    
    private let queue = DispatchQueue(label: "com.antigravity.logger", attributes: .concurrent)
    
    public func append(_ message: String) {
        DispatchQueue.main.async {
            print("[DIAGNOSTIC]", message)
            self.logs.append(message)
        }
    }
}
