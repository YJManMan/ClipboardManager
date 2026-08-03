import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var contextMenu: NSMenu!
    private var launchItem: NSMenuItem?
    private let history = ClipboardHistory()
    private let monitor: ClipboardMonitor
    private let hotkey = HotkeyManager()
    private var accessibilityRefreshTimer: Timer?

    override init() {
        monitor = ClipboardMonitor(history: history)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AccessibilityManager.shared.checkAndRequest()

        setupStatusItem()
        setupPopover()

        monitor.start()
        hotkey.onHotkey = { [weak self] in
            self?.togglePopover()
        }
        hotkey.register()

        startAccessibilityPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotkey.unregister()
        accessibilityRefreshTimer?.invalidate()
        contextMenu = nil
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "ClipboardManager"
            )
            button.action = #selector(handleStatusBarClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusBarClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        if contextMenu == nil {
            buildContextMenu()
        }
        if let button = statusItem.button {
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    private func buildContextMenu() {
        contextMenu = NSMenu()
        contextMenu.delegate = self
        contextMenu.autoenablesItems = false

        let openItem = NSMenuItem(title: "打开剪贴板历史", action: #selector(togglePopover), keyEquivalent: "")
        openItem.target = self
        contextMenu.addItem(openItem)

        contextMenu.addItem(.separator())

        let launch = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launch.target = self
        launchItem = launch
        contextMenu.addItem(launch)

        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 ClipboardManager", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let manager = LaunchAtLoginManager.shared
        if manager.isEnabled {
            do {
                try manager.disable()
            } catch {
                showErrorAlert(title: "关闭失败", message: "无法关闭开机自启动：\(error.localizedDescription)")
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "确认开启开机自启动？"
            alert.informativeText = "ClipboardManager 将在你登录 macOS 后自动启动。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "开启")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            do {
                try manager.enable()
            } catch {
                showErrorAlert(
                    title: "开启失败",
                    message: "无法开启开机自启动：\(error.localizedDescription)。\n\n提示：请先通过 package.sh 安装到 /Applications 目录后，该功能才能生效。"
                )
            }
        }
        refreshLaunchItem()
    }

    @objc private func quitApp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "确认退出 ClipboardManager？"
        alert.informativeText = "退出后剪贴板历史将保留，但不再自动记录新的复制内容。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        NSApp.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLaunchItem()
    }

    private func refreshLaunchItem() {
        launchItem?.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient

        let contentView = ContentView(
            history: history,
            onSelect: { [weak self] item in
                self?.selectAndPaste(item)
            },
            onSettingsChanged: { [weak self] in
                self?.applySettingsChanges()
            }
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.close()
        } else if let button = statusItem.button {
            AccessibilityManager.shared.refreshStatus()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func selectAndPaste(_ item: ClipboardItem) {
        history.writeToPasteboard(item)
        popover.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PasteHelper.paste()
        }
    }

    private func applySettingsChanges() {
        monitor.restartTimer()
        hotkey.reregister()
    }

    private func startAccessibilityPolling() {
        accessibilityRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AccessibilityManager.shared.refreshStatus()
        }
    }
}
