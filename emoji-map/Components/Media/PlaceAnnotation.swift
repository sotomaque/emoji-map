import SwiftUI

struct PlaceAnnotation: View {
    let emoji: String
    let isFavorite: Bool
    let rating: Int?
    let isLoading: Bool
    let onTap: () -> Void
    
    // Animation states
    @State private var animateIn = false
    @State private var bounce = false
    @State private var rotation = Double.random(in: -20...20)
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Show user rating if available
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
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2), value: animateIn)
                } else if isFavorite {
                    // Show outline star for favorites without rating
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                        .offset(y: 2)
                        .opacity(animateIn ? 1 : 0)
                        .scaleEffect(animateIn ? 1 : 0.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2), value: animateIn)
                }
                
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 40, height: 40)
                    .background(
                        isFavorite ?
                            Circle()
                                .fill(Color.yellow.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .scaleEffect(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animateIn)
                        : nil
                    )
                    .scaleEffect(bounce ? 1.1 : 1.0)
                    .rotationEffect(.degrees(animateIn ? 0 : rotation))
                    .animation(
                        bounce ? 
                            Animation.spring(response: 0.3, dampingFraction: 0.6).repeatCount(1, autoreverses: true) : 
                            .default,
                        value: bounce
                    )
            }
            .offset(y: animateIn ? 0 : -20)
            .scaleEffect(isLoading ? 0.8 : (animateIn ? 1.0 : 0.01))
            .opacity(isLoading ? 0.6 : (animateIn ? 1.0 : 0.0))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateIn)
            .animation(.easeInOut(duration: 0.3), value: isLoading)
        }
        .onAppear {
            // Trigger entrance animation with a slight delay for staggered effect
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.4)) {
                withAnimation {
                    animateIn = true
                }
                
                // Add a bounce effect after the entrance animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    bounce = true
                    
                    // Reset bounce after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        bounce = false
                    }
                }
            }
        }
    }
}


// MARK: Preview
struct PlaceAnnotationPreview: PreviewProvider {
    static var previews: some View {
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
                rating: 3,
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
        .previewLayout(.sizeThatFits)
    }
}
