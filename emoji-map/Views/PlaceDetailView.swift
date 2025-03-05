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
        .toolbar {
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
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading details...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
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
                        skeletonPhotoView
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
                                skeletonPhotoView
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
    
    // Skeleton loading view for photos
    private var skeletonPhotoView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity, maxHeight: 200)
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
            .shimmering() // Add shimmer effect
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
                    
                    StarRatingDisplayView(rating: viewModel.userRating, size: 14)
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
                currentRating: viewModel.userRating,
                size: 30,
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
                backgroundColor: viewModel.isFavorite ? .red : .blue
            ) {
                toggleFavorite()
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.7 : 1.0)
            
            ActionButton(
                title: "View on Map",
                icon: "map.fill",
                foregroundColor: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                hasBorder: true
            ) {
                // Dismiss the sheet and focus on this place on the map
                mapViewModel.selectedPlace = nil
            }
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
                        skeletonReviewCard
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
                Text("No reviews available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.reviews, id: \.0) { (
                    author,
                    comment,
                    rating
                ) in
                    ReviewCard(author: author, comment: comment, rating: rating)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(.horizontal)
    }
    
    // Skeleton loading view for review cards
    private var skeletonReviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 16)
                    .cornerRadius(4)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 14)
                .cornerRadius(4)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 14)
                .cornerRadius(4)
                .padding(.trailing, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .shimmering() // Add shimmer effect
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
                StarRatingDisplayView(rating: rating)
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

//struct StarRatingDisplayView: View {
//    let rating: Int
//    
//    var body: some View {
//        HStack(spacing: 4) {
//            ForEach(1...5, id: \.self) { index in
//                Image(systemName: index <= rating ? "star.fill" : "star")
//                    .foregroundColor(index <= rating ? .yellow : .gray)
//                    .font(.system(size: 14))
//            }
//        }
//    }
//}

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

// MARK: - Shimmer Effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: phase - 0.2),
                            .init(color: .white.opacity(0.5), location: phase),
                            .init(color: .clear, location: phase + 0.2)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(content)
                    .frame(width: geo.size.width * 3)
                    .offset(x: -geo.size.width + (geo.size.width * 3) * phase)
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    self.phase = 1
                }
            }
    }
}
