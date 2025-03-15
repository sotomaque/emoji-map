//
//  PlaceSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI
import os.log
import UIKit

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
            VStack(alignment: .leading, spacing: 20) {
                // Place header
                HStack(spacing: 16) {
                    Text(place.emoji)
                        .font(.system(size: 60))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.6))
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if let displayName = viewModel.place.displayName {
                            Text(displayName)
                                .font(.title3)
                                .fontWeight(.bold)
                        } else {
                            // Shimmer effect for loading name
                            ShimmerView()
                                .frame(width: 180, height: 22)
                                .cornerRadius(4)
                        }
                        
                        if let primaryType = viewModel.place.primaryTypeDisplayName {
                            Text(primaryType)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Shimmer effect for loading type
                            ShimmerView()
                                .frame(width: 100, height: 16)
                                .cornerRadius(4)
                        }
                        
                        // Rating stars
                        if let rating = viewModel.place.rating {
                            HStack(spacing: 4) {
                                // Show actual stars
                                HStack(spacing: 1) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                if let userRatingCount = viewModel.place.userRatingCount {
                                    Text("(\(userRatingCount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let priceLevel = viewModel.place.priceLevel {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 2)
                                    
                                    Text(String(repeating: "$", count: priceLevel))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.top, 2)
                        } else if viewModel.isLoadingDetails {
                            // Shimmer for rating
                            ShimmerView()
                                .frame(width: 120, height: 14)
                                .cornerRadius(4)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Heart button
                    HeartButton(placeId: place.id)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                // User Rating section
                UserRatingView(placeId: place.id, isLoading: viewModel.isLoadingDetails)
                    .padding(.vertical, 12)
                
                // Location section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.red)
                        Text("Location")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Open in Maps app
                        let url = URL(string: "maps://?q=\(place.location.latitude),\(place.location.longitude)")!
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.white)
                            Text("Open in Maps")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                // Features section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "star.square.fill")
                            .foregroundColor(.orange)
                        Text("Features")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    // Grid of feature badges
                    if !viewModel.isLoadingDetails {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                    } else {
                        // Shimmer for features
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<6, id: \.self) { _ in
                                HStack(spacing: 6) {
                                    ShimmerView()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                    
                                    ShimmerView()
                                        .frame(height: 16)
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                
                // Reviews section
                if let reviews = viewModel.place.reviews, !reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                            Text("Reviews")
                                .font(.headline)
                        }
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
                } else if viewModel.isLoadingDetails {
                    // Reviews section with shimmer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                            Text("Reviews")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        // Show 2 shimmer placeholders for reviews
                        ForEach(0..<2, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ShimmerView()
                                        .frame(width: 80, height: 16)
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    ShimmerView()
                                        .frame(width: 60, height: 16)
                                        .cornerRadius(4)
                                }
                                
                                ShimmerView()
                                    .frame(height: 16)
                                    .cornerRadius(4)
                                
                                ShimmerView()
                                    .frame(height: 16)
                                    .cornerRadius(4)
                                    .padding(.trailing, 40)
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
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.purple)
                            Text("Photos")
                                .font(.headline)
                        }
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
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
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
                } else if viewModel.isLoadingPhotos {
                    // Photos section with shimmer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.purple)
                            Text("Photos")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Show 3 shimmer placeholders
                                ForEach(0..<3, id: \.self) { _ in
                                    ShimmerView()
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Loading indicators and error messages
                VStack(alignment: .leading, spacing: 8) {
                    // Error messages
                    if let detailsError = viewModel.detailsError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Details error: \(detailsError)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if let photosError = viewModel.photosError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Photos error: \(photosError)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
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
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(.white)
                .padding(6)
                .background(
                    Circle()
                        .fill(color)
                )
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// Heart button for favorites
struct HeartButton: View {
    // State to track favorite status
    @State private var isFavorite: Bool
    
    // Access to user preferences
    @ObservedObject private var userPreferences = ServiceContainer.shared.userPreferences
    
    // Place ID
    let placeId: String
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "HeartButton")
    
    init(placeId: String) {
        self.placeId = placeId
        // Initialize favorite state from UserPreferences
        self._isFavorite = State(initialValue: ServiceContainer.shared.userPreferences.isFavorite(placeId: placeId))
    }
    
    var body: some View {
        Button(action: {
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            
            // Toggle favorite status in UserPreferences
            isFavorite = userPreferences.toggleFavorite(placeId: placeId)
            
            // Trigger haptic feedback
            generator.impactOccurred()
            
            logger.notice("Heart button clicked for place ID: \(placeId), favorite: \(isFavorite)")
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title)
                .foregroundColor(isFavorite ? .red : .gray)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.6))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// User rating stars component
struct UserRatingView: View {
    let placeId: String
    let isLoading: Bool
    @State private var userRating: Int = 0
    
    // Access to user preferences
    @ObservedObject private var userPreferences = ServiceContainer.shared.userPreferences
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "UserRatingView")
    
    init(placeId: String, isLoading: Bool) {
        self.placeId = placeId
        self.isLoading = isLoading
        // Initialize rating from UserPreferences
        self._userRating = State(initialValue: ServiceContainer.shared.userPreferences.getRating(placeId: placeId))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.square.fill")
                    .foregroundColor(.yellow)
                Text("Rate this place")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            if isLoading {
                // Shimmer effect for loading state
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { _ in
                        ShimmerView()
                            .frame(width: 30, height: 30)
                            .mask(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 30))
                            )
                    }
                }
                .padding(.horizontal)
            } else {
                // Interactive rating stars
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= userRating ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                // Provide haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare()
                                
                                // Check if the user is clicking the same rating
                                if userRating == star {
                                    // Reset the rating to 0 (null)
                                    userRating = 0
                                    userPreferences.setRating(placeId: placeId, rating: 0)
                                    logger.notice("Rating reset to 0 for place ID: \(placeId)")
                                } else {
                                    // Update to the new rating
                                    userRating = star
                                    userPreferences.setRating(placeId: placeId, rating: star)
                                    logger.notice("Rating updated to \(star) for place ID: \(placeId)")
                                }
                                
                                // Trigger haptic feedback
                                generator.impactOccurred()
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// Shimmer effect view for loading states
struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.gray.opacity(0.2), location: phase - 0.2),
                        .init(color: Color.gray.opacity(0.3), location: phase),
                        .init(color: Color.gray.opacity(0.2), location: phase + 0.2)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#Preview {
    PlaceSheet(place: Place(id: "preview-id", emoji: "🏠", location: Place.Location(latitude: 37.7749, longitude: -122.4194)))
} 
