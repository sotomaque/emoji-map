//
//  PlaceAnnotation.swift
//  emoji-map
//
//  Created by Enrique on 3/14/25.
//

import SwiftUI

struct PlaceAnnotation: View {
    let emoji: String
    let isFavorite: Bool
    let isLoading: Bool
    let onTap: () -> Void
    
    // Animation states
    @State private var animateIn = false
    @State private var bounce = false
    @State private var rotation = Double.random(in: -20...20)
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
               
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 40, height: 40)
                    .background(
                        isFavorite ?
                            Circle()
                                .fill(Color.yellow.opacity(0.3))
                                .frame(width: 44, height: 44)
                                .scaleEffect(animateIn ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animateIn)
                        : nil
                    )
                    .scaleEffect(bounce ? 1.1 : 1.0)
                    .rotationEffect(.degrees(animateIn ? 0 : rotation))
                    .animation(
                        bounce ? 
                            Animation.spring(response: 0.3, dampingFraction: 0.6).repeatCount(1, autoreverses: true) : 
                            .default,
                        value: bounce
                    )
            }
            .offset(y: animateIn ? 0 : -20)
            .scaleEffect(isLoading ? 0.8 : (animateIn ? 1.0 : 0.01))
            .opacity(isLoading ? 0.6 : (animateIn ? 1.0 : 0.0))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateIn)
            .animation(.easeInOut(duration: 0.3), value: isLoading)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Trigger entrance animation with a slight delay for staggered effect
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.4)) {
                withAnimation {
                    animateIn = true
                }
                
                // Add a bounce effect after the entrance animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    bounce = true
                    
                    // Reset bounce after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        bounce = false
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PlaceAnnotation(emoji: "🍕", isFavorite: true, isLoading: false) {}
        PlaceAnnotation(emoji: "🍺", isFavorite: false, isLoading: false) {}
        PlaceAnnotation(emoji: "🍣", isFavorite: true, isLoading: true) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
} 