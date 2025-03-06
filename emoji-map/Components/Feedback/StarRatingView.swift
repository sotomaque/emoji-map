import SwiftUI

struct StarRatingView: View {
    let maxRating: Int
    let rating: Int
    let size: CGFloat
    let spacing: CGFloat
    let color: Color
    let isInteractive: Bool
    let onRatingChanged: ((Int) -> Void)?
    
    init(
        rating: Int = 0,
        maxRating: Int = 5,
        size: CGFloat = 24,
        spacing: CGFloat = 4,
        color: Color = .yellow,
        isInteractive: Bool = false,
        onRatingChanged: ((Int) -> Void)? = nil
    ) {
        self.maxRating = maxRating
        self.rating = min(max(rating, 0), maxRating)
        self.size = size
        self.spacing = spacing
        self.color = color
        self.isInteractive = isInteractive
        self.onRatingChanged = onRatingChanged
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starView(for: index)
                    .foregroundColor(color)
                    .if(isInteractive) { view in
                        view.onTapGesture {
                            if let onRatingChanged = onRatingChanged {
                                // If tapping the current rating, clear it (set to 0)
                                let newRating = index == rating ? 0 : index
                                onRatingChanged(newRating)
                            }
                        }
                    }
            }
        }
        .if(isInteractive) { view in
            view
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rating: \(rating) out of \(maxRating) stars")
                .accessibilityValue(rating == 0 ? "No rating" : "\(rating) stars")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        if let onRatingChanged = onRatingChanged, rating < maxRating {
                            onRatingChanged(rating + 1)
                        }
                    case .decrement:
                        if let onRatingChanged = onRatingChanged, rating > 0 {
                            onRatingChanged(rating - 1)
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
    
    @ViewBuilder
    private func starView(for index: Int) -> some View {
        if isInteractive {
            Image(systemName: index <= rating ? "star.fill" : "star")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: index <= rating ? "star.fill" : "star")
                .font(.system(size: size))
        }
    }
}

// Extension to conditionally apply modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: Preview
struct StarRatingViewPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Group {
                Text("Display Mode (Non-Interactive)")
                    .font(.headline)
                
                StarRatingView(rating: 3)
                StarRatingView(rating: 5, size: 30, color: .orange)
                StarRatingView(rating: 2, maxRating: 4, size: 15, color: .blue)
            }
            
            Divider()
                .padding(.vertical)
            
            Group {
                Text("Interactive Mode")
                    .font(.headline)
                
                StarRatingView(
                    rating: 3,
                    isInteractive: true,
                    onRatingChanged: { _ in }
                )
                
                StarRatingView(
                    rating: 4,
                    size: 32,
                    color: .orange,
                    isInteractive: true,
                    onRatingChanged: { _ in }
                )
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
