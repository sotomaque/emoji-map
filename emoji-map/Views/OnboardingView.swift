import SwiftUI
import QuartzCore

class GradientAnimator: ObservableObject {
    @Published var animateGradient = false
    private var displayLink: CADisplayLink?
    
    func startAnimation() {
        // Start the gradient animation
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            animateGradient = true
        }
        
        // Use CADisplayLink to ensure animation continues during interaction
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func update(_ displayLink: CADisplayLink) {
        // This empty method keeps the run loop active during user interaction
    }
}

struct OnboardingView: View, OnboardingSlideDelegate {
    @ObservedObject var userPreferences: UserPreferences
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    // Animation states
    @State private var showParticles = false
    @StateObject private var gradientAnimator = GradientAnimator()
    @State private var animateButtons = false
    
    // Reference to control particle system
    @State private var easterEggActive = false
    
    // Flag to determine if this is shown from settings
    var isFromSettings: Bool = false
    
    private let slides = OnboardingSlide.slides
    
    var body: some View {
        ZStack {
            // Animated background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    slides[currentPage].accentColor.opacity(gradientAnimator.animateGradient ? 0.4 : 0.2),
                    slides[currentPage].accentColor.opacity(gradientAnimator.animateGradient ? 0.1 : 0.3)
                ]),
                startPoint: gradientAnimator.animateGradient ? .topLeading : .bottomTrailing,
                endPoint: gradientAnimator.animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: gradientAnimator.animateGradient)
            
            // Emoji particle system (food raining down)
            if showParticles {
                EmojiParticleView()
                    .zIndex(1) // Ensure particles appear above the background but below the content
                    .modifier(EasterEggModifier(isActive: easterEggActive))
            }
            
            VStack {
                HStack {
                    // Close button (only shown when opened from settings)
                    if isFromSettings {
                        Button(action: {
                            // Provide haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            // Dismiss the view
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                                .padding(.top, 20)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                    }
                    
                    Spacer()
                    
                    // Skip button
                    if currentPage < slides.count - 1 {
                        Button(action: {
                            // Provide haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            // Complete onboarding with success feedback
                            let successGenerator = UINotificationFeedbackGenerator()
                            successGenerator.notificationOccurred(.success)
                            
                            // Complete onboarding or dismiss if from settings
                            withAnimation(.spring()) {
                                if isFromSettings {
                                    dismiss()
                                } else {
                                    userPreferences.completeOnboarding()
                                }
                            }
                        }) {
                            Text("Skip")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                        .scaleEffect(animateButtons ? 1.0 : 0.8)
                        .opacity(animateButtons ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: animateButtons)
                    }
                }
                
                // Paging view for slides
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        OnboardingSlideView(slide: slides[index], delegate: self)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentPage) { _ in
                    // Provide haptic feedback on page change
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
                // Page indicators and buttons
                VStack(spacing: 30) {
                    // Page indicators
                    HStack(spacing: 10) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 10, height: 10)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    .padding(.bottom, 10)
                    .scaleEffect(animateButtons ? 1.0 : 0.8)
                    .opacity(animateButtons ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: animateButtons)
                    
                    // Navigation buttons
                    HStack {
                        // Back button
                        if currentPage > 0 {
                            Button(action: {
                                // Provide haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            }
                            .transition(.scale)
                        } else {
                            // Empty view to maintain layout
                            Spacer()
                                .frame(width: 100)
                        }
                        
                        Spacer()
                        
                        // Next/Get Started button
                        Button(action: {
                            // Provide haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            if currentPage < slides.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                // Final slide - complete onboarding with success feedback
                                let successGenerator = UINotificationFeedbackGenerator()
                                successGenerator.notificationOccurred(.success)
                                
                                // Complete onboarding or dismiss if from settings
                                withAnimation(.spring()) {
                                    if isFromSettings {
                                        dismiss()
                                    } else {
                                        userPreferences.completeOnboarding()
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Text(currentPage < slides.count - 1 ? "Next" : (isFromSettings ? "Close" : "Get Started"))
                                Image(systemName: currentPage < slides.count - 1 ? "chevron.right" : (isFromSettings ? "xmark" : "chevron.right"))
                            }
                            .fontWeight(.medium)
                            .foregroundColor(slides[currentPage].accentColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .scaleEffect(animateButtons ? 1.0 : 0.8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: animateButtons)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .zIndex(2) // Ensure content is above particles
        }
        .onAppear {
            // Start animations with slight delays
            gradientAnimator.startAnimation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showParticles = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    animateButtons = true
                }
            }
        }
        .onDisappear {
            gradientAnimator.stopAnimation()
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset = gesture.translation.width
                }
                .onEnded { gesture in
                    let threshold: CGFloat = 50
                    if dragOffset > threshold && currentPage > 0 {
                        // Provide haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        withAnimation {
                            currentPage -= 1
                        }
                    } else if dragOffset < -threshold && currentPage < slides.count - 1 {
                        // Provide haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    dragOffset = 0
                }
        )
    }
    
    // MARK: - OnboardingSlideDelegate
    
    func activateEasterEgg() {
        // Activate easter egg mode
        easterEggActive = true
        
        // Show a fun message
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            easterEggActive = false
        }
    }
}

// Modifier to activate easter egg in EmojiParticleView
struct EasterEggModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // If already active when appearing, activate the easter egg
                if isActive {
                    NotificationCenter.default.post(name: NSNotification.Name("ActivateEasterEgg"), object: nil)
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    // Find the EmojiParticleView and activate easter egg
                    NotificationCenter.default.post(name: NSNotification.Name("ActivateEasterEgg"), object: nil)
                }
            }
    }
}

// Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(userPreferences: UserPreferences())
    }
} 