//
//  ContentView.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = {
        MainActor.assumeIsolated {
            ServiceContainer.shared.mapViewModel
        }
    }()
    @State private var lastHapticTime: Date = Date.distantPast
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var lastRegionChangeTime: Date = Date.distantPast
    @State private var debounceTimer: Timer?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Map as base layer - updated for iOS 17
            Map(position: $mapPosition) {
                // Use the new MapContentBuilder syntax
                ForEach(viewModel.filteredPlaces) { place in
                    Annotation(
                        coordinate: place.coordinate,
                        content: {
                            PlaceAnnotation(
                                emoji: viewModel
                                    .categoryEmoji(for: place.category),
                                isFavorite: viewModel
                                    .isFavorite(placeId: place.placeId),
                                rating: viewModel.getRating(for: place.placeId),
                                onTap: {
                                    viewModel.selectedPlace = place
                                }
                            )
                            // Use a stable ID that doesn't change when panning the map
                            // This prevents existing annotations from flashing
                            .id(place.placeId)
                        },
                        label: {
                            // Empty label since we're using custom annotation view
                            EmptyView()
                        }
                    )
                }
                
                // Add user location marker
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                // Optional: Add map controls if needed
                // MapCompass()
                // MapScaleView()
            }
            .onMapCameraChange { context in
                // Update the region and center coordinate when the map camera changes
                let newRegion = MKCoordinateRegion(
                    center: context.region.center,
                    span: context.region.span
                )
                viewModel.region = newRegion
                
                // Update center coordinate and handle region change with debounce
                let newCenter = newRegion.center
                if centerCoordinate.latitude != newCenter.latitude || centerCoordinate.longitude != newCenter.longitude {
                    centerCoordinate = newCenter
                    handleRegionChangeWithDebounce()
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            if !viewModel.isLocationAvailable && !viewModel.isLocationPermissionDenied {
                // Progress view when location isn't available but not denied - use minimal style
                VStack {
                    Spacer()
                    
                    UnifiedLoadingIndicator(
                        message: "Finding your location...",
                        style: .minimal,
                        backgroundColor: Color(.systemBackground).opacity(0.8)
                    )
                    .padding(.bottom, 40)
                    
                    Spacer()
                }
            } else {
                // Normal content when location is available or permission is denied
                VStack(spacing: 8) {
                    // Emoji selector at the top
                    EmojiSelector()
                        .environmentObject(viewModel)
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.7 : 1.0) 
                
                    // Single banner that shows either config warning or notification
                    Banner(
                        // If there's a config warning, show that, otherwise show notification message
                        message: viewModel.showConfigWarning ? viewModel.configWarningMessage : viewModel.notificationMessage,
                        // Show if either config warning or notification is active
                        isVisible: viewModel.showConfigWarning || viewModel.showNotification,
                        // Use warning style for config warnings, notification style otherwise
                        style: viewModel.showConfigWarning ? .warning : .notification,
                        onAppear: {
                            // Only trigger haptic feedback for notifications, not config warnings
                            if viewModel.showNotification && !viewModel.showConfigWarning {
                                triggerHapticFeedback()
                            }
                        }
                    )
                    
                    Spacer()
                    
                    if viewModel.showSearchHereButton {
                        SearchHereButton(
                            action: {
                                viewModel.searchHere()
                            },
                            isLoading: viewModel.isLoading
                        )
                        .padding(.bottom, 40)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7),
                            value: viewModel.showSearchHereButton
                        )
                    }
                }
                .zIndex(20)
                
                // Recenter button
                RecenterButton(
                    isLoading: viewModel.isLoading,
                    action: {
                        withAnimation {
                            viewModel.recenterMap()
                        }
                    }
                )
                .position(
                    x: UIScreen.main.bounds.width - 40,
                    y: UIScreen.main.bounds.height - 120
                ) // Bottom-right corner
                .zIndex(
                    20
                ) // Higher than notification but lower than emoji selector
                
                // FiltersButton - moved to bottom left
                Button(action: {
                    viewModel.showFilters = true
                }) {
                    FiltersButton(
                        activeFilterCount: viewModel.activeFilterCount
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .position(
                    x: 40,
                    y: UIScreen.main.bounds.height - 120
                ) // Bottom-left corner
                .zIndex(
                    20
                ) // Higher than notification but lower than emoji selector
                // Add long press gesture for settings (easter egg)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            // Provide escalating haptic feedback
                            provideSettingsHapticFeedback()
                            
                            // Show settings
                            showSettings = true
                        }
                )
            }
            
            // Location permission view overlay
            if viewModel.showLocationPermissionView {
                ZStack {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    LocationPermissionView(
                        onOpenSettings: {
                            viewModel.openAppSettings()
                        },
                        onContinueWithoutLocation: {
                            viewModel.continueWithoutLocation()
                        }
                    )
                    .transition(.scale)
                }
                .zIndex(100) // Ensure it's above everything else
            }
        }
        .onAppear {
            viewModel.onAppear()
            // Initialize the center coordinate
            centerCoordinate = viewModel.region.center
            
            // Set initial map position
            mapPosition = .region(viewModel.region)
            
            // Force UI refresh to ensure favorites are properly displayed
            viewModel.objectWillChange.send()
            
            // Set up a publisher to observe region changes
            viewModel.onRegionDidChange = { newRegion in
                // Update map position when region changes
                self.mapPosition = .region(newRegion)
                print("Map region updated to: \(newRegion.center)")
            }
        }
        .onDisappear {
            // Clean up the timer when the view disappears
            debounceTimer?.invalidate()
            debounceTimer = nil
            
            // Remove the region change callback
            viewModel.onRegionDidChange = nil
        }
        .sheet(item: $viewModel.selectedPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
                    .environmentObject(viewModel)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
            .presentationBackground {
                Color(.systemGroupedBackground)
                    .opacity(0.98)
            }
        }
        .alert(
isPresented: $viewModel.showError,
 content: {
            Alert(
                title: Text("Error"),
                message: Text(
                    viewModel.error?.localizedDescription ?? "An unknown error occurred"
                ),
                primaryButton: .default(Text("Retry")) {
                    viewModel.retryFetchPlaces()
                },
                secondaryButton: .cancel()
            )
 })
        // Add sheet for filters
        .sheet(isPresented: $viewModel.showFilters) {
            FiltersView(
                selectedPriceLevels: viewModel.selectedPriceLevels,
                showOpenNowOnly: viewModel.showOpenNowOnly,
                minimumRating: viewModel.minimumRating,
                useLocalRatings: viewModel.useLocalRatings,
                onApplyFilters: nil
            )
            .environmentObject(viewModel)
        }
        // Add sheet for settings
        .sheet(isPresented: $showSettings) {
            SettingsView(userPreferences: viewModel.preferences)
        }
    }
     // Function to provide escalating haptic feedback for settings access
    private func provideSettingsHapticFeedback() {
        // Use the centralized HapticsManager for escalating feedback
        HapticsManager.shared.escalatingSequence()
    }
    
    
    // Haptic feedback function
    private func triggerHapticFeedback() {
        // Prevent multiple haptics in quick succession
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) > 1.0 {
            HapticsManager.shared.notification(type: .success)
            lastHapticTime = now
        }
    }
    
    private func handleRegionChangeWithDebounce() {
        // Cancel any existing timer on the main thread
        debounceTimer?.invalidate()
        
        // Create a new timer that will fire after a short delay
        debounceTimer = Timer
            .scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                // Only process region changes that are at least 0.5 seconds apart
                let now = Date()
                if now.timeIntervalSince(self.lastRegionChangeTime) >= 0.5 {
                    self.lastRegionChangeTime = now
                
                    // Always dispatch to the main actor to call the isolated method
                    Task { @MainActor in
                        self.viewModel.onRegionChange(
                            newCenter: CoordinateWrapper(
                                self.centerCoordinate
                            )
                        )
                    }
                }
            }
    }
}
