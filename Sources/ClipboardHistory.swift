import SwiftUI

final class ClipboardHistory: ObservableObject {
    @Published var items: [ClipboardItem] = []
    private let storage = ClipboardStorage()

    private var maxItems: Int {
        SettingsManager.shared.maxHistoryItems
    }

    init() {
        items = storage.load().sorted { $0.timestamp > $1.timestamp }
    }

    func add(_ type: ClipboardItemType) {
        let newItem = ClipboardItem(id: UUID(), type: type, timestamp: Date())

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.deduplicate(newItem)
            self.items.insert(newItem, at: 0)

            if self.items.count > self.maxItems {
                self.items = Array(self.items.prefix(self.maxItems))
            }

            self.storage.save(self.items)
        }
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        storage.save(items)
    }

    func clearAll() {
        items.removeAll()
        storage.save(items)
    }

    private func deduplicate(_ newItem: ClipboardItem) {
        switch newItem.type {
        case .text(let newText):
            items.removeAll { item in
                if case .text(let existingText) = item.type {
                    return existingText == newText
                }
                return false
            }
        case .rtf(let newData):
            items.removeAll { item in
                if case .rtf(let existingData) = item.type {
                    return existingData == newData
                }
                return false
            }
        case .html(let newHtml):
            items.removeAll { item in
                if case .html(let existingHtml) = item.type {
                    return existingHtml == newHtml
                }
                return false
            }
        case .fileURLs(let newUrls):
            items.removeAll { item in
                if case .fileURLs(let existingUrls) = item.type {
                    return existingUrls == newUrls
                }
                return false
            }
        case .image:
            break
        }
    }

    func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            pasteboard.setData(data, forType: .png)
        case .rtf(let data):
            pasteboard.setData(data, forType: .rtf)
            if let text = NSAttributedString(rtf: data, documentAttributes: nil)?.string {
                pasteboard.setString(text, forType: .string)
            }
        case .html(let html):
            pasteboard.setString(html, forType: .html)
            let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            pasteboard.setString(stripped, forType: .string)
        case .fileURLs(let urls):
            let string = urls.map { $0.path }.joined(separator: "\n")
            pasteboard.setString(string, forType: .string)
            let refURLs = urls as [NSURL]
            pasteboard.writeObjects(refURLs)
            pasteboard.setPropertyList(urls.map { $0.path }, forType: .fileURL)
        }
    }
}
