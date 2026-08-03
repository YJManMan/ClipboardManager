import Carbon
import AppKit

final class HotkeyManager {
    var onHotkey: (() -> Void)?
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var handlerInstalled = false
    fileprivate static var instance: HotkeyManager?

    func register() {
        let keyCode = SettingsManager.shared.hotkeyKeyCode
        let modifiers = SettingsManager.shared.hotkeyCarbonModifiers
        registerInternal(keyCode: keyCode, modifiers: modifiers)
    }

    func reregister() {
        unregister()
        register()
    }

    private func registerInternal(keyCode: Int, modifiers: UInt32) {
        Self.instance = self

        if !handlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                hotkeyCallback,
                1,
                &eventType,
                nil,
                &handlerRef
            )
            handlerInstalled = true
        }

        let hotkeyID = EventHotKeyID(signature: 0x434D4752, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }
}

private func hotkeyCallback(
    _ handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ data: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        HotkeyManager.instance?.onHotkey?()
    }
    return noErr
}
