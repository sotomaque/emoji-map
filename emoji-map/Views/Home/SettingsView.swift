import SwiftUI
import os.log

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userPreferences: UserPreferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var showResetConfirmation = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "SettingsView")
    
    var body: some View {
        NavigationStack {
            Form {
                // Appearance section
                Section(header: Text("Appearance")) {
                    Toggle("Use Dark Mode", isOn: $userPreferences.useDarkMode)
                        .onChange(of: userPreferences.useDarkMode) { oldValue, newValue in
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
                    .onChange(of: userPreferences.distanceUnit) { oldValue, newValue in
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(userPreferences: UserPreferences())
    }
} 
