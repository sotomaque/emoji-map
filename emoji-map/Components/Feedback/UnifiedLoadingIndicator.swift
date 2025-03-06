import SwiftUI
import MetalKit

/// A unified loading indicator that can use either standard SwiftUI or Metal-based animations
struct UnifiedLoadingIndicator: View {
    // MARK: - Properties
    let message: String
    var color: Color
    var style: LoadingStyle
    var backgroundColor: Color
    
    // MARK: - Initialization
    init(
        message: String = "Loading...",
        color: Color = .blue,
        style: LoadingStyle = .standard,
        backgroundColor: Color? = nil
    ) {
        self.message = message
        self.color = color
        self.style = style
        
        // Default background color based on style
        if let customBackground = backgroundColor {
            self.backgroundColor = customBackground
        } else {
            self.backgroundColor = style == .standard ? 
                Color.black.opacity(0.7) : 
                Color(.systemBackground).opacity(0.8)
        }
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            switch style {
            case .metal where MetalHelper.isMetalSupported:
                // Metal-based loading animation
                MetalLoadingView(color: color, message: message)
                    .frame(width: 200, height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(backgroundColor)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                
            case .compact:
                // Compact loading indicator for inline use
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(color)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                
            case .minimal:
                // Minimal loading indicator that doesn't block the UI
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(color)
                    
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
            
            default:
                // Standard SwiftUI loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(style == .standard ? .white : color)
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(style == .standard ? .white : .primary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
            }
        }
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            // Only provide haptic feedback for standard and metal styles
            if style == .standard || style == .metal {
                HapticsManager.shared.mediumImpact()
            }
        }
    }
    
    // MARK: - Loading Styles
    enum LoadingStyle {
        case standard
        case metal
        case compact
        case minimal
    }
}

// Helper to check Metal support
enum MetalHelper {
    static var isMetalSupported: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }
}

// MARK: - Preview
struct UnifiedLoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UnifiedLoadingIndicator(
                message: "Standard Loading...",
                style: .standard
            )
            .padding()
            .previewDisplayName("Standard")
            
            UnifiedLoadingIndicator(
                message: "Metal Loading...",
                style: .metal
            )
            .padding()
            .previewDisplayName("Metal")
            
            UnifiedLoadingIndicator(
                message: "Custom Background...",
                color: .green,
                style: .standard,
                backgroundColor: Color.green.opacity(0.2)
            )
            .padding()
            .previewDisplayName("Custom")
            
            UnifiedLoadingIndicator(
                message: "Compact Loading...",
                color: .blue,
                style: .compact,
                backgroundColor: Color.white
            )
            .padding()
            .previewDisplayName("Compact")
        }
        .previewLayout(.sizeThatFits)
    }
} 