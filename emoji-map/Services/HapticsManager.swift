import UIKit

/// A centralized manager for haptic feedback throughout the app
class HapticsManager {
    // MARK: - Singleton
    static let shared = HapticsManager()
    
    // MARK: - Properties
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // Prevent multiple haptics in quick succession
    private var lastHapticTime: Date = Date.distantPast
    private let minimumHapticInterval: TimeInterval = 0.1
    
    // MARK: - Initialization
    private init() {
        // Pre-prepare generators for faster response
        prepareGenerators()
    }
    
    // MARK: - Public Methods
    
    /// Prepares all haptic generators for faster response
    func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    /// Triggers a light impact feedback
    /// - Parameter intensity: The intensity of the feedback (0.0 to 1.0)
    func lightImpact(intensity: CGFloat = 1.0) {
        guard shouldTriggerHaptic() else { return }
        lightGenerator.impactOccurred(intensity: intensity)
        updateLastHapticTime()
    }
    
    /// Triggers a medium impact feedback
    /// - Parameter intensity: The intensity of the feedback (0.0 to 1.0)
    func mediumImpact(intensity: CGFloat = 1.0) {
        guard shouldTriggerHaptic() else { return }
        mediumGenerator.impactOccurred(intensity: intensity)
        updateLastHapticTime()
    }
    
    /// Triggers a heavy impact feedback
    /// - Parameter intensity: The intensity of the feedback (0.0 to 1.0)
    func heavyImpact(intensity: CGFloat = 1.0) {
        guard shouldTriggerHaptic() else { return }
        heavyGenerator.impactOccurred(intensity: intensity)
        updateLastHapticTime()
    }
    
    /// Triggers a notification feedback
    /// - Parameter type: The type of notification feedback
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard shouldTriggerHaptic() else { return }
        notificationGenerator.notificationOccurred(type)
        updateLastHapticTime()
    }
    
    /// Triggers a selection feedback
    func selection() {
        guard shouldTriggerHaptic() else { return }
        selectionGenerator.selectionChanged()
        updateLastHapticTime()
    }
    
    /// Triggers an escalating sequence of haptic feedback
    /// - Parameter completion: Optional callback when the sequence completes
    func escalatingSequence(completion: (() -> Void)? = nil) {
        lightImpact(intensity: 0.6)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.mediumImpact(intensity: 0.7)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.mediumImpact(intensity: 0.9)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.heavyImpact(intensity: 1.0)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.notification(type: .success)
                        completion?()
                    }
                }
            }
        }
    }
    
    /// Triggers a success sequence of haptic feedback
    func successSequence() {
        mediumImpact(intensity: 0.8)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.notification(type: .success)
        }
    }
    
    /// Triggers an error sequence of haptic feedback
    func errorSequence() {
        mediumImpact(intensity: 0.7)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.notification(type: .error)
        }
    }
    
    // MARK: - Private Methods
    
    private func shouldTriggerHaptic() -> Bool {
        let now = Date()
        return now.timeIntervalSince(lastHapticTime) >= minimumHapticInterval
    }
    
    private func updateLastHapticTime() {
        lastHapticTime = Date()
    }
} 