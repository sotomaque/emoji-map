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
                    Button(action: {
                        viewModel.selectedPlace = place
                    }) {
                        VStack(spacing: 0) {
                            // Show rating or star icon above emoji for favorites
                            if viewModel.isFavorite(placeId: place.placeId) {
                                if let rating = viewModel.getRating(for: place.placeId), rating > 0 {
                                    // Show numeric rating with star
                                    HStack(spacing: 1) {
                                        Text("\(rating)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.yellow)
                                        
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(8)
                                    .offset(y: 2)
                                } else {
                                    // Show outline star for favorites without rating
                                    Image(systemName: "star")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                        .offset(y: 2)
                                }
                            }
                            
                            Text(viewModel.categoryEmoji(for: place.category))
                                .font(.system(size: 30))
                                .frame(width: 40, height: 40)
                                .background(
                                    viewModel.isFavorite(placeId: place.placeId) ?
                                        Circle()
                                            .fill(Color.yellow.opacity(0.3))
                                            .frame(width: 44, height: 44)
                                    : nil
                                )
                        }
                    }
                    .scaleEffect(viewModel.isLoading ? 0.8 : 1.0) // Subtle scale effect during loading
                    .opacity(viewModel.isLoading ? 0.6 : 1.0) // Fade out during loading
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
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
                    configurationWarningBanner
                }
                
                Spacer()
            }
            
            if !viewModel.isLocationAvailable {
                // Progress view when location isn't available
                VStack {
                    ProgressView("Finding your location...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                }
            } else {
                // Normal content when location is available
                VStack {
                    VStack(spacing: 4) {
                        // Category count indicator - moved to top right
                        HStack {
                            Spacer()
                            
                            if !viewModel.selectedCategories.isEmpty {
                                Text("\(viewModel.selectedCategories.count) \(viewModel.selectedCategories.count == 1 ? "category" : "categories")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemBackground).opacity(0.8))
                                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    )
                            }
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                        
                        // Emoji category selector with integrated favorites button
                        EmojiSelector()
                            .disabled(viewModel.isLoading) // Disable interaction during loading
                            .opacity(viewModel.isLoading ? 0.7 : 1.0) // Subtle fade during loading
                    }
                    
                    Spacer() // Push selector to the top
                    
                    // Enhanced loading indicator
                    if viewModel.isLoading {
                        loadingIndicator
                    }
                }
                
                // Recenter button
                Button(action: {
                    withAnimation {
                        viewModel.recenterMap()
                    }
                }) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .position(x: UIScreen.main.bounds.width - 40, y: UIScreen.main.bounds.height - 120) // Bottom-right corner
                .disabled(viewModel.isLoading) // Disable during loading
                .opacity(viewModel.isLoading ? 0.6 : 1.0) // Fade during loading
                .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
            }
            
            // Notification banner
            VStack {
                Spacer()
                
                if viewModel.showNotification {
                    Text(viewModel.notificationMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            // Trigger haptic feedback when notification appears
                            triggerHapticFeedback()
                        }
                }
            }
            .animation(.spring(response: 0.4), value: viewModel.showNotification)
            .zIndex(100) // Ensure it's above other elements
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: CoordinateWrapper(viewModel.region.center)) { _, newValue in
            viewModel.onRegionChange(newCenter: newValue)
        }
        .sheet(item: $viewModel.selectedPlace) { place in
            PlaceDetailView(place: place)
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
    }
    
    // Enhanced loading indicator
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Loading places...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(response: 0.3), value: viewModel.isLoading)
    }
    
    // Configuration warning banner
    private var configurationWarningBanner: some View {
        VStack {
            Text(viewModel.configWarningMessage)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.orange)
                .cornerRadius(0)
                .frame(maxWidth: .infinity)
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut, value: viewModel.showConfigWarning)
    }
    
    // Haptic feedback function
    private func triggerHapticFeedback() {
        // Prevent multiple haptics in quick succession
        let now = Date()
        if now.timeIntervalSince(lastHapticTime) > 0.5 {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            lastHapticTime = now
        }
    }
}
