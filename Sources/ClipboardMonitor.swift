import AppKit

final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private weak var history: ClipboardHistory?

    private var pollInterval: TimeInterval {
        SettingsManager.shared.pollInterval
    }

    init(history: ClipboardHistory) {
        self.history = history
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func restartTimer() {
        start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if detectAndAdd(pasteboard) { return }
    }

    private func detectAndAdd(_ pasteboard: NSPasteboard) -> Bool {
        if let urls = detectFileURLs(pasteboard) {
            history?.add(.fileURLs(urls))
            return true
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            history?.add(.rtf(rtfData))
            return true
        }

        if let html = pasteboard.string(forType: .html), !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            history?.add(.html(html))
            return true
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            history?.add(.text(text))
            return true
        }

        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
            history?.add(.image(jpeg))
            return true
        }

        return false
    }

    private func detectFileURLs(_ pasteboard: NSPasteboard) -> [URL]? {
        guard let items = pasteboard.pasteboardItems else { return nil }

        var allURLs: [URL] = []
        for item in items {
            guard let urlString = item.string(forType: .fileURL),
                  let url = URL(string: urlString) else { continue }
            allURLs.append(url)
        }
        return allURLs.isEmpty ? nil : allURLs
    }
}
