//
//  PlaceDetailView.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    @StateObject private var viewModel = PlaceDetailViewModel()
    
    // Sample data for the gallery (replace with real data in the future)
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Image Gallery
                gallerySection
                
                // MARK: Place Info
                placeInfoSection
                
                // MARK: Action Buttons
                actionButtonsSection
                
                // MARK: Reviews
                reviewsSection
                
                Spacer()
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchDetails(for: place.placeId)
        }
        .alert(isPresented: $viewModel.showError, content: {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error?.localizedDescription ?? "An unknown error occurred"),
                primaryButton: .default(Text("Retry")) {
                    viewModel.retryFetchDetails(for: place.placeId)
                },
                secondaryButton: .cancel()
            )
        })
    }
    
    // MARK: - Subviews
    private var gallerySection: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if viewModel.error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Failed to load photos")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    Button("Retry") {
                        viewModel.retryFetchDetails(for: place.placeId)
                    }
                    .padding(.top, 8)
                }
                .frame(height: 200)
            } else if viewModel.photos.isEmpty {
                Text("No photos available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                TabView {
                    ForEach(viewModel.photos, id: \.self) { photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: 200)
                                .background(Color.gray.opacity(0.2))
                        }
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16
                            )
                        )
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16
                            )
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 200)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var placeInfoSection: some View {
        VStack(spacing: 8) {
            Text(place.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(place.description)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "Add to Favorites",
                icon: "heart.fill",
                foregroundColor: .white,
                backgroundColor: .blue
            ) {
                // Future favorites implementation
            }
            
            ActionButton(
                title: "View Reviews",
                icon: "star.fill",
                foregroundColor: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                hasBorder: true
            ) {
                // Future reviews implementation
            }
        }
        .padding(.horizontal)
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reviews")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.error != nil {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    
                    Text("Failed to load reviews")
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        viewModel.retryFetchDetails(for: place.placeId)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if viewModel.reviews.isEmpty {
                Text("No reviews available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.reviews, id: \.0) { (
                    author,
                    comment,
                    rating
                ) in
                    ReviewCard(author: author, comment: comment, rating: rating)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views
struct ActionButton: View {
    let title: String
    let icon: String
    let foregroundColor: Color
    let backgroundColor: Color
    let hasBorder: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        foregroundColor: Color,
        backgroundColor: Color,
        hasBorder: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.hasBorder = hasBorder
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay {
                if hasBorder {
                    Capsule()
                        .stroke(Color.blue, lineWidth: 1)
                }
            }
        }
    }
}

struct ReviewCard: View {
    let author: String
    let comment: String
    let rating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(author)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                StarRating(rating: rating)
            }
            Text(comment)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct StarRating: View {
    let rating: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? .yellow : .gray)
                    .font(.system(size: 14))
            }
        }
    }
}

// MARK: - Preview
struct PlaceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Define dummy data for the mock
        let dummyPlaces = [
            Place(
                placeId: "sample_place_id",
                name: "Sample Restaurant",
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749,
                    longitude: -122.4194
                ),
                category: "pizza",
                description: "A cozy place with great food!"
            )
        ]
        
        let dummyDetails = PlaceDetails(
            photos: [
                "https://via.placeholder.com/300x200.png?text=Interior",
                "https://via.placeholder.com/300x200.png?text=Food",
                "https://via.placeholder.com/300x200.png?text=Exterior"
            ],
            reviews: [
                ("Alice", "Amazing pizza, great vibes!", 5),
                ("Bob", "Good but crowded.", 4),
                ("Charlie", "Service was meh.", 3)
            ]
        )
        
        // Create a mock service with the dummy data
        let mockService = MockGooglePlacesService(
            mockPlaces: dummyPlaces,
            mockDetails: dummyDetails
        )
        
        // Configure MapViewModel with the mock
        let mapViewModel = MapViewModel(googlePlacesService: mockService)
        
        // Return the preview
        PlaceDetailView(place: dummyPlaces[0])
            .environmentObject(mapViewModel)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
