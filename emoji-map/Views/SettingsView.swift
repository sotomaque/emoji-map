import SwiftUI

struct SettingsView: View {
    @ObservedObject var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var showOnboarding = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Information")) {
                    HStack {
                        Image("AppIcon")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emoji Map")
                                .font(.headline)
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Display Preferences")) {
                    // Distance unit picker
                    Picker("Distance Units", selection: $userPreferences.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .onChange(of: userPreferences.distanceUnit) { newValue in
                        userPreferences.setDistanceUnit(newValue)
                    }
                    
                    // Default map app picker
                    Picker("Default Map App", selection: $userPreferences.defaultMapApp) {
                        ForEach(MapAppUtility.shared.getInstalledMapApps()) { app in
                            Text(app.rawValue).tag(app.rawValue)
                        }
                    }
                    .onChange(of: userPreferences.defaultMapApp) { newValue in
                        userPreferences.setDefaultMapApp(newValue)
                    }
                }
                
                Section(header: Text("Help & Support")) {
                    Button(action: {
                        // Provide haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Show onboarding
                        showOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("View Tutorial")
                        }
                    }
                    
                    Link(destination: URL(string: "mailto:support@example.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact Support")
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    Text("Emoji Map helps you discover restaurants and bars around you with a fun, emoji-based interface. Filter by food type, save your favorites, and explore your city in a new way!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text("Data Management")) {
                    Button(action: {
                        // Provide haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Show reset confirmation
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset All Data")
                                .foregroundColor(.red)
                        }
                    }
                    .alert(isPresented: $showResetConfirmation) {
                        Alert(
                            title: Text("Reset All Data?"),
                            message: Text("This will delete all your favorites, ratings, and preferences. This action cannot be undone."),
                            primaryButton: .destructive(Text("Reset")) {
                                // Provide strong haptic feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                
                                // Reset user data
                                userPreferences.resetAllData()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                Section(header: Text("Legal")) {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("Terms of Service")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(userPreferences: userPreferences, isFromSettings: true)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(userPreferences: UserPreferences())
    }
} 