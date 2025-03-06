# UI Components Guide for Emoji Map

This document explains the key UI components in the Emoji Map application, with a focus on z-index management and notification banners.

## Z-Index Management

SwiftUI uses the `zIndex` modifier to control the layering of views. In Emoji Map, we use a consistent z-index hierarchy to ensure proper layering:

### Z-Index Hierarchy

| Component           | Z-Index | Description                              |
| ------------------- | ------- | ---------------------------------------- |
| Map                 | 0       | Base layer (default)                     |
| Notification Banner | 10      | Appears below other UI elements          |
| Control Buttons     | 20      | Recenter and filter buttons              |
| Emoji Selector      | 50      | Category selection bar at top            |
| Modal Overlays      | 100     | Permission dialogs, full-screen overlays |

### Best Practices

1. **Consistent Values**: Use the values in the table above for consistency
2. **Minimal Nesting**: Keep view hierarchy as flat as possible
3. **Explicit Assignment**: Always explicitly set z-index values for overlapping elements

## Notification Banner

The notification banner displays temporary messages to the user.

### Implementation

The `NotificationBanner` component is implemented in `Components/Feedback/NotificationBanner.swift`:

```swift
struct NotificationBanner: View {
    let message: String
    let isVisible: Bool
    var onAppear: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                if isVisible {
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                                .shadow(
                                    color: .black.opacity(0.2),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            onAppear?()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: geometry.size.width)
        }
        .animation(.spring(response: 0.4), value: isVisible)
        .frame(height: 80)
        .zIndex(10) // Lower z-index to ensure it's below the emoji selector
    }
}
```

### Usage

The notification banner is positioned in the main `ContentView` as a separate element in the view hierarchy:

```swift
// Notification banner - positioned as a separate element
if viewModel.showNotification {
    VStack {
        Spacer() // Push to bottom

        NotificationBanner(
            message: viewModel.notificationMessage,
            isVisible: true,
            onAppear: {
                // Trigger haptic feedback when notification appears
                triggerHapticFeedback()
            }
        )
        .padding(.bottom, 100) // Add padding to position above bottom buttons
    }
    .zIndex(10) // Lower z-index to ensure it's below the emoji selector
}
```

### Positioning

The notification banner is designed to appear below the emoji selector but above the map. Key points:

1. It has a z-index of 10, which is lower than the emoji selector (50)
2. It's positioned at the bottom of the screen with padding
3. It uses a spring animation for smooth appearance/disappearance
4. It includes haptic feedback when appearing

## Warning Banner

Similar to the notification banner, the warning banner displays important alerts at the top of the screen:

```swift
struct WarningBanner: View {
    let message: String
    let isVisible: Bool
    var backgroundColor: Color = .orange

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isVisible {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(backgroundColor)
                        .cornerRadius(0)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }

                Spacer()
            }
            .frame(width: geometry.size.width)
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .ignoresSafeArea(.all, edges: .top)
        .zIndex(999) // Very high z-index to ensure it's above other elements
    }
}
```

## Troubleshooting Z-Index Issues

If you encounter layering issues:

1. **Check Parent-Child Relationships**: Z-index is relative to the parent view
2. **Flatten View Hierarchy**: Move overlapping elements to the same level in the hierarchy
3. **Explicit Z-Index**: Always set explicit z-index values for overlapping elements
4. **Use GeometryReader**: For complex positioning, use GeometryReader to get precise control
5. **Check Transitions**: Ensure transitions don't interfere with z-index values

## Haptic Feedback

The app uses haptic feedback to enhance the notification experience:

```swift
private func triggerHapticFeedback() {
    // Prevent multiple haptics in quick succession
    let now = Date()
    if now.timeIntervalSince(lastHapticTime) > 1.0 {
        HapticsManager.shared.notification(type: .success)
        lastHapticTime = now
    }
}
```

This provides a subtle tactile response when notifications appear.
