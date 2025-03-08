import SwiftUI

struct FiltersView: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Local state for the filters
    @State var selectedPriceLevels: Set<Int>
    @State var showOpenNowOnly: Bool
    @State var minimumRating: Int
    @State var useLocalRatings: Bool
    
    // Completion handler for testing
    var onApplyFilters: (() -> Void)?
    
    // Initialize with current filter values
    init(
        selectedPriceLevels: Set<Int>, 
        showOpenNowOnly: Bool, 
        minimumRating: Int,
        useLocalRatings: Bool = false,
        onApplyFilters: (() -> Void)? = nil
    ) {
        _selectedPriceLevels = State(initialValue: selectedPriceLevels)
        _showOpenNowOnly = State(initialValue: showOpenNowOnly)
        _minimumRating = State(initialValue: minimumRating)
        _useLocalRatings = State(initialValue: useLocalRatings)
        self.onApplyFilters = onApplyFilters
    }
    
    // Colors for the UI
    private var accentColor: Color { Color.blue }
    private var backgroundColor: Color { colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground) }
    private var cardBackgroundColor: Color { colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Reset") {
                    resetFilters()
                }
                .foregroundColor(accentColor)
                
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
                .foregroundColor(accentColor)
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
                    
                    // Open Now Card
                    FilterCard(title: "Open Now") {
                        Toggle("Show only places open now", isOn: $showOpenNowOnly)
                            .tint(accentColor)
                            .padding(.vertical, 4)
                    }
                    
                    // Minimum Rating Card
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
                                    
                                    if minimumRating > 0 {
                                        Button("Clear") {
                                            minimumRating = 0
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(accentColor)
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        minimumRating = 0
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
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // Active filters summary
                    let filterCount = getActiveFilterCount()
                    if filterCount > 0 {
                        HStack {
                            Text("\(filterCount) \(filterCount == 1 ? "filter" : "filters") active")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: resetFilters) {
                                Text("Reset All")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
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
    
    func togglePriceLevel(_ level: Int) {
        // Create a mutable copy of the set for testing
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
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func resetFilters() {
        selectedPriceLevels = [1, 2, 3, 4]
        showOpenNowOnly = false
        minimumRating = 0
        useLocalRatings = false
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func applyFilters() {
        // Apply filters to the view model
        testableViewModel.selectedPriceLevels = selectedPriceLevels
        testableViewModel.showOpenNowOnly = showOpenNowOnly
        testableViewModel.minimumRating = minimumRating
        testableViewModel.useLocalRatings = useLocalRatings
        
        // Fetch places with the new filters
        Task {
            try? await testableViewModel.fetchAndUpdatePlaces()
        }
        
        // Show notification with filter summary
        let filterCount = getActiveFilterCount()
        if filterCount > 0 {
            testableViewModel.showNotificationMessage("\(filterCount) \(filterCount == 1 ? "filter" : "filters") applied")
        } else {
            testableViewModel.showNotificationMessage("All filters cleared")
        }
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Call the completion handler if provided (for testing)
        onApplyFilters?()
    }
    
    // Helper method for testing - allows setting the environment object directly
    mutating func setViewModel(_ viewModel: MapViewModel) {
        // For testing purposes only
        // Store the viewModel in a static property that can be accessed by the test
        FiltersView.testViewModel = viewModel
    }
    
    // Static property to hold the test view model
    private static var testViewModel: MapViewModel?
    
    // Override the viewModel property for testing
    var testableViewModel: MapViewModel {
        return FiltersView.testViewModel ?? viewModel
    }
    
    func getActiveFilterCount() -> Int {
        var count = 0
        
        // Count price level filters
        if selectedPriceLevels.count < 4 {
            count += 1
        }
        
        // Count open now filter
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

// Custom card view for filters
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

