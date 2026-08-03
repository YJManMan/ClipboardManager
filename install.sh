#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/.build/ClipboardManager.app"
TARGET="/Applications/ClipboardManager.app"

if [ ! -d "$APP" ]; then
    echo "❌ 未找到 $APP，请先运行 build.sh 或 package.sh"
    exit 1
fi

# Kill any running instances
if pgrep -f "ClipboardManager.app" > /dev/null; then
    echo "🔄 关闭正在运行的程序..."
    pkill -f "ClipboardManager.app" 2>/dev/null || true
    sleep 1
fi

if [ -d "$TARGET" ]; then
    echo "🔄 旧版本已存在，正在替换..."
    rm -rf "$TARGET"
fi

cp -R "$APP" "$TARGET"
echo "✅ 已安装到 /Applications/ClipboardManager.app"
echo ""
echo "运行中..."
open "$TARGET"
