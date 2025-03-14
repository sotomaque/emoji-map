//
//  SettingsSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/14/25.
//

import SwiftUI
import os.log
import Combine
import CoreLocation
import MapKit
import _MapKit_SwiftUI
import SwiftUICore

struct SettingsSheet: View {
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "SettingsSheet")
    
    // ViewModel
    @ObservedObject var viewModel: HomeViewModel
    
    // Access to user preferences
    @ObservedObject private var userPreferences = ServiceContainer.shared.userPreferences
    
    // State for showing onboarding
    @State private var showOnboarding = false
    
    // State for confirmation dialog
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("⚙️")
                    .font(.largeTitle)
            }
            .padding(.bottom, 8)
            
            // Divider
            Divider()
            
            // App Settings Section
            VStack(alignment: .leading, spacing: 12) {
                Text("App Settings")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                // View Onboarding Button
                Button(action: {
                    logger.notice("View onboarding requested")
                    showOnboarding = true
                }) {
                    HStack {
                        Image(systemName: "book")
                            .foregroundColor(.blue)
                        Text("View Onboarding")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reset All Settings Button
                Button(action: {
                    logger.notice("Reset all settings requested")
                    showResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                        Text("Reset All Settings")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            
            // Developer Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Developer")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                // Places Cache Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Places Cache")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(viewModel.places.count) places")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Filtered Places")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(viewModel.filteredPlaces.count) places")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Selected Categories")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(viewModel.selectedCategoryKeys.count) categories")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Clear Cache Button
                Button(action: {
                    viewModel.clearPlaces()
                    viewModel.placesService.clearCache()
                    logger.notice("Cache cleared from settings")
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear Places Cache")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh Places Button
                Button(action: {
                    viewModel.refreshPlaces(clearExisting: true)
                    logger.notice("Places refreshed from settings")
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("Refresh Places")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            // Version info
            Text("Version 1.0.0 (Build 42)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
        }
        .padding()
        .onAppear {
            logger.notice("Settings sheet appeared")
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(userPreferences: userPreferences, isFromSettings: true)
        }
        .confirmationDialog(
            "Reset All Settings?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                // Reset all settings
                ServiceContainer.shared.resetAllServices()
                logger.notice("All settings have been reset")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values and clear all cached data. This action cannot be undone.")
        }
    }
}

#Preview {
    // Create a mock HomeViewModel for the preview
    let mockService = PreviewMockPlacesService()
    let viewModel = HomeViewModel(placesService: mockService)
    
    // Add some mock data
    viewModel.places = [
        Place(id: "1", emoji: "🍕", location: Place.Location(latitude: 37.7749, longitude: -122.4194)),
        Place(id: "2", emoji: "🍺", location: Place.Location(latitude: 37.7749, longitude: -122.4194))
    ]
    viewModel.filteredPlaces = [viewModel.places[0]]
    viewModel.selectedCategoryKeys = [1]
    
    return SettingsSheet(viewModel: viewModel)
}

// Mock service for preview
private class PreviewMockPlacesService: PlacesServiceProtocol {
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool) async throws -> [Place] {
        return []
    }
    
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int]) async throws -> [Place] {
        return []
    }
    
    @MainActor func clearCache() {
        // No-op for preview
    }
} 