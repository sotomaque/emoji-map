import SwiftUI

struct SkeletonPhotoView: View {
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 16
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity, maxHeight: height)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius, 
                    bottomLeadingRadius: 0, 
                    bottomTrailingRadius: 0, 
                    topTrailingRadius: cornerRadius
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius, 
                    bottomLeadingRadius: 0, 
                    bottomTrailingRadius: 0, 
                    topTrailingRadius: cornerRadius
                )
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shimmering()
    }
}

struct SkeletonReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reviewer name
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 16)
                .cornerRadius(4)
            
            // Rating
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .cornerRadius(8)
                }
            }
            
            // Review text
            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 12)
                    .cornerRadius(2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .shimmering() 
    }
}

// Renamed to avoid conflicts with PlaceDetailView implementation
struct SkeletonShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.white.opacity(0.5), location: 0.3),
                            .init(color: Color.white.opacity(0.5), location: 0.7),
                            .init(color: Color.clear, location: 1),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2) * phase)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// Renamed extension to avoid conflicts
extension View {
    func shimmering() -> some View {
        modifier(SkeletonShimmerModifier())
    }
}

#Preview {
    VStack(spacing: 20) {
        SkeletonPhotoView()
        
        SkeletonReviewCard()
    }
    .padding()
} 
