import SwiftUI

struct StarRatingView: View {
    let maxRating: Int
    let currentRating: Int
    let size: CGFloat
    let color: Color
    let onRatingChanged: ((Int) -> Void)?
    
    init(
        maxRating: Int = 5,
        currentRating: Int = 0,
        size: CGFloat = 24,
        color: Color = .yellow,
        onRatingChanged: ((Int) -> Void)? = nil
    ) {
        self.maxRating = maxRating
        self.currentRating = min(max(currentRating, 0), maxRating)
        self.size = size
        self.color = color
        self.onRatingChanged = onRatingChanged
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { rating in
                Image(systemName: rating <= currentRating ? "star.fill" : "star")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundColor(color)
                    .onTapGesture {
                        if let onRatingChanged = onRatingChanged {
                            // If tapping the current rating, clear it (set to 0)
                            let newRating = rating == currentRating ? 0 : rating
                            onRatingChanged(newRating)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(currentRating) out of \(maxRating) stars")
        .accessibilityValue(currentRating == 0 ? "No rating" : "\(currentRating) stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if let onRatingChanged = onRatingChanged, currentRating < maxRating {
                    onRatingChanged(currentRating + 1)
                }
            case .decrement:
                if let onRatingChanged = onRatingChanged, currentRating > 0 {
                    onRatingChanged(currentRating - 1)
                }
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingView(currentRating: 3)
        
        StarRatingView(currentRating: 4, size: 32, color: .orange)
    }
    .padding()
} 