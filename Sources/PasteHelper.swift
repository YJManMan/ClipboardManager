import AppKit

enum PasteHelper {
    static func paste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let vKey: CGKeyCode = 9
        let mask: CGEventFlags = .maskCommand

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return
        }

        keyDown.flags = mask
        keyUp.flags = mask

        keyDown.post(tap: .cghidEventTap)
        usleep(20000)
        keyUp.post(tap: .cghidEventTap)
    }
}
