// YTJSMusic/Views/CacheSettingsView.swift
import SwiftUI

struct CacheSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var networkMonitor = NetworkPathMonitor.shared
    
    @State private var usedBytes: Int64 = 0
    @State private var maxBytes: Int64 = 500 * 1024 * 1024
    @State private var streamCount: Int = 0
    @State private var hitCount: Int = 0
    @State private var missCount: Int = 0
    @State private var avoidedRequests: Int = 0
    @State private var isClearing: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Storage & Cache")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache Usage")
                                .font(.headline)
                            Text("\(formatBytes(usedBytes)) of \(formatBytes(maxBytes)) used (\(streamCount) cached streams)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: clearCache) {
                            if isClearing {
                                ProgressView()
                            } else {
                                Text("Clear Cache")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    ProgressView(value: Double(usedBytes), total: Double(maxBytes))
                        .accentColor(.red)
                }
                
                Section(header: Text("Network & Prefetching")) {
                    HStack {
                        Text("Current Network Status")
                        Spacer()
                        Text(networkMonitor.isWiFi ? "Wi-Fi" : (networkMonitor.isConnected ? "Cellular" : "Offline"))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Prefetch Strategy")
                        Spacer()
                        Text(policyName(networkMonitor.currentPolicy))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Developer Diagnostics")) {
                    HStack {
                        Text("Cache Hit / Miss Ratio")
                        Spacer()
                        Text(hitRatioString)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Avoided CDN Requests")
                        Spacer()
                        Text("\(avoidedRequests)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Cached Ranges Map")
                        Spacer()
                        Text(hitCount > 0 ? "████████░░░░" : "░░░░░░░░░░░░")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Cache & Performance")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                refreshStats()
            }
        }
    }
    
    private var hitRatioString: String {
        let total = hitCount + missCount
        guard total > 0 else { return "N/A" }
        let pct = (Double(hitCount) / Double(total)) * 100.0
        return String(format: "%.1f%% (%d hits / %d total)", pct, hitCount, total)
    }
    
    private func policyName(_ policy: PrefetchPolicy) -> String {
        switch policy {
        case .aggressive: return "Aggressive (2MB)"
        case .balanced: return "Balanced (256KB)"
        case .conservative: return "Conservative (128KB)"
        case .offline: return "Offline (Cache Only)"
        }
    }
    
    private func refreshStats() {
        Task {
            let stats = await AudioStreamCacheManager.shared.getStats()
            DispatchQueue.main.async {
                self.usedBytes = stats.usedBytes
                self.maxBytes = stats.maxBytes
                self.streamCount = stats.streamCount
                self.hitCount = stats.hitCount
                self.missCount = stats.missCount
                self.avoidedRequests = stats.avoidedCDNRequests
            }
        }
    }
    
    private func clearCache() {
        isClearing = true
        Task {
            await AudioStreamCacheManager.shared.clearCache()
            DispatchQueue.main.async {
                self.isClearing = false
                self.refreshStats()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1000 {
            return String(format: "%.2f GB", mb / 1024.0)
        }
        return String(format: "%.1f MB", mb)
    }
}
