#!/bin/bash
# Installs the stickyAudio toggle as a macOS Shortcut
#
# This creates a Shortcut called "Toggle stickyAudio" that you can:
#   - Run from Spotlight (type "Toggle stickyAudio")
#   - Assign a keyboard shortcut in System Settings
#   - Add to the menu bar via Control Center > Shortcuts
#   - Trigger with Siri ("Toggle stickyAudio")

set -e

TOGGLE_SCRIPT="$HOME/.config/audio-wake-fix/stickyaudio-toggle.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Install the toggle script
mkdir -p "$HOME/.config/audio-wake-fix"
cp "$SCRIPT_DIR/stickyaudio-toggle.sh" "$TOGGLE_SCRIPT"
chmod +x "$TOGGLE_SCRIPT"

echo "=========================================="
echo "macOS Shortcuts Setup"
echo "=========================================="
echo ""
echo "The toggle script has been installed to:"
echo "  $TOGGLE_SCRIPT"
echo ""
echo "Now create the Shortcut manually (takes ~30 seconds):"
echo ""
echo "  1. Open the Shortcuts app (Spotlight > 'Shortcuts')"
echo "  2. Click '+' to create a new Shortcut"
echo "  3. Search for 'Run Shell Script' and add it"
echo "  4. Paste this as the script body:"
echo ""
echo "     $TOGGLE_SCRIPT"
echo ""
echo "  5. Name the Shortcut 'Toggle stickyAudio'"
echo "  6. Click the (i) button > 'Add Keyboard Shortcut'"
echo "     Suggested: Ctrl+Option+S"
echo ""
echo "Optional - show in menu bar:"
echo "  System Settings > Control Center > Menu Bar Only >"
echo "  Shortcuts > Show in Menu Bar"
echo ""
echo "Optional - show notification on toggle:"
echo "  After the 'Run Shell Script' action, add 'Show Notification'"
echo "  Set the title to 'Shell Script Result' (the output of the toggle)"
