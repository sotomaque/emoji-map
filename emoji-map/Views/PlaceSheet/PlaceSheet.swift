//
//  PlaceSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI
import os.log

struct PlaceSheet: View {
    var place: Place?
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceSheet")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let place = place {
                PlaceDetailView(place: place)
            } else {
                // Filter UI (original purpose of the sheet)
                Text("Filter Places")
                    .font(.largeTitle)
                    .padding()
            }
        }
        .padding()
    }
}

// Separate view for place details with its own view model
struct PlaceDetailView: View {
    let place: Place
    
    // View model for handling network requests
    @StateObject private var viewModel: PlaceSheetViewModel
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetailView")
    
    init(place: Place) {
        self.place = place
        // Initialize the view model
        self._viewModel = StateObject(wrappedValue: PlaceSheetViewModel(place: place))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Place details
                HStack {
                    Text(place.emoji)
                        .font(.system(size: 60))
                    
                    VStack(alignment: .leading) {
                        Text("ID: \(place.id)")
                            .font(.headline)
                        
                        Text("Location: \(String(format: "%.6f", place.location.latitude)), \(String(format: "%.6f", place.location.longitude))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Photos section
                if !viewModel.place.photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.place.photos, id: \.self) { photoUrl in
                                    AsyncImage(url: URL(string: photoUrl)) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 150, height: 150)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 150, height: 150)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        case .failure:
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                                .frame(width: 150, height: 150)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Loading indicators
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isLoadingDetails {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading details...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if viewModel.isLoadingPhotos {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading photos...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Error messages
                    if let detailsError = viewModel.detailsError {
                        Text("Details error: \(detailsError)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if let photosError = viewModel.photosError {
                        Text("Photos error: \(photosError)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            // Trigger network requests when the view appears
            logger.notice("PlaceDetailView appeared for place ID: \(place.id)")
            viewModel.fetchPlaceData()
        }
    }
}

#Preview {
    PlaceSheet(place: Place(id: "preview-id", emoji: "🏠", location: Place.Location(latitude: 37.7749, longitude: -122.4194)))
} 