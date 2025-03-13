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
    
    // ViewModel
    @StateObject private var viewModel: HomeViewModel
    
    // MARK: - Initialization
    
    init() {
        // Use the HomeViewModel from the ServiceContainer
        self._viewModel = StateObject(wrappedValue: ServiceContainer.shared.homeViewModel)
    }
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                
                // Display place annotations
                ForEach(viewModel.places) { place in
                    place.mapAnnotation(onTap: { selectedPlace in
                        viewModel.selectPlace(selectedPlace)
                    })
                }
            }
            .onMapCameraChange { context in
                viewModel.handleMapRegionChange(context.region)
            }
            
            // Bottom buttons container
            VStack {
                Spacer()
                HStack {
                    // Filter button
                    Button(action: {
                        viewModel.toggleFilterSheet()
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Refresh button
                    Button(action: {
                        viewModel.refreshPlaces()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
            }
            
            // Loading indicator
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        Spacer()
                    }
                    Spacer().frame(height: 100)
                }
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
            }
        }
        .sheet(isPresented: $viewModel.isFilterSheetPresented) {
            PlaceSheet()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.isPlaceDetailSheetPresented) {
            if let selectedPlace = viewModel.selectedPlace {
                PlaceSheet(place: selectedPlace)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            logger.notice("Home view appeared")
        }
    }
}

// MARK: - Preview
#Preview {
    Home()
}
