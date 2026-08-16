// YTJSMusic/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var audioManager: AudioPlayerManager
    @ObservedObject var networkMonitor = NetworkPathMonitor.shared
    @ObservedObject var logger = SystemLogger.shared
    
    @State private var usedBytes: Int64 = 0
    @State private var maxBytes: Int64 = 500 * 1024 * 1024
    @State private var streamCount: Int = 0
    @State private var hitCount: Int = 0
    @State private var missCount: Int = 0
    @State private var avoidedRequests: Int = 0
    @State private var isClearing: Bool = false
    @State private var isCopied: Bool = false
    @State private var logSearchText: String = ""
    @State private var showLogsSheet: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // Storage & Cache Section
                Section(header: Text("Storage & Audio Cache")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Disk Cache Usage")
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
                    
                    ProgressView(value: Double(usedBytes), total: Double(max(maxBytes, 1)))
                        .accentColor(.red)
                }
                
                // Network & Prefetching Section
                Section(header: Text("Network & Prefetching")) {
                    HStack {
                        Label("Connection Status", systemImage: networkMonitor.isWiFi ? "wifi" : (networkMonitor.isConnected ? "antenna.radiowaves.left.and.right" : "wifi.slash"))
                        Spacer()
                        Text(networkMonitor.isWiFi ? "Wi-Fi" : (networkMonitor.isConnected ? "Cellular" : "Offline"))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Prefetch Policy", systemImage: "bolt.horizontal.fill")
                        Spacer()
                        Text(policyName(networkMonitor.currentPolicy))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }
                
                // Cache Performance Diagnostics
                Section(header: Text("Cache Performance")) {
                    HStack {
                        Text("Hit / Miss Ratio")
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
                }
                
                // Diagnostic Logs Section
                Section(header: Text("System & Playback Logs")) {
                    NavigationLink(destination: FullDiagnosticsLogView()) {
                        HStack {
                            Label("Diagnostic Logs", systemImage: "terminal.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(logger.logs.count) lines")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Button(action: {
                            UIPasteboard.general.string = logger.getLogs()
                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                isCopied = false
                            }
                        }) {
                            Label(isCopied ? "Copied to Clipboard!" : "Copy Full Logs", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(isCopied ? .green : .red)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            logger.clear()
                        }) {
                            Text("Clear Logs")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (YTJSMusic)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Audio Backend")
                        Spacer()
                        Text("Native AVPlayer / ResourceLoader")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Catalog Provider")
                        Spacer()
                        Text("Apple Music Catalog / LRCLIB")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .padding(.bottom, audioManager.currentTrack != nil ? 110 : 20)
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

struct FullDiagnosticsLogView: View {
    @ObservedObject var logger = SystemLogger.shared
    @State private var searchText: String = ""
    @State private var isCopied: Bool = false
    
    var filteredLogs: [String] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return logger.logs
        }
        return logger.logs.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search / Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter logs...", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(line.contains("FAILED") || line.contains("ERROR") ? .red : (line.contains("CACHE HIT") || line.contains("SUCCESS") ? .green : .primary))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("Diagnostic Logs")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: HStack(spacing: 12) {
                Button(action: {
                    UIPasteboard.general.string = filteredLogs.joined(separator: "\n")
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isCopied = false
                    }
                }) {
                    Text(isCopied ? "Copied!" : "Copy")
                }
                
                Button(action: {
                    logger.clear()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        )
    }
}
