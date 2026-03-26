#!/bin/bash

# stickyAudio Uninstaller

set -e

echo "=========================================="
echo "stickyAudio Uninstaller"
echo "=========================================="
echo ""

# Unload and remove daemon LaunchAgent
PLIST_DAEMON="$HOME/Library/LaunchAgents/com.audio-wake-fix.daemon.plist"
if [ -f "$PLIST_DAEMON" ]; then
    launchctl unload "$PLIST_DAEMON" 2>/dev/null || true
    rm "$PLIST_DAEMON"
    echo "✓ Removed daemon LaunchAgent"
fi

# Unload and remove sleepwatcher LaunchAgent
PLIST_SLEEPWATCHER="$HOME/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist"
if [ -f "$PLIST_SLEEPWATCHER" ]; then
    launchctl unload "$PLIST_SLEEPWATCHER" 2>/dev/null || true
    rm "$PLIST_SLEEPWATCHER"
    echo "✓ Removed sleepwatcher LaunchAgent"
fi

# Remove wakeup symlink
if [ -L "$HOME/.wakeup" ]; then
    rm "$HOME/.wakeup"
    echo "✓ Removed ~/.wakeup"
fi

# Remove CLI symlink
for dir in /opt/homebrew/bin /usr/local/bin; do
    if [ -L "$dir/stickyaudio" ]; then
        rm "$dir/stickyaudio" 2>/dev/null || sudo rm "$dir/stickyaudio" 2>/dev/null || true
        echo "✓ Removed $dir/stickyaudio"
    fi
done

# Remove config directory
SCRIPT_DIR="$HOME/.config/audio-wake-fix"
if [ -d "$SCRIPT_DIR" ]; then
    rm -rf "$SCRIPT_DIR"
    echo "✓ Removed config directory ($SCRIPT_DIR)"
fi

echo ""
echo "=========================================="
echo "✅ Uninstall Complete!"
echo "=========================================="
echo ""
echo "Note: sleepwatcher and SwitchAudioSource were not"
echo "uninstalled. To remove them:"
echo "  brew uninstall sleepwatcher switchaudio-osx"
