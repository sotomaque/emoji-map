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
    // Track initial open now value to detect changes
    @State private var initialOpenNowOnly: Bool = false
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
        // Only consider rating source change as a meaningful change if a rating value is active
        let ratingSourceChanged = useLocalRatings != viewModel.useLocalRatings && 
                                  (minimumRating > 0 || viewModel.minimumRating > 0)
        
        // Check if open now filter has changed
        let openNowChanged = showOpenNowOnly != initialOpenNowOnly
        
        // Log the change state for debugging
        if useLocalRatings != viewModel.useLocalRatings {
            logger.notice("Rating source changed: \(viewModel.useLocalRatings) -> \(useLocalRatings), minimumRating: \(minimumRating), viewModel rating: \(viewModel.minimumRating), considered as change: \(ratingSourceChanged)")
        }
        
        return priceLevelsChanged || ratingChanged || ratingSourceChanged || openNowChanged
    }
    
    // Computed property to check if filters are non-default
    private var hasNonDefaultFilters: Bool {
        // Check if price levels are not all selected (default is all selected)
        let hasPriceLevelFilters = !viewModel.allPriceLevelsSelected
        
        // Check if minimum rating filter is active
        let hasRatingFilter = minimumRating > 0
        
        // Check if any filter is active
        return hasPriceLevelFilters || hasRatingFilter || showOpenNowOnly
    }
    
    // Computed property to check if all price levels are selected in the local state or none are selected
    private var allPriceLevelsSelectedLocally: Bool {
        // If no price levels are selected, it's the same as all being selected (no filtering)
        if selectedPriceLevels.isEmpty {
            return true
        }
        
        // Otherwise, check if all 4 price levels are selected
        return selectedPriceLevels.count == 4 && 
               selectedPriceLevels.contains(1) && 
               selectedPriceLevels.contains(2) && 
               selectedPriceLevels.contains(3) && 
               selectedPriceLevels.contains(4)
    }
    
    // Initialize with the view model and load current filter settings
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        
        // Log the view model's price levels
        logger.notice("View model price levels: \(Array(viewModel.selectedPriceLevels).sorted()), allPriceLevelsSelected: \(viewModel.allPriceLevelsSelected)")
        
        // Initialize price levels from the view model
        let priceLevels = viewModel.selectedPriceLevels
        
        // If the view model has no price levels selected, use all price levels
        let initialPriceLevels = priceLevels.isEmpty ? Set([1, 2, 3, 4]) : priceLevels
        
        // Initialize state variables
        _selectedPriceLevels = State(initialValue: initialPriceLevels)
        _initialPriceLevels = State(initialValue: initialPriceLevels)
        
        // Initialize rating filter state from view model
        _minimumRating = State(initialValue: viewModel.minimumRating)
        _useLocalRatings = State(initialValue: viewModel.useLocalRatings)
        
        // Initialize open now filter state from view model
        _showOpenNowOnly = State(initialValue: viewModel.showOpenNowOnly)
        _initialOpenNowOnly = State(initialValue: viewModel.showOpenNowOnly)
        
        logger.notice("Initialized FilterView with price levels: \(Array(initialPriceLevels).sorted())")
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
                                logger.notice("Open Now toggle changed from \(oldValue) to \(newValue)")
                            }
                    }
                    
                    // Minimum Rating Card - fully functional for both Google Maps and user ratings
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
                            }
                            
                            Divider()
                            
                            // Rating selection
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Minimum: \(minimumRating) \(minimumRating == 1 ? "star" : "stars")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
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
        
        // Check if we're in the initial state with all price levels selected or none selected
        let allSelected = selectedPriceLevels.count == 4 && 
                          selectedPriceLevels.contains(1) && 
                          selectedPriceLevels.contains(2) && 
                          selectedPriceLevels.contains(3) && 
                          selectedPriceLevels.contains(4)
        let noneSelected = selectedPriceLevels.isEmpty
        
        // If all are selected or none are selected, and user clicks on a level,
        // clear everything and select only that level
        if (allSelected || noneSelected) && !selectedPriceLevels.contains(level) {
            updatedPriceLevels.removeAll()
            updatedPriceLevels.insert(level)
            logger.notice("Starting from all/none selected: cleared all and selected only \(level)")
        } 
        // If all are selected and user clicks on a selected level, 
        // clear everything except that level (keep only that level)
        else if allSelected && selectedPriceLevels.contains(level) {
            updatedPriceLevels.removeAll()
            updatedPriceLevels.insert(level)
            logger.notice("Starting from all selected: kept only \(level)")
        }
        // Normal toggle behavior for other cases
        else if selectedPriceLevels.contains(level) {
            // If this is the only selected level, don't allow deselecting it
            if selectedPriceLevels.count == 1 {
                return
            }
            
            // Otherwise, remove this price level
            updatedPriceLevels.remove(level)
            logger.notice("Removed price level \(level)")
        } else {
            // Add this level to the existing selection
            updatedPriceLevels.insert(level)
            logger.notice("Added price level \(level) to existing selection")
        }
        
        // Update the state with the new set
        selectedPriceLevels = updatedPriceLevels
        
        logger.notice("Price level selection updated. Selected levels: \(Array(selectedPriceLevels).sorted())")
        
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
        
        logger.notice("All filters reset to default values: all price levels selected, minimum rating cleared")
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Apply filters and dismiss the sheet
    func applyFilters() {
        // If no price levels are selected, treat it as all price levels selected
        let priceLevelsToApply = selectedPriceLevels.isEmpty ? Set([1, 2, 3, 4]) : selectedPriceLevels
        
        // Update the view model with the selected price levels
        viewModel.selectedPriceLevels = priceLevelsToApply
        
        // Update the view model with the minimum rating and rating source
        viewModel.minimumRating = minimumRating
        viewModel.useLocalRatings = useLocalRatings
        
        // Update the view model with the open now filter
        viewModel.showOpenNowOnly = showOpenNowOnly
        
        // Apply the filters
        viewModel.applyFilters()
        
        // Log filter application
        let filterCount = getActiveFilterCount()
        logger.notice("\(filterCount) \(filterCount == 1 ? "filter" : "filters") applied with price levels: \(Array(priceLevelsToApply).sorted())")
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Helper to count active filters
    func getActiveFilterCount() -> Int {
        var count = 0
        
        // Count price level filters
        if !allPriceLevelsSelectedLocally {
            count += 1
        }
        
        // Count open now filter (not functional yet)
        if showOpenNowOnly {
            count += 1
        }
        
        // Count minimum rating filter
        if minimumRating > 0 {
            count += 1
        }
        
        return count
    }
}

#Preview {
    FilterView(viewModel: HomeViewModel(placesService: PlacesService(), userPreferences: UserPreferences()))
}
