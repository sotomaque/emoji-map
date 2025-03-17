//
//  PlaceSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI
import os.log

struct FilterCard<Content: View>: View {
    let title: String
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

struct StarRatingView: View {
    let rating: Int
    let maxRating: Int
    let size: CGFloat
    let color: Color
    let isInteractive: Bool
    let onRatingChanged: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? color : .gray.opacity(0.3))
                    .font(.system(size: size))
                    .onTapGesture {
                        if isInteractive {
                            onRatingChanged(star)
                        }
                    }
            }
        }
    }
}

struct FilterView: View {
    // State for selected price levels
    @State private var selectedPriceLevels: Set<Int> = []
    // Track initial price levels to detect changes
    @State private var initialPriceLevels: Set<Int> = []
    // State for new UI elements (not functional yet)
    @State private var showOpenNowOnly: Bool = false
    @State private var minimumRating: Int = 0
    @State private var useLocalRatings: Bool = false
    
    // Environment to dismiss the sheet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Reference to the HomeViewModel
    @ObservedObject var viewModel: HomeViewModel
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "FilterView")
    
    // Colors for the UI
    private var accentColor: Color { Color.blue }
    private var backgroundColor: Color { colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground) }
    private var cardBackgroundColor: Color { colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white }
    
    // Computed property to check if filters have changed
    private var filtersChanged: Bool {
        // Check if price levels have changed
        let priceLevelsChanged = selectedPriceLevels != initialPriceLevels
        
        // Check if minimum rating has changed from the view model's value
        let ratingChanged = minimumRating != viewModel.minimumRating
        
        // Check if rating source has changed from the view model's value
        let ratingSourceChanged = useLocalRatings != viewModel.useLocalRatings
        
        return priceLevelsChanged || ratingChanged || ratingSourceChanged
    }
    
    // Computed property to check if filters are non-default
    private var hasNonDefaultFilters: Bool {
        // Check if price levels are not all selected (default is all selected)
        let allPriceLevelsSelected = selectedPriceLevels.count == 4 && 
                                    selectedPriceLevels.contains(1) && 
                                    selectedPriceLevels.contains(2) && 
                                    selectedPriceLevels.contains(3) && 
                                    selectedPriceLevels.contains(4)
        
        let hasPriceLevelFilters = !allPriceLevelsSelected
        
        // Check if minimum rating filter is active
        let hasRatingFilter = minimumRating > 0
        
        // Check if any filter is active
        return hasPriceLevelFilters || hasRatingFilter || showOpenNowOnly
    }
    
    // Initialize with the view model and load current filter settings
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        
        // Initialize with current filter settings from the view model
        var priceLevels = viewModel.selectedPriceLevels
        
        // If no price levels are selected, default to all
        if priceLevels.isEmpty {
            priceLevels = [1, 2, 3, 4]
        }
        
        // Initialize state variables
        _selectedPriceLevels = State(initialValue: priceLevels)
        _initialPriceLevels = State(initialValue: priceLevels)
        
        // Initialize rating filter state from view model
        _minimumRating = State(initialValue: viewModel.minimumRating)
        _useLocalRatings = State(initialValue: viewModel.useLocalRatings)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Reset") {
                    resetFilters()
                }
                .foregroundColor(hasNonDefaultFilters ? .red : Color.gray.opacity(0.5))
                .disabled(!hasNonDefaultFilters)
                
                Spacer()
                
                Text("Filters")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Apply") {
                    applyFilters()
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(filtersChanged ? accentColor : Color.gray.opacity(0.5))
                .disabled(!filtersChanged)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(backgroundColor)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Price Level Card
                    FilterCard(title: "Price Level") {
                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { level in
                                Button(action: {
                                    togglePriceLevel(level)
                                }) {
                                    Text(String(repeating: "$", count: level))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedPriceLevels.contains(level) 
                                                    ? accentColor 
                                                    : Color.gray.opacity(0.15))
                                        )
                                        .foregroundColor(selectedPriceLevels.contains(level) ? .white : .primary)
                                        .fontWeight(selectedPriceLevels.contains(level) ? .semibold : .regular)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPriceLevels.contains(level))
                            }
                        }
                    }
                    
                    // Open Now Card (placeholder, not functional yet)
                    FilterCard(title: "Open Now") {
                        Toggle("Show only places open now", isOn: $showOpenNowOnly)
                            .tint(accentColor)
                            .padding(.vertical, 4)
                            .onChange(of: showOpenNowOnly) { oldValue, newValue in
                                logger.notice("Open Now toggle changed to: \(newValue) (not functional yet)")
                            }
                    }
                    
                    // Minimum Rating Card (placeholder, not functional yet)
                    FilterCard(title: "Minimum Rating") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Rating source toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rating Source")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Rating Source", selection: $useLocalRatings) {
                                    Text("Google Maps").tag(false)
                                    Text("My Ratings").tag(true)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.bottom, 8)
                                .onChange(of: useLocalRatings) { newValue in
                                    logger.notice("Rating source changed to: \(newValue ? "My Ratings" : "Google Maps")")
                                }
                            }
                            
                            Divider()
                            
                            // Rating selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Minimum: \(minimumRating) \(minimumRating == 1 ? "star" : "stars")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if minimumRating > 0 {
                                        Button("Clear") {
                                            minimumRating = 0
                                            logger.notice("Minimum rating cleared")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(accentColor)
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        minimumRating = 0
                                        logger.notice("Minimum rating set to Any")
                                    }) {
                                        Text("Any")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(minimumRating == 0 ? accentColor : Color.gray.opacity(0.15))
                                            )
                                            .foregroundColor(minimumRating == 0 ? .white : .primary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: minimumRating == 0)
                                    
                                    Spacer()
                                    
                                    StarRatingView(
                                        rating: minimumRating,
                                        maxRating: 5,
                                        size: 28,
                                        color: .yellow,
                                        isInteractive: true,
                                        onRatingChanged: { rating in
                                            minimumRating = rating
                                            logger.notice("Minimum rating set to \(rating)")
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Active filters summary - keep this but remove the Reset button
                    let filterCount = getActiveFilterCount()
                    if filterCount > 0 {
                        HStack {
                            Text("\(filterCount) \(filterCount == 1 ? "filter" : "filters") active")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(backgroundColor)
        }
        .background(backgroundColor)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // Toggle price level selection
    private func togglePriceLevel(_ level: Int) {
        // Create a mutable copy of the set
        var updatedPriceLevels = selectedPriceLevels
        
        if selectedPriceLevels.contains(level) {
            // Don't allow deselecting all price levels
            if selectedPriceLevels.count > 1 {
                updatedPriceLevels.remove(level)
            }
        } else {
            updatedPriceLevels.insert(level)
        }
        
        // Update the state with the new set
        selectedPriceLevels = updatedPriceLevels
        
        logger.notice("Price level \(level) \(selectedPriceLevels.contains(level) ? "selected" : "deselected"). Selected levels: \(selectedPriceLevels)")
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Reset all filters
    private func resetFilters() {
        // Reset to default values (all price levels selected)
        selectedPriceLevels = [1, 2, 3, 4]
        showOpenNowOnly = false
        minimumRating = 0
        useLocalRatings = false
        
        logger.notice("All filters reset to default values")
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Apply filters and dismiss the sheet
    func applyFilters() {
        // Update the view model with the selected price levels
        viewModel.selectedPriceLevels = selectedPriceLevels
        
        // Update the view model with the minimum rating and rating source
        viewModel.minimumRating = minimumRating
        viewModel.useLocalRatings = useLocalRatings
        
        // Apply the filters
        viewModel.applyFilters()
        
        // Log filter application
        let filterCount = getActiveFilterCount()
        logger.notice("\(filterCount) \(filterCount == 1 ? "filter" : "filters") applied")
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Helper to count active filters
    func getActiveFilterCount() -> Int {
        var count = 0
        
        // Count price level filters
        if selectedPriceLevels.count < 4 {
            count += 1
        }
        
        // Count open now filter (not functional yet)
        if showOpenNowOnly {
            count += 1
        }
        
        // Count minimum rating filter (not functional yet)
        if minimumRating > 0 {
            count += 1
        }
        
        return count
    }
}

#Preview {
    FilterView(viewModel: HomeViewModel(placesService: PlacesService(), userPreferences: UserPreferences()))
}
