import SwiftUI
import QuartzCore

// Protocol for communicating with parent view
protocol OnboardingSlideDelegate {
    func activateEasterEgg()
}

class EmojiAnimator: ObservableObject {
    @Published var currentEmojiIndex = 0
    @Published var isEasterEggActive = false
    private var displayLink: CADisplayLink?
    private var lastChangeTime: CFTimeInterval = 0
    private var changeInterval: CFTimeInterval = 1.5 // Change emoji every 1.5 seconds
    private let foodEmojis = ["🍕", "🍔", "🌮", "🍣", "🍜", "🍦", "🍷", "🍺", "☕️", "🥗", "🍲", "🥪"]
    
    var currentEmoji: String {
        return foodEmojis[currentEmojiIndex]
    }
    
    func startAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common) // .common mode ensures it runs during scrolling
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func activateEasterEgg() {
        isEasterEggActive = true
        // Speed up emoji changes when easter egg is active
        changeInterval = 0.5
    }
    
    func deactivateEasterEgg() {
        isEasterEggActive = false
        // Return to normal speed
        changeInterval = 1.5
    }
    
    @objc private func update(displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastChangeTime == 0 {
            lastChangeTime = currentTime
            return
        }
        
        // Check if it's time to change the emoji
        if currentTime - lastChangeTime >= changeInterval {
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.currentEmojiIndex = (self.currentEmojiIndex + 1) % self.foodEmojis.count
                }
            }
            lastChangeTime = currentTime
        }
    }
}

struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    @State private var animateIcon = false
    @State private var animateText = false
    @State private var animateBackground = false
    @State private var pulseEffect = false
    @State private var rotateEffect = false
    @State private var easterEggRotation: Double = 0
    @State private var easterEggScale: CGFloat = 1.0
    @StateObject private var emojiAnimator = EmojiAnimator()
    
    // Delegate for communicating with parent view
    var delegate: OnboardingSlideDelegate?
    
    // Check if this is the second slide (Find What You Crave)
    private var isSecondSlide: Bool {
        return slide.title == "Find What You Crave"
    }
    
    // Get the current emoji to display
    private var displayEmoji: String {
        if isSecondSlide {
            return emojiAnimator.currentEmoji
        } else {
            return slide.emoji
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 40) {
                // Icon with animation
                ZStack {
                    // Animated background circles
                    Circle()
                        .fill(slide.accentColor.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .scaleEffect(animateBackground ? 1.1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: animateBackground
                        )
                    
                    Circle()
                        .fill(slide.accentColor.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .scaleEffect(animateIcon ? 1.0 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: animateIcon
                        )
                    
                    Circle()
                        .fill(slide.accentColor.opacity(0.4))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseEffect ? 1.1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: pulseEffect
                        )
                    
                    // Emoji or SF Symbol with animations
                    if slide.emoji.isEmpty {
                        Image(systemName: slide.imageName)
                            .font(.system(size: 60))
                            .foregroundColor(slide.accentColor)
                            .scaleEffect(animateIcon ? 1.0 : 0.6)
                            .rotationEffect(rotateEffect ? .degrees(10) : .degrees(-10))
                            .animation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true),
                                value: rotateEffect
                            )
                    } else {
                        Text(displayEmoji)
                            .font(.system(size: 70))
                            .scaleEffect(animateIcon ? 1.0 : 0.6)
                            .rotationEffect(rotateEffect ? .degrees(10) : .degrees(-10))
                            .animation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true),
                                value: rotateEffect
                            )
                            .transition(.scale.combined(with: .opacity))
                            .id("emoji-\(emojiAnimator.currentEmojiIndex)") // Force view refresh when emoji changes
                    }
                    
                    // Sparkle effects
                    ForEach(0..<8) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundColor(slide.accentColor)
                            .offset(
                                x: 70 * cos(Double(i) * .pi / 4),
                                y: 70 * sin(Double(i) * .pi / 4)
                            )
                            .scaleEffect(pulseEffect ? 1.0 : 0.5)
                            .opacity(pulseEffect ? 1.0 : 0.0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.1),
                                value: pulseEffect
                            )
                    }
                }
                .shadow(color: slide.accentColor.opacity(0.3), radius: 15, x: 0, y: 10)
                .padding(.top, 20)
                // Apply 3D rotation for easter egg
                .rotation3DEffect(
                    .degrees(easterEggRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.5
                )
                .scaleEffect(easterEggScale)
                // Add long press gesture for easter egg on second slide
                .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 50, pressing: { isPressing in
                    // Only provide feedback for the second slide
                    if isPressing && isSecondSlide {
                        // Start haptic feedback sequence
                        startHapticFeedback()
                    }
                }) {
                    // Only activate easter egg on the second slide
                    if isSecondSlide {
                        activateEasterEgg()
                    }
                }
                
                // Text content with animation
                VStack(spacing: 20) {
                    Text(slide.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateText ? 1 : 0)
                        .offset(y: animateText ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateText)
                    
                    Text(slide.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(animateText ? 1 : 0)
                        .offset(y: animateText ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateText)
                    
                    // Easter egg hint for second slide
                    if isSecondSlide {
                        Text("Hint: Try holding on the emoji...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.6)
                            .padding(.top, 10)
                    }
                }
                .frame(height: isSecondSlide ? 180 : 150)
                
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                // Start animations with slight delays for a more dynamic effect
                withAnimation {
                    animateIcon = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation {
                        animateText = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        animateBackground = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation {
                        pulseEffect = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        rotateEffect = true
                    }
                }
                
                // Start emoji rotation for the second slide
                if isSecondSlide {
                    emojiAnimator.startAnimation()
                }
            }
            .onDisappear {
                // Clean up animation when view disappears
                if isSecondSlide {
                    emojiAnimator.stopAnimation()
                }
            }
        }
    }
    
    // Function to provide escalating haptic feedback during long press
    private func startHapticFeedback() {
        // Initial light feedback
        let lightGenerator = UIImpactFeedbackGenerator(style: .light)
        lightGenerator.impactOccurred()
        
        // Schedule increasingly intense feedback with more frequent pulses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let lightGenerator = UIImpactFeedbackGenerator(style: .light)
            lightGenerator.impactOccurred(intensity: 0.6)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            mediumGenerator.impactOccurred(intensity: 0.7)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            mediumGenerator.impactOccurred(intensity: 0.8)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.impactOccurred(intensity: 0.9)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            heavyGenerator.impactOccurred(intensity: 1.0)
            
            // Add a notification feedback at the end for a "success" feeling
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.prepare()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notificationGenerator.notificationOccurred(.success)
            }
        }
    }
    
    // Function to activate the easter egg
    private func activateEasterEgg() {
        // Provide strong haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Trigger intense haptic feedback with a pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
            impactGenerator.impactOccurred(intensity: 1.0)
            
            // Add a sequence of rapid pulses for a more exciting effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
                mediumGenerator.impactOccurred(intensity: 0.8)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
                    heavyGenerator.impactOccurred(intensity: 1.0)
                }
            }
        }
        
        // Animate 3D rotation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            easterEggRotation = 360
            easterEggScale = 1.2
        }
        
        // Speed up emoji changes
        emojiAnimator.activateEasterEgg()
        
        // Notify parent view to increase particle rain
        delegate?.activateEasterEgg()
        
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring()) {
                easterEggRotation = 0
                easterEggScale = 1.0
            }
            
            // Return to normal emoji change speed after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                emojiAnimator.deactivateEasterEgg()
            }
        }
    }
}

// Preview
struct OnboardingSlideView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlideView(slide: OnboardingSlide.slides[0])
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 