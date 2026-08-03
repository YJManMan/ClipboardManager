import Foundation
import Carbon
import AppKit

final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    var maxHistoryItems: Int {
        get {
            let val = defaults.integer(forKey: Keys.maxHistory)
            return val > 0 ? val : 50
        }
        set { defaults.set(newValue, forKey: Keys.maxHistory) }
    }

    var pollInterval: Double {
        get {
            let val = defaults.double(forKey: Keys.pollInterval)
            return val > 0 ? val : 0.5
        }
        set { defaults.set(newValue, forKey: Keys.pollInterval) }
    }

    var hotkeyKeyCode: Int {
        get {
            let val = defaults.integer(forKey: Keys.hotkeyKeyCode)
            return val != 0 ? val : 9
        }
        set { defaults.set(newValue, forKey: Keys.hotkeyKeyCode) }
    }

    var hotkeyModifiers: Int {
        get {
            let val = defaults.integer(forKey: Keys.hotkeyModifiers)
            return val != 0 ? val : Int(cmdKey | shiftKey)
        }
        set { defaults.set(newValue, forKey: Keys.hotkeyModifiers) }
    }

    var hotkeyCarbonModifiers: UInt32 {
        UInt32(hotkeyModifiers)
    }

    var hotkeyDisplayString: String {
        Self.carbonKeyDisplay(keyCode: hotkeyKeyCode, carbonModifiers: hotkeyCarbonModifiers)
    }

    func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if nsFlags.contains(.command) { carbon |= Int(cmdKey) }
        if nsFlags.contains(.shift) { carbon |= Int(shiftKey) }
        if nsFlags.contains(.option) { carbon |= Int(optionKey) }
        if nsFlags.contains(.control) { carbon |= Int(controlKey) }
        return carbon
    }

    static func carbonKeyDisplay(keyCode: Int, carbonModifiers: UInt32) -> String {
        var result = ""
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "\u{2318}" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "\u{21E7}" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "\u{2325}" }
        if carbonModifiers & UInt32(controlKey) != 0 { result += "\u{2303}" }
        result += carbonKeyCodeChar(keyCode)
        return result
    }

    private static let keyCodeMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`",
        51: "Delete", 53: "Escape",
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
        123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        116: "PgUp", 121: "PgDn",
        115: "Home", 119: "End",
    ]

    private static func carbonKeyCodeChar(_ keyCode: Int) -> String {
        return keyCodeMap[keyCode] ?? "Key\(keyCode)"
    }

    private enum Keys {
        static let maxHistory = "maxHistoryItems"
        static let pollInterval = "pollInterval"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }
}
