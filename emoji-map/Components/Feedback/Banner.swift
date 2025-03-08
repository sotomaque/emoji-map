import SwiftUI

enum BannerStyle {
    case notification
    case warning
    case error
    
    var backgroundColor: Color {
        switch self {
        case .notification:
            return Color.black.opacity(0.8)
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
    
    var textColor: Color {
        return .white
    }
    
    var font: Font {
        switch self {
        case .notification:
            return .system(size: 16, weight: .medium)
        case .warning, .error:
            return .system(size: 14, weight: .medium)
        }
    }
    
    var height: CGFloat {
        switch self {
        case .notification:
            return 60
        case .warning, .error:
            return 40
        }
    }
    
    // Instead of returning a shape, return a ViewModifier that applies the appropriate shape
    @ViewBuilder
    func backgroundShape<S: ShapeStyle>(fill: S) -> some View {
        switch self {
        case .notification:
            Capsule()
                .fill(fill)
        case .warning, .error:
            Rectangle()
                .fill(fill)
        }
    }
}

struct Banner: View {
    let message: String
    let isVisible: Bool
    let style: BannerStyle
    var onAppear: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if isVisible {
                Text(message)
                    .font(style.font)
                    .multilineTextAlignment(.center)
                    .foregroundColor(style.textColor)
                    .padding(.vertical, style == .notification ? 12 : 8)
                    .padding(.horizontal, style == .notification ? 20 : 16)
                    .background(
                        style.backgroundShape(fill: style.backgroundColor)
                            .shadow(
                                color: .black.opacity(0.2),
                                radius: style == .notification ? 8 : 3,
                                x: 0,
                                y: style == .notification ? 4 : 2
                            )
                    )
                    .padding(.top, style == .notification ? 4 : 0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onAppear {
                        onAppear?()
                    }
            }
        }
        .frame(height: isVisible ? style.height : 0) // Adjust height based on visibility and style
    }
}

// MARK: Preview
struct BannerPreview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Banner(
                message: "Location updated",
                isVisible: true,
                style: .notification
            )
            
            Banner(
                message: "API key not configured properly",
                isVisible: true,
                style: .warning
            )
            
            Banner(
                message: "Network connection lost",
                isVisible: true,
                style: .error
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
