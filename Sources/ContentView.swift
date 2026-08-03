import SwiftUI
import AppKit

final class HotkeyRecorderState: ObservableObject {
    @Published var isRecording = false
    @Published var display = ""

    private var monitor: Any?

    init() {
        display = SettingsManager.shared.hotkeyDisplayString
    }

    func startRecording() {
        if isRecording { return }
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = true
        display = "按下组合键..."
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty else {
                self.stopRecording()
                return nil
            }
            let carbonMods = SettingsManager.shared.carbonModifiers(from: mods)
            SettingsManager.shared.hotkeyKeyCode = Int(event.keyCode)
            SettingsManager.shared.hotkeyModifiers = carbonMods
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        display = SettingsManager.shared.hotkeyDisplayString
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

struct ContentView: View {
    @ObservedObject var history: ClipboardHistory
    let onSelect: (ClipboardItem) -> Void
    let onSettingsChanged: () -> Void

    @State private var searchText = ""
    @State private var showSettings = false
    @StateObject private var hotkeyRecorder = HotkeyRecorderState()

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty { return history.items }
        let lower = searchText.lowercased()
        return history.items.filter {
            $0.type.searchText.contains(lower)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarBar

            Divider()

            if showSettings {
                settingsPanel
            } else if history.items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .frame(width: 320, height: 420)
        
    }

    // MARK: - Toolbar

    private var toolbarBar: some View {
        HStack(spacing: 6) {
            if showSettings {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                Text("设置")
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("搜索历史...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }

            Spacer()

            if !showSettings, !history.items.isEmpty {
                Button(action: {
                    history.clearAll()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("清空全部历史")
            }

            Button(action: { showSettings.toggle() }) {
                Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("剪贴板为空")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("Cmd+C 复制 · Cmd+Shift+V 打开")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredItems.isEmpty {
                    Text("无匹配结果")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(filteredItems) { item in
                        ItemRow(item: item, onSelect: { onSelect(item) }, onDelete: { history.remove(item) })
                        Divider().padding(.leading, 12)
                    }
                }

                Text("\(history.items.count) 条记录")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection(title: "历史记录数量", detail: "\(SettingsManager.shared.maxHistoryItems) 条") {
                    VStack(spacing: 4) {
                        Slider(value: Binding<Double>(
                            get: { Double(SettingsManager.shared.maxHistoryItems) },
                            set: {
                                SettingsManager.shared.maxHistoryItems = Int($0)
                                trimHistory()
                                onSettingsChanged()
                            }
                        ), in: 10...200, step: 10)
                        HStack {
                            Text("10").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                            Text("200").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }

                settingsSection(title: "轮询间隔", detail: String(format: "%.1f 秒", SettingsManager.shared.pollInterval)) {
                    VStack(spacing: 4) {
                        Slider(value: Binding<Double>(
                            get: { SettingsManager.shared.pollInterval },
                            set: {
                                SettingsManager.shared.pollInterval = $0
                                onSettingsChanged()
                            }
                        ), in: 0.3...3.0, step: 0.1)
                        HStack {
                            Text("0.3s").font(.system(size: 10)).foregroundColor(.secondary)
                            Spacer()
                            Text("3.0s").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }

                settingsSection(title: "全局快捷键", detail: hotkeyRecorder.display) {
                    hotkeyRecorderView
                }

                Text("修改设置后即时生效")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
        }
    }

    private var hotkeyRecorderView: some View {
        HStack {
            Text(hotkeyRecorder.display)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hotkeyRecorder.isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(hotkeyRecorder.isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )

            Button(hotkeyRecorder.isRecording ? "取消" : "修改") {
                if hotkeyRecorder.isRecording {
                    hotkeyRecorder.stopRecording()
                } else {
                    hotkeyRecorder.startRecording()
                }
            }
            .font(.system(size: 11))
        }
    }

    private func settingsSection<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            content()
        }
    }

    // MARK: - Helpers

    private func trimHistory() {
        let max = SettingsManager.shared.maxHistoryItems
        if history.items.count > max {
            history.items = Array(history.items.prefix(max))
        }
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: ClipboardItem
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            typeIcon
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .center)

            contentView
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .onTapGesture { onSelect() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .image(let data):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 60)
                    .cornerRadius(4)
            }
        case .rtf(let data):
            if let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
                Text(AttributedString(attributed))
                    .lineLimit(3)
                    .font(.system(size: 13))
            }
        case .text, .html, .fileURLs:
            Text(item.type.previewText)
                .lineLimit(3)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var typeIcon: some View {
        Group {
            switch item.type {
            case .text: Image(systemName: "text.alignleft")
            case .image: Image(systemName: "photo")
            case .rtf: Image(systemName: "doc.richtext")
            case .html: Image(systemName: "chevron.left.forwardslash.chevron.right")
            case .fileURLs: Image(systemName: "doc.on.doc")
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }
}
