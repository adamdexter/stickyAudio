#!/bin/bash

# Mac Mini Audio Wake Fix Uninstaller

set -e

echo "=========================================="
echo "Mac Mini Audio Wake Fix Uninstaller"
echo "=========================================="
echo ""

# Unload and remove LaunchAgent
PLIST="$HOME/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist"
if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm "$PLIST"
    echo "✓ Removed LaunchAgent"
fi

# Remove wakeup symlink
if [ -L "$HOME/.wakeup" ]; then
    rm "$HOME/.wakeup"
    echo "✓ Removed ~/.wakeup"
fi

# Remove config directory
SCRIPT_DIR="$HOME/.config/audio-wake-fix"
if [ -d "$SCRIPT_DIR" ]; then
    rm -rf "$SCRIPT_DIR"
    echo "✓ Removed config directory"
fi

echo ""
echo "=========================================="
echo "✅ Uninstall Complete!"
echo "=========================================="
echo ""
echo "Note: sleepwatcher and SwitchAudioSource were not"
echo "uninstalled. To remove them:"
echo "  brew uninstall sleepwatcher switchaudio-osx"
