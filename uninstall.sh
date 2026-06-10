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

# Remove the CLI — may be a symlink (git-checkout install) or a regular
# file (tarball/curl install copies it).
# sudo -n (non-interactive): a plain `sudo` with stderr suppressed would
# sit silently waiting for a password the user can't see.
for dir in /opt/homebrew/bin /usr/local/bin; do
    if [ -L "$dir/stickyaudio" ] || [ -f "$dir/stickyaudio" ]; then
        if rm "$dir/stickyaudio" 2>/dev/null || sudo -n rm "$dir/stickyaudio" 2>/dev/null; then
            echo "✓ Removed $dir/stickyaudio"
        else
            echo "⚠️  Could not remove $dir/stickyaudio (permission denied)."
            echo "   Remove it manually: sudo rm \"$dir/stickyaudio\""
        fi
    fi
done

# Remove the Automator Quick Action if the hotkey setup installed it
WORKFLOW_DIR="$HOME/Library/Services/Toggle stickyAudio.workflow"
if [ -d "$WORKFLOW_DIR" ]; then
    rm -rf "$WORKFLOW_DIR"
    echo "✓ Removed Automator Quick Action"
fi

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
