import SwiftUI

// MARK: SkeletonPhotoView
struct SkeletonPhotoView: View {
    var height: CGFloat = 200
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            Color.gray.opacity(0.1),
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.1)
                        ]
                    ),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity, maxHeight: height)
            .shimmering(opacity: 0.3)
    }
}

// MARK: SkeletonReviewCard
struct SkeletonReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reviewer name
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 120, height: 16)
                .cornerRadius(4)
            
            // Rating
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 16, height: 16)
                        .cornerRadius(8)
                }
            }
            
            // Review text
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 12)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 12)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 200, height: 12)
                    .cornerRadius(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        .shimmering(opacity: 0.3)
    }
}

// MARK: SkeletonShimmerModifier
struct SkeletonShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var opacity: CGFloat = 0.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(
                            stops: [
                                .init(color: Color.clear, location: 0),
                                .init(
                                    color: Color.white.opacity(opacity),
                                    location: 0.3
                                ),
                                .init(
                                    color: Color.white.opacity(opacity),
                                    location: 0.7
                                ),
                                .init(color: Color.clear, location: 1),
                            ]
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(
                        x: -geometry.size
                            .width + (geometry.size.width * 2) * phase
                    )
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    Animation
                        .linear(duration: 2.0)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering(opacity: CGFloat = 0.5) -> some View {
        modifier(SkeletonShimmerModifier(opacity: opacity))
    }
}

// MARK: Preview
struct SkeletonViewPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SkeletonPhotoView()
            
            SkeletonReviewCard()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
