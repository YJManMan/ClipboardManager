import Foundation

final class ClipboardStorage {
    private let key = "com.clipboardmanager.history"

    func save(_ items: [ClipboardItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> [ClipboardItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }
}
