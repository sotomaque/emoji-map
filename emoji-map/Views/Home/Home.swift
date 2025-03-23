//
//  Home.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI
import MapKit
import Combine
import os.log

struct Home: View {
    // Logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HomeView")
    
    // Map state
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showRecenterButton = false
    @State private var userDistanceThreshold = 1000.0 // Distance in meters to show recenter button
    @State private var highlightedPlaceId: String? = nil
    
    // ViewModel
    @StateObject private var viewModel: HomeViewModel
    
    // Computed property to determine which places list to display
    private var placesToDisplay: [Place] {
        // When any filter is active, including category selection, use the filtered places
        if viewModel.hasNetworkDependentFilters || viewModel.showFavoritesOnly || 
           (viewModel.minimumRating > 0 && viewModel.useLocalRatings) ||
           (!viewModel.isAllCategoriesMode && !viewModel.selectedCategoryKeys.isEmpty) {
            logger.notice("Using filtered places list for display (filters or category selection active)")
            
            // Log more details when we have no places to display
            if viewModel.filteredPlaces.isEmpty {
                logger.notice("⚠️ WARNING: Filtered places list is empty!")
                
                if !viewModel.isAllCategoriesMode && !viewModel.selectedCategoryKeys.isEmpty {
                    logger.notice("🔍 Category filter is active for: \(viewModel.selectedCategoryKeys.map { CategoryMappings.getEmojiForKey($0) ?? "?" }.joined())")
                }
                
                // Log total places available
                logger.notice("🔍 Total places available: \(viewModel.places.count)")
                
                // If we're filtering by coffee, do extra logging
                if viewModel.selectedCategoryKeys.contains(4) {
                    let coffeeEmoji = CategoryMappings.getEmojiForKey(4) ?? "☕️"
                    let coffeePlaces = viewModel.places.filter { $0.emoji.contains(coffeeEmoji) }
                    logger.notice("🔍 Coffee places in main collection: \(coffeePlaces.count)")
                    
                    // Log a few sample coffee places
                    for (index, place) in coffeePlaces.prefix(3).enumerated() {
                        logger.notice("🔍 Coffee place \(index+1): \(place.displayName ?? "Unknown") - Emoji: '\(place.emoji)'")
                    }
                }
            }
            
            return viewModel.filteredPlaces
        } else {
            // If no filters are active, use the regular places list
            logger.notice("Using regular places list for display (no filters active)")
            return viewModel.places
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Use the HomeViewModel from the ServiceContainer
        self._viewModel = StateObject(wrappedValue: ServiceContainer.shared.homeViewModel)
    }
    
    var body: some View {
        ZStack {
            // Map layer
            Map(position: $position) {
                UserAnnotation()
                
                // Display place annotations - use placesToDisplay computed property
                ForEach(placesToDisplay) { place in
                    place.mapAnnotation(onTap: { selectedPlace in
                        viewModel.selectPlace(selectedPlace)
                    }, isHighlighted: place.id == highlightedPlaceId)
                }
            }
            .onMapCameraChange { context in
                viewModel.handleMapRegionChange(context.region)
                
                // Check if we should show the recenter button
                if let userLocation = viewModel.locationManager.lastLocation?.coordinate {
                    let mapCenter = context.region.center
                    let centerLocation = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
                    let userLocationObj = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                    
                    // Calculate distance between current map center and user location
                    let distance = centerLocation.distance(from: userLocationObj)
                    
                    // Show recenter button if distance exceeds threshold
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let shouldShow = distance > userDistanceThreshold
                        if shouldShow != showRecenterButton {
                            logger.notice("Recenter button visibility changed: \(shouldShow ? "showing" : "hiding") (distance: \(Int(distance))m, threshold: \(Int(userDistanceThreshold))m)")
                        }
                        showRecenterButton = shouldShow
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // UI Overlay
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Category selector at the top
                    VStack {
                        CategorySelector(viewModel: viewModel)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    
                    Spacer()
                    
                    // Bottom buttons container
                    VStack {
                        // Display place count badge if categories or filters are active
                        if !viewModel.isAllCategoriesMode || viewModel.hasActiveFilters {
                            Text("\(placesToDisplay.count) places")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 2)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: placesToDisplay.count)
                        }
                        
                        Spacer()
                        
                        HStack {
                            // Filter button
                            Button(action: {
                                viewModel.toggleFilterSheet()
                            }) {
                                Text("🔍")
                                    .font(.title2)
                                    .padding()
                                    .background(viewModel.hasActiveFilters ? Color.blue : Color(.systemBackground))
                                    .foregroundColor(viewModel.hasActiveFilters ? .white : .primary)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding(.leading, 20)
                            
                            Spacer()
                            
                            // Settings button
                            Button(action: {
                                viewModel.toggleSettingsSheet()
                            }) {
                                Text("⚙")
                                    .font(.title2)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Recenter button - appears when user moves away from current location
            if showRecenterButton {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            // Recenter map to user location
                            withAnimation(.easeInOut(duration: 0.5)) {
                                position = .userLocation(fallback: .automatic)
                                showRecenterButton = false
                                logger.notice("Map recentered to user location")
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 90) // Position above the filter/settings buttons
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            // Loading indicator - only shown when there are no places
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading places...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        Spacer()
                    }
                    Spacer().frame(height: 100)
                }
                .allowsHitTesting(false) // Allow interaction with the map underneath
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }
                .allowsHitTesting(false) // Allow interaction with the map underneath
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.errorMessage != nil)
            }
        }
        .sheet(isPresented: $viewModel.isFilterSheetPresented) {
            PlaceSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.isPlaceDetailSheetPresented) {
            if let selectedPlace = viewModel.selectedPlace {
                PlaceSheet(place: selectedPlace)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .onAppear {
                        // Center map on the selected place and highlight it
                        withAnimation(.easeInOut(duration: 0.5)) {
                            position = .region(MKCoordinateRegion(
                                center: selectedPlace.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))
                            highlightedPlaceId = selectedPlace.id
                            logger.notice("Centered map on selected place: \(selectedPlace.id)")
                        }
                    }
                    .onDisappear {
                        // Reset highlighted place when sheet closes
                        highlightedPlaceId = nil
                        logger.notice("Place detail sheet closed, reset highlighted place")
                    }
            }
        }
        .sheet(isPresented: $viewModel.isSettingsSheetPresented) {
            SettingsSheet(viewModel: viewModel)
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            logger.notice("Home view appeared")
            
            // Fetch user data in the background
            Task {
                await viewModel.fetchUserData()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    Home()
}
