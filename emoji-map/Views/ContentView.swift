//
//  ContentView.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @State private var lastHapticTime: Date = Date.distantPast
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var lastRegionChangeTime: Date = Date.distantPast
    @State private var debounceTimer: Timer?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showSettings = false
    @State private var showTooltip = false
    @State private var tooltipTimer: Timer?
    
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
                                emoji: viewModel.categoryEmoji(for: place.category),
                                isFavorite: viewModel.isFavorite(placeId: place.placeId),
                                rating: viewModel.getRating(for: place.placeId),
                                isLoading: viewModel.isLoading,
                                onTap: {
                                    viewModel.selectedPlace = place
                                }
                            )
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
            .overlay(
                // Map overlay for loading - more subtle approach
                viewModel.isLoading ?
                    ZStack {
                        // Semi-transparent overlay that doesn't completely hide the map
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .edgesIgnoringSafeArea(.all)
                    }
                    : nil
            )
            
            // Overlay layers
            VStack {
                // Configuration warning banner
                if viewModel.showConfigWarning {
                    WarningBanner(
                        message: viewModel.configWarningMessage,
                        isVisible: viewModel.showConfigWarning
                    )
                }
                
                // Loading indicator at the top - minimal style to prevent layout shifts
                if viewModel.isLoading {
                    UnifiedLoadingIndicator(
                        message: "Loading places...",
                        color: .blue,
                        style: .minimal,
                        backgroundColor: Color(.systemBackground).opacity(0.8)
                    )
                    .transition(.opacity)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            
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
                VStack {
                    VStack(spacing: 4) {
                        // Remove the FiltersButton and category count indicator from here
                        
                        // Emoji category selector with integrated favorites button
                        EmojiSelector()
                            .disabled(viewModel.isLoading) // Disable interaction during loading
                            .opacity(viewModel.isLoading ? 0.7 : 1.0) // Subtle fade during loading
                    }
                    
                    Spacer() // Push selector to the top
                    
                    if viewModel.showSearchHereButton {
                        SearchHereButton(
                            action: {
                                viewModel.searchHere()
                            },
                            isLoading: viewModel.isLoading
                        )
                        .padding(.bottom, 40)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSearchHereButton)
                    }
                }
                
                // Recenter button
                RecenterButton(
                    isLoading: viewModel.isLoading,
                    action: {
                        withAnimation {
                            viewModel.recenterMap()
                        }
                    }
                )
                .position(x: UIScreen.main.bounds.width - 40, y: UIScreen.main.bounds.height - 120) // Bottom-right corner
                
                // FiltersButton - moved to bottom left
                Button(action: {
                    viewModel.showFilters = true
                }) {
                    FiltersButton(
                        activeFilterCount: viewModel.activeFilterCount,
                        isLoading: viewModel.isLoading
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)
                .position(x: 40, y: UIScreen.main.bounds.height - 120) // Bottom-left corner
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
                // Add a tooltip to hint at the hidden feature
                .overlay(
                    ZStack {
                        if showTooltip {
                            VStack {
                                Text("Hold for Settings")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .offset(y: -50)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .animation(.easeInOut, value: showTooltip)
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
            
            // Notification banner
            NotificationBanner(
                message: viewModel.notificationMessage,
                isVisible: viewModel.showNotification,
                onAppear: {
                    // Trigger haptic feedback when notification appears
                    triggerHapticFeedback()
                }
            )
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
            
            // Show tooltip on first launch
            if !viewModel.preferences.hasShownSettingsTooltip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showTooltip = true
                    
                    // Hide tooltip after 5 seconds
                    tooltipTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        withAnimation {
                            showTooltip = false
                        }
                        viewModel.preferences.markSettingsTooltipAsShown()
                    }
                }
            }
        }
        .onDisappear {
            // Clean up the timer when the view disappears
            debounceTimer?.invalidate()
            debounceTimer = nil
            
            // Remove the region change callback
            viewModel.onRegionDidChange = nil
            
            tooltipTimer?.invalidate()
        }
        .sheet(item: $viewModel.selectedPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(isPresented: $viewModel.showError, content: {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error?.localizedDescription ?? "An unknown error occurred"),
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
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            // Only process region changes that are at least 0.3 seconds apart
            let now = Date()
            if now.timeIntervalSince(self.lastRegionChangeTime) >= 0.3 {
                self.lastRegionChangeTime = now
                
                // Ensure we're on the main thread when calling viewModel methods
                if Thread.isMainThread {
                    self.viewModel.onRegionChange(newCenter: CoordinateWrapper(self.centerCoordinate))
                } else {
                    DispatchQueue.main.async {
                        self.viewModel.onRegionChange(newCenter: CoordinateWrapper(self.centerCoordinate))
                    }
                }
            }
        }
    }
}
