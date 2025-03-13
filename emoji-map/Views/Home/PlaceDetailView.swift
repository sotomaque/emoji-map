//
//  PlaceDetailView.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit
import os.log

// Add a custom view modifier to prevent dismissal
struct PreventDismissModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .background(PreventDismissView(isActive: isActive))
    }
}

// Helper view to prevent dismissal
struct PreventDismissView: UIViewControllerRepresentable {
    let isActive: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        PreventDismissController(isActive: isActive)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? PreventDismissController)?.isActive = isActive
    }
    
    class PreventDismissController: UIViewController {
        var isActive: Bool {
            didSet {
                // When isActive changes, update the presentation controller delegate
                parent?.presentationController?.delegate = self
                
                // Log the change for debugging
                print("PreventDismissController: isActive changed to \(isActive)")
            }
        }
        
        init(isActive: Bool) {
            self.isActive = isActive
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            // Set the presentation controller delegate
            parent?.presentationController?.delegate = self
            
            // Log for debugging
            print("PreventDismissController: viewDidLoad, setting delegate")
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Ensure the delegate is set when the view appears
            parent?.presentationController?.delegate = self
            
            // Log for debugging
            print("PreventDismissController: viewWillAppear, setting delegate")
        }
    }
}

// Extension to make the controller a presentation controller delegate
extension PreventDismissView.PreventDismissController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // Only allow dismissal if not active
        print("PreventDismissController: presentationControllerShouldDismiss called, returning \(!isActive)")
        return !isActive
    }
    
    // Add this method to handle attempted dismissals
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        print("PreventDismissController: presentationControllerDidAttemptToDismiss called")
        // This is called when the user tries to dismiss but we prevented it
        // We could add additional logic here if needed
    }
    
    // Add this method to handle dismissal completion
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("PreventDismissController: presentationControllerDidDismiss called")
        // This is called when the sheet is actually dismissed
        // We could add additional logic here if needed
    }
}

// TODO: move to Extensions folder
// Extension to add the modifier to any view
extension View {
    func preventDismissal(when condition: Bool) -> some View {
        self.modifier(PreventDismissModifier(isActive: condition))
    }
}

//
struct PlaceDetailView: View {
    let place: Place
    @StateObject private var viewModel: PlaceDetailViewModel
    @State private var isAppearing = false
    @EnvironmentObject private var mapViewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showMapAppActionSheet = false
    // Add a logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetailView")
    // Add a flag to track if we're in the process of dismissing
    @State private var isDismissing = false
    
    // Initialize with the place and create the view model with the shared service
    init(place: Place) {
        self.place = place
        
        print("PLACE: \(place)")
        
        // Use the default initializer which creates a dummy MapViewModel
        // The real MapViewModel will be set in onAppear from the environment
        _viewModel = StateObject(wrappedValue: PlaceDetailViewModel())
    }
    
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
                
                // Add a retry button if there's an error
                if viewModel.error != nil && !viewModel.isLoading {
                    Button(action: {
                        viewModel.retryFetchDetails(for: place)
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Loading Details")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                
                // Add a loading indicator at the bottom if still loading
                if viewModel.isLoading && isAppearing {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading details...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .padding(.vertical)
            .opacity(isAppearing ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: isAppearing)
        }
        .background(Color(.systemGroupedBackground))
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if viewModel.isLoading {
                    // Shimmering placeholder for title
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 20)
                        .shimmering()
                } else {
                    Text(viewModel.placeName ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    logger.debug("🔍 DEBUG: Close button tapped, dismissing sheet")
                    customDismiss()
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
            // Full-screen loading overlay - only show before content appears
            ZStack {
                if viewModel.isLoading && !isAppearing {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        LoadingIndicator(message: "Loading details...")
                        
                        // Add a cancel button after a few seconds
                        if viewModel.isLoading {
                            Button("Cancel") {
                                logger.debug("🔍 DEBUG: Cancel loading button tapped")
                                customDismiss()
                            }
                            .padding(.top, 20)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        )
        .onAppear {
            logger.debug("🔍 DEBUG: PlaceDetailView.onAppear called for place: \(place.name)")
            
            // Update the view model with the MapViewModel from the environment
            viewModel.updateMapViewModel(mapViewModel)
            
            // Fetch details for the place
            logger.debug("🔍 DEBUG: Calling fetchDetails for place: \(place.name)")
            viewModel.fetchDetails(for: place)
            
            // Calculate distance from user once (static)
            viewModel.calculateDistanceFromUser(place: place, userLocation: mapViewModel.locationManager.location)
            
            // Slight delay before showing content for smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                logger.debug("🔍 DEBUG: Setting isAppearing to true")
                isAppearing = true
            }
            
            logger.debug("🔍 DEBUG: PlaceDetailView.onAppear completed")
        }
        .onDisappear {
            logger.debug("🔍 DEBUG: PlaceDetailView.onDisappear called, isDismissing: \(isDismissing)")
            
            // Only process dismissal if it's an intentional dismissal
            if isDismissing {
                // Notify the view model that the view is disappearing
                viewModel.onViewDisappear()
            }
            
            logger.debug("🔍 DEBUG: PlaceDetailView.onDisappear completed")
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
        // Add presentation detents to control the sheet size
        .presentationDetents([.large])
        // Always prevent interactive dismissal to avoid accidental dismissals
        .interactiveDismissDisabled(true)
        // Add a custom presentation background to prevent touches from passing through
        .presentationBackground {
            Color(.systemGroupedBackground)
                .opacity(0.98)
        }
        // Always prevent dismissal to ensure only our customDismiss method can dismiss the sheet
        .preventDismissal(when: true) // Always prevent dismissal
    }
    
    private func toggleFavorite() {
        logger.debug("🔍 DEBUG: toggleFavorite called for place: \(viewModel.placeName ?? "")")
        
        // Toggle favorite directly in the view model
        viewModel.toggleFavorite()
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        logger.debug("🔍 DEBUG: Favorite status updated")
    }
    
    // Add a custom dismiss action to control when the sheet is dismissed
    private func customDismiss() {
        logger.debug("🔍 DEBUG: customDismiss called, setting isDismissing to true")
        isDismissing = true
        dismiss()
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
            if viewModel.isLoading {
                // Skeleton loading for place name
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 32)
                    .shimmering()
                
                // Skeleton loading for description
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 16)
                    .shimmering()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 240, height: 16)
                    .shimmering()
            } else {
                Text(viewModel.placeName ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(place.description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
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
            
            // Info pills
            HStack(spacing: 12) {
                // Distance pill
                if viewModel.distanceFromUser != nil {
                    InfoPill(
                        icon: "location.fill",
                        text: viewModel.formattedDistance,
                        color: .blue
                    )
                }
                
                // Price level pill
                InfoPill(
                    icon: "dollarsign.circle.fill",
                    text: place.formattedPriceLevel,
                    color: .green
                )
                
                // Rating pill
                if place.hasRating {
                    InfoPill(
                        icon: "star.fill",
                        text: place.formattedRating,
                        color: .yellow
                    )
                }
                
                // Open status pill
                InfoPill(
                    icon: place.openNow == true ? "checkmark.circle.fill" : "xmark.circle.fill",
                    text: place.openStatus,
                    color: place.openNow == true ? .green : .red
                )
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }
    
    // New section for user to rate the place
    private var userRatingSection: some View {
        VStack(spacing: 8) {
            Text("Rate this place")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            // Add a debug text to show the current rating value
            #if DEBUG
            Text("Current rating: \(viewModel.userRating)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            #endif
            
            StarRatingView(
                rating: viewModel.userRating,
                size: 30,
                isInteractive: true,
                onRatingChanged: { rating in
                    logger.debug("🔍 DEBUG: onRatingChanged called with rating: \(rating)")
                    
                    // Update rating directly in the view model
                    viewModel.ratePlace(rating: rating)
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    
                    // Show notification
                    mapViewModel.showNotificationMessage("Rating saved")
                    
                    logger.debug("🔍 DEBUG: Rating updated to: \(rating)")
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
        VStack(spacing: 16) {
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
                        logger.debug("🔍 DEBUG: View on Map button tapped")
                        // Use the default map app
                        let defaultMapAppName = mapViewModel.preferences.defaultMapApp
                        let installedApps = MapAppUtility.shared.getInstalledMapApps()
                        
                        // Find the default map app
                        if let defaultApp = installedApps.first(where: { $0.rawValue == defaultMapAppName }) {
                            // Use the default map app
                            MapAppUtility.shared.openInMapApp(
                                mapApp: defaultApp,
                                coordinate: place.coordinate,
                                name: viewModel.placeName ?? ""
                            )
                        } else if let firstApp = installedApps.first {
                            // Use the first available map app if default is not found
                            MapAppUtility.shared.openInMapApp(
                                mapApp: firstApp,
                                coordinate: place.coordinate,
                                name: viewModel.placeName ?? ""
                            )
                        }
                        
                        // Dismiss the sheet after launching the map app
                        logger.debug("🔍 DEBUG: Dismissing sheet after launching map app")
                        customDismiss()
                    }
                )
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                .contextMenu {
                    // Context menu to choose a different map app
                    Text("Open with...")
                    
                    ForEach(MapAppUtility.shared.getInstalledMapApps()) { app in
                        Button {
                            MapAppUtility.shared.openInMapApp(
                                mapApp: app,
                                coordinate: place.coordinate,
                                name: viewModel.placeName ?? ""
                            )
                            customDismiss()
                        } label: {
                            Label(app.rawValue, systemImage: "map.fill")
                        }
                    }
                }
            }
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


// TODO: PREVIEW

// MARK: - Shimmering Effect
extension View {
    func shimmering() -> some View {
        self.modifier(ShimmeringEffect())
    }
}

struct ShimmeringEffect: ViewModifier {
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
                    .blendMode(.screen)
                    .mask(content)
                    .offset(x: -geo.size.width + (geo.size.width * 3 * phase))
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    self.phase = 1
                }
            }
    }
}
