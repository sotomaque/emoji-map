import SwiftUI

struct FiltersView: View {
    @EnvironmentObject private var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Local state for the filters
    @State var selectedPriceLevels: Set<Int>
    @State var showOpenNowOnly: Bool
    @State var minimumRating: Int
    
    // Initialize with current filter values
    init(selectedPriceLevels: Set<Int>, showOpenNowOnly: Bool, minimumRating: Int) {
        _selectedPriceLevels = State(initialValue: selectedPriceLevels)
        _showOpenNowOnly = State(initialValue: showOpenNowOnly)
        _minimumRating = State(initialValue: minimumRating)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Price Level Section
                Section(header: Text("Price Level")) {
                    HStack {
                        ForEach(1...4, id: \.self) { level in
                            Button(action: {
                                togglePriceLevel(level)
                            }) {
                                Text(String(repeating: "$", count: level))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedPriceLevels.contains(level) ? Color.blue : Color.gray.opacity(0.2))
                                    )
                                    .foregroundColor(selectedPriceLevels.contains(level) ? .white : .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Open Now Section
                Section(header: Text("Open Now")) {
                    Toggle("Show only places open now", isOn: $showOpenNowOnly)
                        .tint(.blue)
                }
                
                // Minimum Rating Section
                Section(header: Text("Minimum Rating")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Minimum: \(minimumRating) \(minimumRating == 1 ? "star" : "stars")")
                                .font(.headline)
                            Spacer()
                            if minimumRating > 0 {
                                Button("Clear") {
                                    minimumRating = 0
                                }
                                .foregroundColor(.blue)
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
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(minimumRating == 0 ? Color.blue : Color.gray.opacity(0.2))
                                    )
                                    .foregroundColor(minimumRating == 0 ? .white : .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
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
                
                // Reset Section
                Section {
                    Button(action: resetFilters) {
                        Text("Reset All Filters")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyFilters()
                    }
                    .bold()
                }
            }
        }
    }
    
    func togglePriceLevel(_ level: Int) {
        if selectedPriceLevels.contains(level) {
            // Don't allow deselecting all price levels
            if selectedPriceLevels.count > 1 {
                selectedPriceLevels.remove(level)
            }
        } else {
            selectedPriceLevels.insert(level)
        }
    }
    
    func resetFilters() {
        selectedPriceLevels = [1, 2, 3, 4]
        showOpenNowOnly = false
        minimumRating = 0
    }
    
    func applyFilters() {
        // Apply filters to the view model
        // Wrap in a do-catch to handle the case when the view model might not be available in tests
        do {
            viewModel.selectedPriceLevels = selectedPriceLevels
            viewModel.showOpenNowOnly = showOpenNowOnly
            viewModel.minimumRating = minimumRating
            
            // Fetch places with the new filters
            Task {
                try await viewModel.fetchAndUpdatePlaces()
            }
            
            // Show notification with filter summary
            let filterCount = getActiveFilterCount()
            if filterCount > 0 {
                viewModel.showNotificationMessage("\(filterCount) \(filterCount == 1 ? "filter" : "filters") applied")
            } else {
                viewModel.showNotificationMessage("All filters cleared")
            }
        } catch {
            print("Error applying filters: \(error)")
        }
        
        dismiss()
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

#Preview {
    FiltersView(
        selectedPriceLevels: [1, 2, 3, 4],
        showOpenNowOnly: false,
        minimumRating: 0
    )
    .environmentObject(MapViewModel(googlePlacesService: GooglePlacesService()))
    .frame(height: 600)
} 