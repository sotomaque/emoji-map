import SwiftUI
import os.log

struct CacheSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCachingEnabled: Bool
    @State private var placesExpirationDays: Double
    @State private var detailsExpirationHours: Double
    @State private var showResetConfirmation = false
    @State private var showClearConfirmation = false
    @State private var cacheStats: (hits: Int, misses: Int, entries: Int, placesExpiration: TimeInterval, detailsExpiration: TimeInterval, enabled: Bool)
    
    // Reference to the cache
    private let cache = NetworkCache.shared
    
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "CacheSettingsView")
    
    init() {
        let stats = NetworkCache.shared.getCacheStatistics()
        _isCachingEnabled = State(initialValue: stats.enabled)
        _placesExpirationDays = State(initialValue: stats.placesExpiration / (24 * 60 * 60)) // Convert seconds to days
        _detailsExpirationHours = State(initialValue: stats.detailsExpiration / (60 * 60)) // Convert seconds to hours
        _cacheStats = State(initialValue: stats)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Cache Control Section
                Section(header: Text("Cache Control")) {
                    Toggle("Enable Caching", isOn: $isCachingEnabled)
                        .onChange(of: isCachingEnabled) { oldValue, newValue in
                            cache.setCachingEnabled(newValue)
                            refreshStats()
                        }
                    
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Cache")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(!isCachingEnabled)
                }
                
                // Cache Expiration Section
                Section(header: Text("Cache Expiration")) {
                    VStack(alignment: .leading) {
                        Text("Places Cache: \(Int(placesExpirationDays)) days")
                            .font(.subheadline)
                        
                        Slider(value: $placesExpirationDays, in: 1...30, step: 1)
                            .onChange(of: placesExpirationDays) { oldValue, newValue in
                                // Convert days to seconds
                                let seconds = newValue * 24 * 60 * 60
                                cache.setPlacesExpiration(seconds)
                                refreshStats()
                            }
                    }
                    .disabled(!isCachingEnabled)
                    
                    VStack(alignment: .leading) {
                        Text("Details Cache: \(Int(detailsExpirationHours)) hours")
                            .font(.subheadline)
                        
                        Slider(value: $detailsExpirationHours, in: 1...48, step: 1)
                            .onChange(of: detailsExpirationHours) { oldValue, newValue in
                                // Convert hours to seconds
                                let seconds = newValue * 60 * 60
                                cache.setDetailsExpiration(seconds)
                                refreshStats()
                            }
                    }
                    .disabled(!isCachingEnabled)
                }
                
                // Cache Statistics Section
                Section(header: Text("Cache Statistics")) {
                    HStack {
                        Text("Cache Hits")
                        Spacer()
                        Text("\(cacheStats.hits)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Cache Misses")
                        Spacer()
                        Text("\(cacheStats.misses)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Entries")
                        Spacer()
                        Text("\(cacheStats.entries)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Hit Rate")
                        Spacer()
                        Text(hitRateString)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        refreshStats()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Statistics")
                        }
                    }
                }
                
                // Cache Inspection Section
                Section(header: Text("Cache Inspection")) {
                    ForEach(cache.getActiveCacheKeys(), id: \.self) { key in
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                // Reset Section
                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Reset Cache Settings")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Cache Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Cache Settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetCacheSettings()
                }
            } message: {
                Text("This will reset all cache settings to their default values. This action cannot be undone.")
            }
            .alert("Clear Cache?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear all cached data. This action cannot be undone.")
            }
            .onAppear {
                refreshStats()
            }
        }
    }
    
    private var hitRateString: String {
        let total = cacheStats.hits + cacheStats.misses
        if total == 0 {
            return "0%"
        }
        
        let hitRate = Double(cacheStats.hits) / Double(total) * 100
        return String(format: "%.1f%%", hitRate)
    }
    
    private func refreshStats() {
        cacheStats = cache.getCacheStatistics()
    }
    
    private func clearCache() {
        cache.clearCache()
        refreshStats()
    }
    
    private func resetCacheSettings() {
        cache.resetCacheSettings()
        
        // Update local state
        isCachingEnabled = true
        placesExpirationDays = cache.getCacheStatistics().placesExpiration / (24 * 60 * 60)
        detailsExpirationHours = cache.getCacheStatistics().detailsExpiration / (60 * 60)
        
        refreshStats()
    }
}

struct CacheSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CacheSettingsView()
    }
} 
