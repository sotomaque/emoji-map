import SwiftUI
import os.log

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userPreferences: UserPreferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDebugInfo = false
    @State private var debugInfo = ""
    @State private var showResetConfirmation = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "SettingsView")
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance section
                Section(header: Text("Appearance")) {
                    Toggle("Use Dark Mode", isOn: $userPreferences.useDarkMode)
                        .onChange(of: userPreferences.useDarkMode) { _ in
                            userPreferences.saveAppearancePreferences()
                        }
                }
                
                // Distance Units section
                Section(header: Text("Distance Units")) {
                    Picker("Distance Units", selection: $userPreferences.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: userPreferences.distanceUnit) { _ in
                        userPreferences.setDistanceUnit(userPreferences.distanceUnit)
                    }
                }
                
                // Cache Settings section
                Section(header: Text("Cache Settings")) {
                    NavigationLink(destination: CacheSettingsView()) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Manage Cache")
                        }
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Show Onboarding") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            userPreferences.hasCompletedOnboarding = false
                        }
                    }
                    
                    Button("Reset All Settings") {
                        showResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                // Debug section
                Section(header: Text("Debug Information")) {
                    Toggle("Show API Key Debug Info", isOn: $showDebugInfo)
                    
                    if showDebugInfo {
                        Button("Check API Key Configuration") {
                            generateDebugInfo()
                        }
                        
                        if !debugInfo.isEmpty {
                            Text(debugInfo)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    userPreferences.resetAllData()
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
            .onAppear {
                // Set dark mode to match system on first launch
                if !userPreferences.userDefaults.bool(forKey: "has_set_dark_mode") {
                    userPreferences.useDarkMode = colorScheme == .dark
                    userPreferences.saveAppearancePreferences()
                    userPreferences.userDefaults.set(true, forKey: "has_set_dark_mode")
                }
            }
        }
    }
    
    private func generateDebugInfo() {
        var info = "API KEY DEBUG INFO:\n\n"
        
        // Check environment variables
        let envVars = ProcessInfo.processInfo.environment
        info += "Environment Variables Count: \(envVars.count)\n"
        
        if let key = envVars["GOOGLE_PLACES_API_KEY"] {
            info += "✅ GOOGLE_PLACES_API_KEY found in environment\n"
            info += "   Value: \(key.prefix(4))...\(key.suffix(4))\n"
        } else {
            info += "❌ GOOGLE_PLACES_API_KEY not found in environment\n"
            
            // List some environment variables as examples
            let sampleKeys = Array(envVars.keys.prefix(5))
            info += "   Sample env vars: \(sampleKeys.joined(separator: ", "))\n"
        }
        
        // Check if using mock data
        if Configuration.isUsingMockKey {
            info += "⚠️ App is using mock data\n"
        } else {
            info += "✅ App is using real API key\n"
        }
        
        // Check for .env file in bundle
        if let envURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            info += "✅ .env file found in bundle\n"
            
            do {
                let contents = try String(contentsOf: envURL, encoding: .utf8)
                let lines = contents.components(separatedBy: .newlines)
                
                var foundKey = false
                for line in lines {
                    if line.hasPrefix("GOOGLE_PLACES_API_KEY=") {
                        foundKey = true
                        info += "✅ GOOGLE_PLACES_API_KEY found in .env file\n"
                        break
                    }
                }
                
                if !foundKey {
                    info += "❌ GOOGLE_PLACES_API_KEY not found in .env file\n"
                }
            } catch {
                info += "❌ Error reading .env file: \(error.localizedDescription)\n"
            }
        } else {
            info += "❌ .env file not found in bundle\n"
        }
        
        // Check bundle resources
        info += "\nBundle Resources (sample):\n"
        if let resourcePaths = Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil) as [String]? {
            let resourceNames = resourcePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
            info += resourceNames.prefix(10).joined(separator: ", ")
            info += resourceNames.count > 10 ? "... (and \(resourceNames.count - 10) more)" : ""
        }
        
        debugInfo = info
        logger.debug("\n\n\(info)\n\n")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(userPreferences: UserPreferences())
    }
} 
