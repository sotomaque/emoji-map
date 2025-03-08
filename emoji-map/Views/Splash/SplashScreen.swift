//
//  SplashScreen.swift
//  emoji-map
//
//  Created by Enrique on 3/7/25.
//

import SwiftUI
import QuartzCore

struct SplashScreen: View {
    // Animation states
    @State private var isAnimating = false
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var showEmojis = false
    @State private var finishedAnimation = false
    
    // Emoji animation properties
    @State private var emojis: [(emoji: String, position: CGPoint, scale: CGFloat, rotation: Double, opacity: Double)] = []
    
    // Completion handler
    var onFinished: () -> Void
    
    // Food emojis from the app
    private let foodEmojis = ["🍕", "🍔", "🌮", "🍣", "🍜", "🍦", "🍷", "🍺", "☕️", "🥗", "🍲", "🥪"]
    
    // Screen dimensions
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Emoji particles
            ForEach(0..<emojis.count, id: \.self) { index in
                Text(emojis[index].emoji)
                    .font(.system(size: 30 * emojis[index].scale))
                    .position(emojis[index].position)
                    .rotationEffect(.degrees(emojis[index].rotation))
                    .opacity(emojis[index].opacity)
            }
            
            VStack(spacing: 20) {
                // App logo
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .opacity(showLogo ? 1 : 0)
                    .scaleEffect(showLogo ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showLogo)
                
                // App title
                Text("Emoji Map")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.7).delay(0.3), value: showTitle)
                
                // App tagline
                Text("Discover places with emojis")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 15)
                    .animation(.easeOut(duration: 0.7).delay(0.5), value: showTagline)
            }
            .padding()
        }
        .onAppear {
            // Start animations
            startAnimations()
            
            // Create emoji particles
            createEmojiParticles()
            
            // Start pre-fetching places data while the splash screen is showing
            MainActor.assumeIsolated {
                ServiceContainer.shared.preFetchPlaces()
            }
            
            // Set a timer to finish the splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    finishedAnimation = true
                }
                
                // Call the completion handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onFinished()
                }
            }
        }
        .opacity(finishedAnimation ? 0 : 1)
    }
    
    private func startAnimations() {
        // Start gradient animation
        isAnimating = true
        
        // Sequence the animations
        withAnimation(.easeOut(duration: 0.5)) {
            showLogo = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showTitle = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showTagline = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation {
                showEmojis = true
            }
        }
    }
    
    private func createEmojiParticles() {
        // Create initial emoji particles
        for _ in 0..<15 {
            let randomX = CGFloat.random(in: 0...screenWidth)
            let randomY = CGFloat.random(in: 0...screenHeight)
            let randomEmoji = foodEmojis.randomElement() ?? "🍕"
            let randomScale = CGFloat.random(in: 0.5...1.5)
            let randomRotation = Double.random(in: 0...360)
            let randomOpacity = Double.random(in: 0.5...1.0)
            
            let particle = (
                emoji: randomEmoji,
                position: CGPoint(x: randomX, y: randomY),
                scale: randomScale,
                rotation: randomRotation,
                opacity: randomOpacity
            )
            
            emojis.append(particle)
        }
        
        // Animate the emojis
        animateEmojis()
    }
    
    private func animateEmojis() {
        guard showEmojis else { return }
        
        // Create a timer to update emoji positions
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in 0..<emojis.count {
                var emoji = emojis[i]
                
                // Update position with a floating effect
                emoji.position.y -= CGFloat.random(in: 0.5...2.0)
                emoji.position.x += CGFloat.random(in: -1.0...1.0)
                
                // Update rotation
                emoji.rotation += Double.random(in: -2...2)
                
                // Remove emojis that go off screen and add new ones
                if emoji.position.y < -50 {
                    let randomX = CGFloat.random(in: 0...screenWidth)
                    emoji.position = CGPoint(x: randomX, y: screenHeight + 50)
                }
                
                emojis[i] = emoji
            }
        }
        
        // Invalidate the timer when the animation is finished
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            timer.invalidate()
        }
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen {
            print("Splash screen finished")
        }
    }
} 
