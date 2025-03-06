import SwiftUI

struct StarRatingDisplayView: View {
    let rating: Int
    let maxRating: Int
    let size: CGFloat
    let spacing: CGFloat
    let color: Color
    
    init(
        rating: Int,
        maxRating: Int = 5,
        size: CGFloat = 20,
        spacing: CGFloat = 2,
        color: Color = .yellow
    ) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.spacing = spacing
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingDisplayView(rating: 3)
        StarRatingDisplayView(rating: 5, size: 30, color: .orange)
        StarRatingDisplayView(rating: 2, maxRating: 4, size: 15, color: .blue)
    }
    .padding()
    .previewLayout(.sizeThatFits)
} 