import SwiftUI
import UIKit

/// System haptics that respect the in-app Haptics switch.
struct HapticsClient {
    var isEnabled: Bool = true

    func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func reelStop() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
    }
}

private struct HapticsKey: EnvironmentKey {
    static let defaultValue = HapticsClient()
}

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SafeAreaKey: EnvironmentKey {
    static let defaultValue = EdgeInsets(top: Metrics.mockupSafeTop, leading: 0, bottom: Metrics.mockupSafeBottom, trailing: 0)
}

extension EnvironmentValues {
    var haptics: HapticsClient {
        get { self[HapticsKey.self] }
        set { self[HapticsKey.self] = newValue }
    }

    /// System Reduce Motion OR the in-app switch.
    var lureReduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }

    /// Window safe-area insets (screens draw edge-to-edge and position content themselves).
    var windowSafeArea: EdgeInsets {
        get { self[SafeAreaKey.self] }
        set { self[SafeAreaKey.self] = newValue }
    }
}

enum Accessibility {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
