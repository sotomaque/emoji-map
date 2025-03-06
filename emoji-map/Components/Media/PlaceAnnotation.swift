import SwiftUI

struct PlaceAnnotation: View {
    let emoji: String
    let isFavorite: Bool
    let rating: Int?
    let isLoading: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Show rating or star icon above emoji for favorites
                if isFavorite {
                    if let rating = rating, rating > 0 {
                        // Show numeric rating with star
                        HStack(spacing: 1) {
                            Text("\(rating)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .offset(y: 2)
                    } else {
                        // Show outline star for favorites without rating
                        Image(systemName: "star")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                            .offset(y: 2)
                    }
                }
                
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 40, height: 40)
                    .background(
                        isFavorite ?
                            Circle()
                                .fill(Color.yellow.opacity(0.3))
                                .frame(width: 44, height: 44)
                        : nil
                    )
            }
        }
        .scaleEffect(isLoading ? 0.8 : 1.0) // Subtle scale effect during loading
        .opacity(isLoading ? 0.6 : 1.0) // Fade out during loading
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        PlaceAnnotation(
            emoji: "🍕",
            isFavorite: true,
            rating: 4,
            isLoading: false,
            onTap: {}
        )
        
        PlaceAnnotation(
            emoji: "🏠",
            isFavorite: true,
            rating: nil,
            isLoading: false,
            onTap: {}
        )
        
        PlaceAnnotation(
            emoji: "🚗",
            isFavorite: false,
            rating: nil,
            isLoading: false,
            onTap: {}
        )
        
        PlaceAnnotation(
            emoji: "🏫",
            isFavorite: false,
            rating: nil,
            isLoading: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.2))
} 