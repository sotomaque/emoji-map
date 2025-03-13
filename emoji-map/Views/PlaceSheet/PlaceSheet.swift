//
//  PlaceSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import SwiftUI

struct PlaceSheet: View {
    var place: Place?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let place = place {
                // Place details
                HStack {
                    Text(place.emoji)
                        .font(.system(size: 60))
                    
                    VStack(alignment: .leading) {
                        Text("ID: \(place.id)")
                            .font(.headline)
                        
                        Text("Location: \(String(format: "%.6f", place.location.latitude)), \(String(format: "%.6f", place.location.longitude))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
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

#Preview {
    PlaceSheet(place: Place(id: "preview-id", emoji: "🏠", location: Place.Location(latitude: 37.7749, longitude: -122.4194)))
} 