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
    
    var body: some View {
        ZStack {
            // Map as base layer
            Map(
                coordinateRegion: $viewModel.region,
                annotationItems: viewModel.places
            ) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    Button(action: {
                        viewModel.selectedPlace = place
                    }) {
                        Text(viewModel.categoryEmoji(for: place.category))
                            .font(.system(size: 30))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // Overlay layers
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
                    EmojiSelector()
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    Spacer() // Push selector to the top
                    
                    // Loading indicator
                    if viewModel.isLoading {
                        ProgressView("Loading places...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
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
            }
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
}
