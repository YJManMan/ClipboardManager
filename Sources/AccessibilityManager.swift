import AppKit

final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published private(set) var isTrusted: Bool

    private init() {
        isTrusted = AXIsProcessTrusted()
    }

    func checkAndRequest() {
        isTrusted = AXIsProcessTrusted()
        let hasPrompted = UserDefaults.standard.bool(forKey: "AccessibilityPrompted")
        if !isTrusted, !hasPrompted {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            isTrusted = AXIsProcessTrustedWithOptions(options)
            UserDefaults.standard.set(true, forKey: "AccessibilityPrompted")
        }
    }

    func refreshStatus() {
        isTrusted = AXIsProcessTrusted()
    }
}
