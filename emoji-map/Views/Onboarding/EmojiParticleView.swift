import SwiftUI
import CoreMotion
import QuartzCore

struct EmojiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var emoji: String
    var scale: CGFloat
    var rotation: Double
    var opacity: Double
    var speed: CGFloat
    var horizontalMovement: CGFloat
}

class ParticleSystem: ObservableObject {
    @Published var particles: [EmojiParticle] = []
    private var displayLink: CADisplayLink?
    private var motionManager = CMMotionManager()
    private var motionX: Double = 0
    private var motionY: Double = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var particleCreationTimer: Timer?
    private var easterEggTimer: Timer?
    
    // Easter egg mode
    private var isEasterEggActive = false
    private var normalParticleLimit = 30
    private var easterEggParticleLimit = 100
    private var normalCreationInterval: TimeInterval = 0.5
    private var easterEggCreationInterval: TimeInterval = 0.1
    
    let foodEmojis = ["🍕", "🍔", "🌮", "🍣", "🍜", "🍦", "🍷", "🍺", "☕️", "🥗", "🍲", "🥪"]
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    init() {
        setupMotionUpdates()
    }
    
    deinit {
        stopSystem()
    }
    
    func startSystem() {
        // Create initial particles
        for _ in 0..<15 {
            createParticle()
        }
        
        // Set up display link for smooth animation
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common) // .common mode ensures it runs during scrolling and other interactions
        
        // Add new particles periodically
        startParticleCreationTimer()
    }
    
    func stopSystem() {
        displayLink?.invalidate()
        displayLink = nil
        particleCreationTimer?.invalidate()
        particleCreationTimer = nil
        easterEggTimer?.invalidate()
        easterEggTimer = nil
        motionManager.stopDeviceMotionUpdates()
        particles.removeAll()
    }
    
    func activateEasterEgg() {
        isEasterEggActive = true
        
        // Cancel existing timer
        particleCreationTimer?.invalidate()
        
        // Start faster particle creation
        startParticleCreationTimer()
        
        // Create a burst of particles immediately
        for _ in 0..<20 {
            createParticle()
        }
        
        // Set a timer to deactivate easter egg mode after 8 seconds
        easterEggTimer?.invalidate()
        easterEggTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.deactivateEasterEgg()
        }
    }
    
    func deactivateEasterEgg() {
        isEasterEggActive = false
        
        // Cancel existing timer
        particleCreationTimer?.invalidate()
        
        // Restart normal particle creation
        startParticleCreationTimer()
    }
    
    private func startParticleCreationTimer() {
        let interval = isEasterEggActive ? easterEggCreationInterval : normalCreationInterval
        let limit = isEasterEggActive ? easterEggParticleLimit : normalParticleLimit
        
        particleCreationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.particles.count < limit {
                self.createParticle()
            }
        }
    }
    
    private func setupMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion, error == nil else { return }
                
                // Get the device tilt values
                self.motionX = motion.gravity.x * 5 // Amplify the effect
                self.motionY = motion.gravity.y * 5
            }
        }
    }
    
    private func createParticle() {
        let randomX = CGFloat.random(in: 0...screenWidth)
        let randomY = CGFloat.random(in: -100...0)
        let randomEmoji = foodEmojis.randomElement() ?? "🍕"
        
        // Increase scale and speed during easter egg mode
        let scaleRange: ClosedRange<CGFloat> = isEasterEggActive ? 0.7...2.0 : 0.5...1.5
        let speedRange: ClosedRange<CGFloat> = isEasterEggActive ? 2...7 : 1...5
        
        let randomScale = CGFloat.random(in: scaleRange)
        let randomRotation = Double.random(in: 0...360)
        let randomOpacity = Double.random(in: 0.5...1.0)
        let randomSpeed = CGFloat.random(in: speedRange)
        let randomHorizontalMovement = CGFloat.random(in: -1...1)
        
        let particle = EmojiParticle(
            position: CGPoint(x: randomX, y: randomY),
            emoji: randomEmoji,
            scale: randomScale,
            rotation: randomRotation,
            opacity: randomOpacity,
            speed: randomSpeed,
            horizontalMovement: randomHorizontalMovement
        )
        
        particles.append(particle)
    }
    
    @objc private func update(displayLink: CADisplayLink) {
        // Calculate delta time for smooth animation regardless of frame rate
        let currentTime = displayLink.timestamp
        let deltaTime: CFTimeInterval
        
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        
        lastUpdateTime = currentTime
        
        // Update particles with delta time for smooth motion
        updateParticles(deltaTime: deltaTime)
    }
    
    private func updateParticles(deltaTime: CFTimeInterval) {
        // Use a speed multiplier based on delta time
        let speedMultiplier = CGFloat(deltaTime * 60) // Normalize to 60fps
        
        // Increase speed during easter egg mode
        let easterEggMultiplier: CGFloat = isEasterEggActive ? 1.5 : 1.0
        
        for i in (0..<particles.count).reversed() {
            // Update position
            var particle = particles[i]
            
            // Apply base movement with delta time for smooth motion
            particle.position.y += particle.speed * speedMultiplier * easterEggMultiplier
            
            // Apply motion-based movement
            particle.position.x += (particle.horizontalMovement + CGFloat(motionX * 2)) * speedMultiplier * easterEggMultiplier
            particle.position.y += CGFloat(motionY) * speedMultiplier * easterEggMultiplier
            
            // Update rotation with motion influence
            particle.rotation += (0.5 * particle.speed + Double(motionX + motionY)) * Double(speedMultiplier) * Double(easterEggMultiplier)
            
            // Remove particles that have gone off screen
            if particle.position.y > screenHeight + 50 || 
               particle.position.x < -50 || 
               particle.position.x > screenWidth + 50 {
                particles.remove(at: i)
                continue
            }
            
            // Update the particle
            particles[i] = particle
        }
    }
}

struct EmojiParticleView: View {
    @StateObject private var particleSystem = ParticleSystem()
    
    var body: some View {
        ZStack {
            ForEach(particleSystem.particles) { particle in
                Text(particle.emoji)
                    .font(.system(size: 30 * particle.scale))
                    .position(particle.position)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            particleSystem.startSystem()
            
            // Listen for easter egg activation
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ActivateEasterEgg"),
                object: nil,
                queue: .main
            ) { _ in
                activateEasterEgg()
            }
        }
        .onDisappear {
            particleSystem.stopSystem()
            
            // Remove observer
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("ActivateEasterEgg"),
                object: nil
            )
        }
        .allowsHitTesting(false) // This prevents the view from intercepting touch events
    }
    
    // Method to activate easter egg mode
    func activateEasterEgg() {
        particleSystem.activateEasterEgg()
    }
}

struct EmojiParticleView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiParticleView()
            .background(Color.black.opacity(0.1))
    }
} 