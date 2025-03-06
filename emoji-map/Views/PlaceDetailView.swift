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
    @State private var isAppearing = false
    @EnvironmentObject private var mapViewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Image Gallery
                gallerySection
                
                // MARK: Place Info
                placeInfoSection
                
                // MARK: User Rating Section
                userRatingSection
                
                // MARK: Action Buttons
                actionButtonsSection
                
                // MARK: Reviews
                reviewsSection
                
                Spacer()
            }
            .padding(.vertical)
            .opacity(isAppearing ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: isAppearing)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Close")
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    toggleFavorite()
                }) {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .foregroundColor(viewModel.isFavorite ? .yellow : .gray)
                }
            }
        }
        .overlay(
            // Full-screen loading overlay
            ZStack {
                if viewModel.isLoading && !isAppearing {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    
                    LoadingIndicator(message: "Loading details...")
                }
            }
        )
        .onAppear {
            viewModel.fetchDetails(for: place)
            
            // Slight delay before showing content for smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAppearing = true
            }
        }
        .alert(isPresented: $viewModel.showError, content: {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.error?.localizedDescription ?? "An unknown error occurred"),
                primaryButton: .default(Text("Retry")) {
                    viewModel.retryFetchDetails(for: place)
                },
                secondaryButton: .cancel()
            )
        })
    }
    
    private func toggleFavorite() {
        viewModel.setFavorite(place, isFavorite: !viewModel.isFavorite)
        // Also update in the map view model to keep state in sync
        mapViewModel.toggleFavorite(for: place)
    }
    
    // MARK: - Subviews
    private var gallerySection: some View {
        Group {
            if viewModel.isLoading && isAppearing {
                // Skeleton loading for photos
                TabView {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonPhotoView()
                    }
                }
                .tabViewStyle(PageTabViewStyle())
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
                        viewModel.retryFetchDetails(for: place)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
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
                        AsyncImage(url: URL(string: photoUrl)) { phase in
                            switch phase {
                            case .empty:
                                SkeletonPhotoView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .transition(.opacity)
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .background(Color.gray.opacity(0.1))
                            @unknown default:
                                EmptyView()
                            }
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
            
            // Display user rating if available
            if viewModel.userRating > 0 {
                HStack {
                    Text("Your rating:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    StarRatingView(rating: viewModel.userRating, size: 14)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }
    
    // New section for user to rate the place
    private var userRatingSection: some View {
        VStack(spacing: 8) {
            Text("Rate this place")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            StarRatingView(
                rating: viewModel.userRating,
                size: 30,
                isInteractive: true,
                onRatingChanged: { rating in
                    viewModel.ratePlace(rating: rating)
                    // Also update in the map view model to keep state in sync
                    mapViewModel.ratePlace(placeId: place.placeId, rating: rating)
                }
            )
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: viewModel.isFavorite ? "Remove Favorite" : "Add to Favorites",
                icon: viewModel.isFavorite ? "star.slash.fill" : "star.fill",
                foregroundColor: .white,
                backgroundColor: viewModel.isFavorite ? .red : .blue,
                action: {
                    toggleFavorite()
                }
            )
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.7 : 1.0)
            
            ActionButton(
                title: "View on Map",
                icon: "map.fill",
                foregroundColor: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                hasBorder: true,
                action: {
                    // Dismiss the sheet and focus on this place on the map
                    mapViewModel.selectedPlace = nil
                }
            )
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.7 : 1.0)
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isFavorite)
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reviews")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            if viewModel.isLoading && isAppearing {
                // Skeleton loading for reviews
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonReviewCard()
                    }
                }
            } else if viewModel.error != nil {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                    
                    Text("Failed to load reviews")
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        viewModel.retryFetchDetails(for: place)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if viewModel.reviews.isEmpty {
                Text("No reviews yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Display actual reviews
                ForEach(viewModel.reviewObjects) { review in
                    reviewCard(for: review)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func reviewCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.authorName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(review.relativeTimeDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if review.rating > 0 {
                StarRatingView(rating: review.rating)
                    .padding(.vertical, 2)
            }
            
            if !review.text.isEmpty {
                Text(review.text)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                description: "A cozy place with great food!",
                priceLevel: 2,
                openNow: true,
                rating: 4.5
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
            .frame(height: 600)
            .previewLayout(.sizeThatFits)
    }
}
