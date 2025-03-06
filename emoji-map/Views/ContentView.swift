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
    
    var body: some View {
        ZStack {
            // Map as base layer
            Map(
                coordinateRegion: $viewModel.region,
                annotationItems: viewModel.filteredPlaces
            ) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    PlaceAnnotation(
                        emoji: viewModel.categoryEmoji(for: place.category),
                        isFavorite: viewModel.isFavorite(placeId: place.placeId),
                        rating: viewModel.isFavorite(placeId: place.placeId) ? viewModel.getRating(for: place.placeId) : nil,
                        isLoading: viewModel.isLoading,
                        onTap: {
                            viewModel.selectedPlace = place
                        }
                    )
                }
            }
            .edgesIgnoringSafeArea(.all)
            .overlay(
                // Map overlay gradient when loading
                viewModel.isLoading ?
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .edgesIgnoringSafeArea(.all)
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
                
                Spacer()
            }
            
            if !viewModel.isLocationAvailable {
                // Progress view when location isn't available
                VStack {
                    LoadingIndicator(message: "Finding your location...")
                }
            } else {
                // Normal content when location is available
                VStack {
                    VStack(spacing: 4) {
                        // Remove the FiltersButton and category count indicator from here
                        
                        // Emoji category selector with integrated favorites button
                        EmojiSelector()
                            .disabled(viewModel.isLoading) // Disable interaction during loading
                            .opacity(viewModel.isLoading ? 0.7 : 1.0) // Subtle fade during loading
                    }
                    
                    Spacer() // Push selector to the top
                    
                    // Enhanced loading indicator
                    if viewModel.isLoading {
                        LoadingIndicator(message: "Loading places...")
                    }
                    
                    if viewModel.showSearchHereButton && !viewModel.isLoading {
                        SearchHereButton(action: {
                            viewModel.searchHere()
                        })
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
        }
        .onChange(of: CoordinateWrapper(viewModel.region.center)) { _, newValue in
            viewModel.onRegionChange(newCenter: newValue)
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
                minimumRating: viewModel.minimumRating
            )
            .environmentObject(viewModel)
        }
    }
    
    // Haptic feedback function
    private func triggerHapticFeedback() {
        // Prevent multiple haptics in quick succession
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) > 1.0 {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            lastHapticTime = now
        }
    }
}
