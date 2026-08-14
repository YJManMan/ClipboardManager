# ClipboardManager

一款纯 Swift 编写的 macOS 菜单栏剪贴板历史管理工具。它会自动记录你复制的文本、图片、RTF、HTML 和文件路径，并支持快速搜索与一键回贴。

- 无外部依赖，仅使用 Apple 系统框架
- 菜单栏运行，无 Dock 图标、无窗口干扰
- 默认全局快捷键 `⌘⇧V` 唤醒

> **提示**：当前尚未提供 DMG 安装包，请通过下方源码编译方式安装使用；后续版本会逐步提供官方 DMG 安装包。

---

## 功能特性

- 自动监控剪贴板，记录文本 / 图片 / RTF / HTML / 文件路径
- 菜单栏 Popover 展示历史，支持搜索与删除
- 全局快捷键（默认 `⌘⇧V`）随时呼出
- 点击条目自动写回剪贴板并模拟 `⌘V` 粘贴到前台应用
- 可配置历史数量上限（10–200）、轮询间隔（0.3–3.0s）、自定义快捷键
- 右键菜单支持开机自启动与退出确认

---

## 系统要求

- **macOS 13.0 (Ventura)** 及以上
- 需要 **Xcode 或 Xcode Command Line Tools**（用于 `swiftc` 编译）

> 安装 Command Line Tools：终端执行 `xcode-select --install`

---

## 从 GitHub 下载并安装

仓库地址：<https://github.com/YJManMan/ClipboardManager>

### 1. 下载源码

任选其一：

```bash
# 使用 git clone
git clone https://github.com/YJManMan/ClipboardManager.git
cd ClipboardManager
```

或直接点击仓库页面的 **Code → Download ZIP**，解压后进入目录。

> 提示：通过 ZIP 下载时脚本的可执行权限会丢失，请先执行 `chmod +x build.sh install.sh package.sh`，或用 `bash build.sh` 等方式运行。

### 2. 编译

完整打包（编译 + 生成图标 + 制作 DMG）：

```bash
./package.sh
# 产物：.build/ClipboardManager.app 和 .build/ClipboardManager.dmg
```

仅快速编译（无图标，适合开发调试）：

```bash
./build.sh
# 产物：.build/ClipboardManager.app
```

### 3. 安装到 /Applications

```bash
./install.sh
```

该脚本会自动关闭正在运行的实例、将 `.build/ClipboardManager.app` 复制到 `/Applications/` 并启动。

也可以手动安装：把 `.build/ClipboardManager.app` 拖入 **Applications** 文件夹后双击运行。

> 注意：开机自启动功能依赖应用位于 `/Applications` 目录，请通过 `install.sh` 或手动拖入安装后再开启。

---

## 首次启动授权

为了自动向其他应用模拟粘贴，需要授予「辅助功能」权限：

1. 首次启动时若弹出系统授权对话框，点击 **打开系统设置**
2. 进入 **系统设置 → 隐私与安全性 → 辅助功能**
3. 找到并勾选 **ClipboardManager**
4. 若列表中没有，点击 `+` 手动添加 `/Applications/ClipboardManager.app`

授予后无需重启，应用会自动检测并生效。

---

## 使用方法

1. **记录**：正常复制任何内容，应用会在后台自动记录（默认保留最近 50 条）
2. **查看**：点击菜单栏图标，或按 `⌘⇧V` 呼出历史面板
3. **回贴**：点击任意条目，自动写入剪贴板并粘贴到当前前台应用
4. **搜索**：在面板顶部输入关键词，实时过滤历史
5. **删除**：鼠标悬停条目，点击出现的删除按钮；或点击工具栏的「清空」一键清空
6. **设置**：点击面板右上角齿轮，可调整历史数量、轮询间隔与全局快捷键
7. **右键菜单**：右键菜单栏图标，可开关「开机自启动」或「退出」

---

## 卸载

1. 右键菜单栏图标 → **退出 ClipboardManager**
2. 删除应用：

```bash
rm -rf /Applications/ClipboardManager.app
```

如需一并清除本地配置与历史记录：

```bash
defaults delete com.clipboardmanager.app
```

---

## 构建脚本说明

| 脚本 | 作用 |
|---|---|
| `build.sh` | 使用 `swiftc` 编译源码到 `.build/ClipboardManager.app` |
| `package.sh` | 完整打包：编译 + 生成图标 + 制作 DMG |
| `install.sh` | 安装 `.build/ClipboardManager.app` 到 `/Applications` 并启动 |

---

## 更多文档

- 架构设计：[ARCHITECTURE.md](ARCHITECTURE.md)
- 功能实现：[FEATURE_DOCUMENT.md](FEATURE_DOCUMENT.md)
