#!/usr/bin/env bash
# Sekai Notch — auto installer
# Usage: bash install.sh
set -e

NOTCH_DIR="$HOME/.config/quickshell/sekai-notch"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🌸 Sekai Notch installer"
echo "========================"

# 1. Check quickshell
if command -v qs >/dev/null 2>&1; then
    QS=qs
elif command -v quickshell >/dev/null 2>&1; then
    QS=quickshell
else
    echo "❌ quickshell/qs not found. Install Quickshell first."
    exit 1
fi
echo "✓ Found quickshell: $($QS --version 2>/dev/null || echo ok)"

# 2. Create target dir
mkdir -p "$NOTCH_DIR"
echo "✓ Target: $NOTCH_DIR"

# 3. Copy files
for f in shell.qml Notch.qml NotchShape.qml NotchButton.qml SekaiTheme.qml; do
    if [ -f "$SRC_DIR/$f" ]; then
        cp "$SRC_DIR/$f" "$NOTCH_DIR/$f"
        echo "  copied $f"
    else
        echo "  ⚠ missing $f (skipped)"
    fi
done

echo ""
echo "✅ Installed. Run with:"
echo "   qs -c sekai-notch"
echo ""
echo "Optional auto-start (Hyprland): add to ~/.config/hypr/user.lua:"
echo "   hl.on(\"hyprland.start\", function() hl.exec_cmd(\"flock -n /tmp/sekai-notch.lock qs -c sekai-notch\") end)"
echo ""
echo "Optional auto-start (other WMs): run 'qs -c sekai-notch' on session start."