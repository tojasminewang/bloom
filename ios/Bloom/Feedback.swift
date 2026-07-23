// Feedback.swift — haptics now; Sfx is the WebAudio synth port (filled in by Sounds.swift).
import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func levelUp() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
    }
    static func warn() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
