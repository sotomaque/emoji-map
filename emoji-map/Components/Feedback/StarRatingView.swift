import SwiftUI
import os

struct StarRatingView: View {
    let maxRating: Int
    let rating: Int
    let size: CGFloat
    let spacing: CGFloat
    let color: Color
    let isInteractive: Bool
    let onRatingChanged: ((Int) -> Void)?
    
    // Add logger for debugging
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "StarRatingView")
    
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
                        view
                            // Use a simultaneous gesture to prevent the sheet from being dismissed
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        if let onRatingChanged = onRatingChanged {
                                            // If tapping the current rating, clear it (set to 0)
                                            let newRating = index == rating ? 0 : index
                                            logger.debug("⭐️ Star \(index) tapped. Current rating: \(rating), New rating: \(newRating)")
                                            
                                            // Log before calling the callback
                                            logger.debug("⭐️ About to call onRatingChanged with rating: \(newRating)")
                                            
                                            // Call the callback
                                            onRatingChanged(newRating)
                                            
                                            // Log after calling the callback
                                            logger.debug("⭐️ Called onRatingChanged with rating: \(newRating)")
                                        } else {
                                            logger.debug("⭐️ Star \(index) tapped but no callback provided")
                                        }
                                    }
                            )
                            // Add a drag gesture that does nothing but prevents other gestures from being recognized
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in }
                                    .onEnded { _ in }
                            )
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
                // Add a background that captures all gestures
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {} // Capture taps but do nothing
                )
        }
    }
    
    @ViewBuilder
    private func starView(for index: Int) -> some View {
        if isInteractive {
            Image(systemName: index <= rating ? "star.fill" : "star")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // Add contentShape to improve tap area
                .contentShape(Rectangle())
                // Add padding to increase the tap area
                .padding(4)
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
