import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let accentColor: Color
    let emoji: String
}

// Sample onboarding slides
extension OnboardingSlide {
    static let slides: [OnboardingSlide] = [
        OnboardingSlide(
            title: "Welcome to Emoji Map",
            description: "Discover restaurants and bars around you with a fun, emoji-based interface.",
            imageName: "map.fill",
            accentColor: .blue,
            emoji: "🗺️"
        ),
        OnboardingSlide(
            title: "Find What You Crave",
            description: "Tap on emoji categories to filter places based on what you're in the mood for.",
            imageName: "fork.knife",
            accentColor: .orange,
            emoji: "🍕"
        ),
        OnboardingSlide(
            title: "Save Your Favorites",
            description: "Keep track of places you love by adding them to your favorites list.",
            imageName: "star.fill",
            accentColor: .yellow,
            emoji: "⭐️"
        ),
        OnboardingSlide(
            title: "Feeling Lucky?",
            description: "Use the random button to discover new places that match your filters.",
            imageName: "dice.fill",
            accentColor: .purple,
            emoji: "🎲"
        ),
        OnboardingSlide(
            title: "Ready to Explore?",
            description: "Let's find some amazing places around you!",
            imageName: "location.fill",
            accentColor: .green,
            emoji: "📍"
        )
    ]
} 