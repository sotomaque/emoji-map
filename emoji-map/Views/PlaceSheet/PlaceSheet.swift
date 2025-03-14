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
                // Place header
                HStack {
                    Text(place.emoji)
                        .font(.system(size: 60))
                    
                    VStack(alignment: .leading) {
                        if let displayName = viewModel.place.displayName {
                            Text(displayName)
                                .font(.headline)
                        } else {
                            Text("ID: \(place.id)")
                                .font(.headline)
                        }
                        
                        if let primaryType = viewModel.place.primaryTypeDisplayName {
                            Text(primaryType)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Location: \(String(format: "%.6f", place.location.latitude)), \(String(format: "%.6f", place.location.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Rating and details section
                if let rating = viewModel.place.rating {
                    HStack(spacing: 12) {
                        // Rating stars
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text(String(format: "%.1f", rating))
                            .fontWeight(.bold)
                        
                        if let userRatingCount = viewModel.place.userRatingCount {
                            Text("(\(userRatingCount) reviews)")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Price level
                        if let priceLevel = viewModel.place.priceLevel, !priceLevel.isEmpty {
                            Text(priceLevel)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Features section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Grid of feature badges
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        if viewModel.place.openNow == true {
                            FeatureBadge(text: "Open Now", systemImage: "clock.fill", color: .green)
                        }
                        
                        if viewModel.place.takeout == true {
                            FeatureBadge(text: "Takeout", systemImage: "bag.fill", color: .blue)
                        }
                        
                        if viewModel.place.delivery == true {
                            FeatureBadge(text: "Delivery", systemImage: "bicycle", color: .orange)
                        }
                        
                        if viewModel.place.dineIn == true {
                            FeatureBadge(text: "Dine-in", systemImage: "fork.knife", color: .purple)
                        }
                        
                        if viewModel.place.outdoorSeating == true {
                            FeatureBadge(text: "Outdoor Seating", systemImage: "sun.max.fill", color: .yellow)
                        }
                        
                        if viewModel.place.servesCoffee == true {
                            FeatureBadge(text: "Coffee", systemImage: "cup.and.saucer.fill", color: .brown)
                        }
                        
                        if viewModel.place.servesDessert == true {
                            FeatureBadge(text: "Dessert", systemImage: "birthday.cake.fill", color: .pink)
                        }
                        
                        if viewModel.place.goodForGroups == true {
                            FeatureBadge(text: "Good for Groups", systemImage: "person.3.fill", color: .indigo)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                // Reviews section
                if let reviews = viewModel.place.reviews, !reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reviews")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(reviews.prefix(3)) { review in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    // Rating stars
                                    HStack(spacing: 2) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(review.relativePublishTimeDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(review.text.text)
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
                
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

// Helper view for feature badges
struct FeatureBadge: View {
    let text: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

#Preview {
    PlaceSheet(place: Place(id: "preview-id", emoji: "🏠", location: Place.Location(latitude: 37.7749, longitude: -122.4194)))
} 