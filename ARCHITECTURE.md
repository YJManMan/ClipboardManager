# ClipboardManager 架构文档

## 项目概述

ClipboardManager 是一个纯 Swift 编写的 macOS 菜单栏剪贴板历史管理工具。它能自动记录用户复制的文本、图片、RTF、HTML 及文件路径，并提供快速搜索和回贴能力。

---

## 技术栈

| 层面 | 技术 | 说明 |
|---|---|---|
| 语言 | Swift 5 | — |
| UI 框架 | SwiftUI + AppKit | SwiftUI 渲染界面，AppKit 管理 NSPopover / NSStatusItem |
| 剪贴板访问 | NSPasteboard | macOS 原生剪贴板 API |
| 全局快捷键 | Carbon Event Manager | `RegisterEventHotKey` + `InstallEventHandler` |
| 模拟粘贴 | Core Graphics Event | `CGEvent` 发送 Cmd+V 按键事件到前台应用 |
| 持久化 | UserDefaults + JSON | `Codable` 序列化，无外部数据库 |
| 开机自启 | SMAppService | macOS 13+ 原生 API |
| 权限检测 | Accessibility API | `AXIsProcessTrusted` 检测辅助功能权限 |
| 构建编译 | swiftc | 命令行直接编译，无 Xcode 依赖 |
| DMG 打包 | hdiutil | macOS 原生磁盘映像工具 |
| 项目配置 | XcodeGen | `project.yml` 可生成 `.xcodeproj` |

---

## 项目目录结构

```
ClipboardManager/
├── .gitignore
├── project.yml                    # XcodeGen 项目配置
├── build.sh                       # 编译脚本（swiftc）
├── install.sh                     # 安装到 /Applications
├── package.sh                     # 完整打包（编译 + 图标 + DMG）
├── Resources/
│   └── Info.plist                 # App Bundle 元数据
├── Sources/
│   ├── ClipboardManagerApp.swift  # @main 应用入口
│   ├── AppDelegate.swift          # 总控制器（状态栏/热键/粘贴流程）
│   ├── ContentView.swift          # SwiftUI 主界面
│   ├── ClipboardMonitor.swift     # 剪贴板轮询引擎
│   ├── ClipboardHistory.swift     # 历史记录管理（内存 + 回写）
│   ├── ClipboardItem.swift        # 数据模型
│   ├── ClipboardStorage.swift     # 持久化层
│   ├── HotkeyManager.swift        # 全局热键管理
│   ├── PasteHelper.swift          # 模拟 Cmd+V
│   ├── SettingsManager.swift      # 设置单例
│   ├── LaunchAtLoginManager.swift # 开机自启管理
│   └── AccessibilityManager.swift # 辅助功能权限
└── Scripts/
    └── generate_icon.swift        # 程序化生成 AppIcon.icns
```

---

## 核心架构设计

### 整体架构图

```
┌─────────────────────────────────────────────────┐
│                   NSStatusItem                    │
│                  (菜单栏图标)                      │
└─────────────────────┬───────────────────────────┘
                      │ 点击
                      ▼
┌─────────────────────────────────────────────────┐
│                   NSPopover                       │
│  ┌───────────────────────────────────────────┐  │
│  │           ContentView (SwiftUI)            │  │
│  │  ┌─────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │ 搜索栏   │ │ 历史列表  │ │  设置面板  │  │  │
│  │  └─────────┘ └──────────┘ └────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘

┌──────────────────┐   ┌──────────────────┐
│ ClipboardMonitor │   │  HotkeyManager    │
│ (Timer 轮询)     │   │ (Carbon 全局热键) │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         ▼                      ▼
┌──────────────────────────────────────┐
│          ClipboardHistory             │
│  (ObservableObject, 内存数组)         │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────┐   ┌──────────────────┐
│ ClipboardStorage  │   │  PasteHelper      │
│ (UserDefaults)    │   │  (CGEvent 模拟粘贴)│
└──────────────────┘   └──────────────────┘
```

### 模块职责

#### 1. `ClipboardManagerApp.swift` — 应用入口
- `@main` 入口点
- 通过 `@NSApplicationDelegateAdaptor` 桥接 `AppDelegate`
- 返回最小化 Scene（菜单栏应用无需窗口）

#### 2. `AppDelegate.swift` — 总控制器
- **状态栏**：创建 `NSStatusItem`，左键弹出 Popover，右键显示菜单
- **Popover**：320×420 尺寸，`.transient` 行为（点击外部自动关闭）
- **剪贴板监控**：持有 `ClipboardMonitor` 实例，随应用生命周期启停
- **热键触发**：持有 `HotkeyManager`，触发时调用 `togglePopover()`
- **粘贴流程**：选中条目 → 写回剪贴板 → 关闭 Popover → 0.1s 后 `PasteHelper.paste()`
- **权限轮询**：2 秒定时器检测 Accessibility 权限状态
- **开机自启**：通过 `LaunchAtLoginManager` 管理

#### 3. `ContentView.swift` — SwiftUI 界面
- **Accessibility 警告横幅**：权限未授予时显示
- **工具栏**：搜索字段 / 设置标题切换 + 清空按钮 + 设置按钮
- **设置面板**：历史数量滑块、轮询间隔滑块、全局快捷键录制器
- **空状态**：无历史记录时的占位提示
- **历史列表**：`LazyVStack` + `ForEach` 渲染过滤后的条目
- **ItemRow**：类别图标 + 内容预览（3 行截断）+ 相对时间戳 + hover 删除按钮

#### 4. `ClipboardMonitor.swift` — 剪贴板轮询
- 使用 `Timer` 定时检查 `NSPasteboard.general.changeCount`
- 检测到变化后按优先级读取类型：文件 URL → RTF → HTML → 文本 → 图片
- 图片转 JPEG（0.7 压缩率）存储
- 轮询间隔可配置，设置变更时自动重启定时器

#### 5. `ClipboardHistory.swift` — 历史管理
- `ObservableObject`，`@Published var items` 按时间倒序排列
- **去重**：新增条目与已有内容完全相同时，移除旧条目（图片不去重）
- **截断**：超过 `maxItems` 时移除最旧条目
- **回写**：`writeToPasteboard(_:)` 根据类型精确设置剪贴板
  - 文本 → `setString(.string)`
  - 图片 → `setData(.png)`
  - RTF → 同时写 RTF 数据 + 纯文本 fallback
  - HTML → 同时写 HTML + 纯文本 fallback
  - 文件 → 写纯文本路径 + NSURL 对象 + fileURL 属性列表

#### 6. `ClipboardItem.swift` — 数据模型
- `ClipboardItemType` 枚举：`.text` / `.image` / `.rtf` / `.html` / `.fileURLs`
- 自定义 `Codable` 实现（`type` + `value` 键结构）
- `ClipboardItem` 结构体：`id` (UUID) + `type` + `timestamp`
- 计算属性 `previewText` 和 `searchText` 供 UI 使用

#### 7. `ClipboardStorage.swift` — 持久化
- 存储键：`com.clipboardmanager.history`
- `JSONEncoder` / `JSONDecoder` 编解码 `[ClipboardItem]`
- 失败时返回空数组，不抛异常

#### 8. `HotkeyManager.swift` — 全局热键
- 使用 Carbon `RegisterEventHotKey` 注册系统级快捷键
- `InstallEventHandler` 监听 `kEventHotKeyPressed` 事件
- C 回调 `hotkeyCallback` 通过静态单例 `Self.instance` 桥接到 Swift
- 热键签名 `0x434D4752`（"CMGR" ASCII）防止冲突
- 支持动态重新注册（快捷键变更时）

#### 9. `PasteHelper.swift` — 模拟粘贴
- 创建 `CGEventSource(stateID: .hidSystemState)`
- 虚拟键码 9 = "V"，mask = `.maskCommand`
- 先 post `keyDown`，20ms 后 post `keyUp`
- 延迟确保前台应用完成剪贴板读取

#### 10. `SettingsManager.swift` — 设置管理
- 单例模式，`UserDefaults` 持久化
- 可配置项：
  - `maxHistoryItems`（10-200，默认 50）
  - `pollInterval`（0.3-3.0s，默认 0.5s）
  - `hotkeyKeyCode`（默认 9 = V 键）
  - `hotkeyModifiers`（Carbon 位掩码，默认 cmdKey | shiftKey）
- `hotkeyDisplayString` 生成人类可读快捷键（如 "⌘⇧V"）
- 内置 `keyCodeMap` 映射键码到显示名称（覆盖 A-Z、数字、功能键、方向键等）

#### 11. `LaunchAtLoginManager.swift` — 开机自启
- 使用 macOS 13+ `SMAppService.mainApp`
- 仅当 App 安装于 `/Applications` 时才能注册成功

#### 12. `AccessibilityManager.swift` — 权限检测
- `ObservableObject`，`@Published isTrusted`
- `AXIsProcessTrusted()` 检查权限
- `AXIsProcessTrustedWithOptions` 弹出系统授权对话框

---

## 数据流

```
用户复制内容
    │
    ▼
NSPasteboard 变化（changeCount++）
    │
    ▼
ClipboardMonitor 检测到变化
    │
    ▼
读取剪贴板类型 → 构造 ClipboardItem
    │
    ▼
ClipboardHistory.add() → 去重 → 截断 → ClipboardStorage.save()
    │
    ▼
ContentView 自动更新（@Published items）

─────────────────────────

用户点击条目 / 按热键
    │
    ▼
AppDelegate.selectAndPaste()
    │
    ├── ClipboardHistory.writeToPasteboard() → 恢复内容到剪贴板
    │
    └── PasteHelper.paste() → Cmd+V 模拟粘贴到前台应用
```

---

## 构建与分发

### build.sh
1. 创建 `.build/ClipboardManager.app/Contents/{MacOS,Resources}`
2. `swiftc` 编译 `Sources/*.swift`，链接 `AppKit`、`SwiftUI`、`Carbon`
3. 输出到 `.build/ClipboardManager.app/Contents/MacOS/ClipboardManager`
4. 复制 `Resources/Info.plist` 到 bundle

### package.sh
1. 执行 build（同 build.sh）
2. 运行 `Scripts/generate_icon.swift` 生成 `AppIcon.icns`
3. `hdiutil` 创建压缩 UDZO 格式 DMG

### install.sh
1. 终止已运行的 ClipboardManager 进程
2. 复制 `.build/ClipboardManager.app` → `/Applications/`
3. 启动已安装的应用

---

## 关键设计决策

### 为什么用轮询而非订阅通知？
NSPasteboard 的变更通知在沙盒/非沙盒应用中行为不一致，且仅在 App 为前台时可靠。Timer 轮询是最稳定且跨 macOS 版本兼容的方案。

### 为什么用 CGEvent 而非 AXUIElement 模拟粘贴？
`CGEvent` 模拟 Cmd+V 直接发送按键事件到系统事件流，比通过 Accessibility API 定位目标应用菜单栏再触发 "Paste" 更简洁可靠。但仍需 Accessibility 权限来确保事件能被注入。

### 为什么不用 Core Data / SQLite？
应用数据量小（最多 200 条记录，纯文本/缩略图），UserDefaults + JSON 足够简单高效，无需引入数据库依赖。

### 热键为什么用 Carbon API 而非 NSEvent？
`NSEvent.addGlobalMonitorForEvents` 需要在系统设置中授权且仍有限制。Carbon Event Manager 的 `RegisterEventHotKey` 是真正的系统级全局热键，响应最可靠。

### 为什么同时设置多种剪贴板类型？
回写剪贴板时同时设置数据本体和纯文本 fallback，确保不支持的应用程序仍能粘贴到内容（如 RTF 写入纯文本版本，HTML 写入 stripped text 版本）。

---

## Info.plist 关键配置

| 键 | 值 | 说明 |
|---|---|---|
| LSUIElement | true | 无 Dock 图标，纯菜单栏应用 |
| LSMinimumSystemVersion | 13.0 | 最低 macOS Ventura |
| NSPrincipalClass | NSApplication | AppKit 应用入口类 |

---

## 无外部依赖

本项目通过 `swiftc` 直接编译，全部使用 Apple 系统框架：

- **AppKit** — NSApplication, NSStatusItem, NSPopover, NSPasteboard
- **SwiftUI** — View, ObservableObject, @Published
- **Carbon** — RegisterEventHotKey, InstallEventHandler
- **CoreGraphics** — CGEvent, CGEventSource
- **ServiceManagement** — SMAppService
- **ApplicationServices** — AXIsProcessTrusted
- **Foundation** — UserDefaults, Timer, JSONEncoder, Codable
