//
//  PlaceSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI
import os.log

struct FilterCard: View {
    let title: String
    let content: AnyView
    
    init<Content: View>(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct FilterView: View {
    // State for selected price levels
    @State private var selectedPriceLevels: Set<Int> = []
    // Track initial price levels to detect changes
    @State private var initialPriceLevels: Set<Int> = []
    // Environment to dismiss the sheet
    @Environment(\.dismiss) private var dismiss
    // Reference to the HomeViewModel
    @ObservedObject var viewModel: HomeViewModel
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "FilterView")
    
    // Accent color for selected items
    private let accentColor = Color.blue
    
    // Computed property to check if filters have changed
    private var filtersChanged: Bool {
        return selectedPriceLevels != initialPriceLevels
    }
    
    // Initialize with the view model and load current filter settings
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        
        // Initialize with current filter settings from the view model
        let priceLevels = viewModel.selectedPriceLevels
        _selectedPriceLevels = State(initialValue: priceLevels)
        _initialPriceLevels = State(initialValue: priceLevels)
    }
    
    var body: some View {
        VStack {
            // Header with title and Apply button
            HStack {
                Text("Filter Places")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Apply") {
                    applyFilters()
                }
                .font(.headline)
                .foregroundColor(filtersChanged ? .blue : .gray)
                .disabled(!filtersChanged)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(filtersChanged ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                )
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                    
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    // Toggle price level selection
    private func togglePriceLevel(_ level: Int) {
        if selectedPriceLevels.contains(level) {
            selectedPriceLevels.remove(level)
            logger.notice("Price level \(level) deselected. Selected levels: \(selectedPriceLevels)")
        } else {
            selectedPriceLevels.insert(level)
            logger.notice("Price level \(level) selected. Selected levels: \(selectedPriceLevels)")
        }
    }
    
    // Apply filters and dismiss the sheet
    func applyFilters() {
        // Update the view model with the selected price levels
        viewModel.selectedPriceLevels = selectedPriceLevels
        
        // Apply the filters
        viewModel.applyFilters()
        
        // Dismiss the sheet
        dismiss()
    }
}

#Preview {
    FilterView(viewModel: HomeViewModel(placesService: PlacesService(), userPreferences: UserPreferences()))
}
