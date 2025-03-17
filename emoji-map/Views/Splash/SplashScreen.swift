//
//  SplashScreen.swift
//  emoji-map
//
//  Created by Enrique on 3/7/25.
//

import SwiftUI

struct SplashScreen: View {
    // Animation states
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var finishedAnimation = false
    
    // Static emoji properties
    private let staticEmojis: [(emoji: String, x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat)]
    
    // Completion handler
    var onFinished: () -> Void
    
    // Food emojis from the app
    private let foodEmojis = ["🍕", "🍔", "🌮", "🍣", "🍜", "🍦", "🍷", "🍺", "☕️", "🥗", "🍲", "🥪"]
    
    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        
        // Create static emojis with random positions and rotations
        var emojis: [(emoji: String, x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat)] = []
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for _ in 0..<20 {
            let emoji = foodEmojis.randomElement() ?? "🍕"
            let x = CGFloat.random(in: 0...screenWidth)
            let y = CGFloat.random(in: 0...screenHeight)
            let rotation = Double.random(in: 0...360)
            let scale = CGFloat.random(in: 0.5...1.5)
            
            emojis.append((emoji: emoji, x: x, y: y, rotation: rotation, scale: scale))
        }
        
        self.staticEmojis = emojis
    }
    
    var body: some View {
        ZStack {
            // Solid background color to ensure complete coverage
            Color.blue.opacity(0.8)
                .ignoresSafeArea()
            
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Static emoji decorations
            ForEach(0..<staticEmojis.count, id: \.self) { index in
                Text(staticEmojis[index].emoji)
                    .font(.system(size: 30 * staticEmojis[index].scale))
                    .position(x: staticEmojis[index].x, y: staticEmojis[index].y)
                    .rotationEffect(.degrees(staticEmojis[index].rotation))
            }
            
            VStack(spacing: 20) {
                // App logo
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .opacity(showLogo ? 1 : 0)
                    .scaleEffect(showLogo ? 1 : 0.5)
                
                // App title
                Text("Emoji Map")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                
                // App tagline
                Text("Smooth Brain? Smooth Map")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 15)
            }
            .padding()
        }
        .onAppear {
            // Start animations
            startAnimations()
            
            // Set a timer to finish the splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
        .zIndex(finishedAnimation ? -1 : 100) // Ensure splash screen is on top until animation finishes
        .transition(.opacity) // Smooth transition when disappearing
    }
    
    private func startAnimations() {
        // Sequence the animations with explicit animations
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            showLogo = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.7)) {
                showTitle = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.7)) {
                showTagline = true
            }
        }
    }
}

// Extension to use SplashScreen as a full-screen cover
extension View {
    func splashScreen(isPresented: Binding<Bool>, onDismiss: @escaping () -> Void) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                SplashScreen(onFinished: {
                    isPresented.wrappedValue = false
                    onDismiss()
                })
                .transition(.opacity)
            }
        }
    }
}

struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen {
            // No logging in preview
        }
    }
} 
