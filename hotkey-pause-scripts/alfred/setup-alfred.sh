#!/bin/bash
# Builds and installs the stickyAudio Alfred Workflow.
#
# Requires: Alfred with Powerpack (paid feature for workflows)
#
# The workflow provides:
#   - A keyword trigger: type "sticky" in Alfred to toggle pause
#   - A hotkey trigger: assign any hotkey in Alfred preferences

set -e

TOGGLE_SCRIPT="$HOME/.config/audio-wake-fix/stickyaudio-toggle.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ALFRED_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/stickyaudio-alfred-build"
WORKFLOW_FILE="$ALFRED_DIR/Toggle stickyAudio.alfredworkflow"

# Install the toggle script
mkdir -p "$HOME/.config/audio-wake-fix"
cp "$SCRIPT_DIR/stickyaudio-toggle.sh" "$TOGGLE_SCRIPT"
chmod +x "$TOGGLE_SCRIPT"

# Build the .alfredworkflow package
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy workflow definition
cp "$ALFRED_DIR/info.plist" "$BUILD_DIR/info.plist"

# Create the toggle script inside the workflow
cat > "$BUILD_DIR/toggle.sh" << 'TOGGLE_EOF'
#!/bin/bash
PAUSE_FILE="$HOME/.config/audio-wake-fix/paused"

if [ -f "$PAUSE_FILE" ]; then
    rm -f "$PAUSE_FILE"
    echo "stickyAudio Resumed"
else
    echo "indefinite" > "$PAUSE_FILE"
    echo "stickyAudio Paused"
fi
TOGGLE_EOF
chmod +x "$BUILD_DIR/toggle.sh"

# Package as .alfredworkflow (it's just a zip)
cd "$BUILD_DIR"
zip -q "$WORKFLOW_FILE" info.plist toggle.sh
cd - > /dev/null

rm -rf "$BUILD_DIR"

echo "=========================================="
echo "Alfred Workflow Built!"
echo "=========================================="
echo ""
echo "Workflow saved to:"
echo "  $WORKFLOW_FILE"
echo ""
echo "To install:"
echo "  Double-click 'Toggle stickyAudio.alfredworkflow'"
echo "  Alfred will open and prompt you to import it."
echo ""
echo "Usage:"
echo "  - Type 'sticky' in Alfred to toggle pause/resume"
echo "  - Or assign a hotkey in Alfred > Workflows > Toggle stickyAudio"
echo "    Click the [Hotkey] box and press your preferred key combo"
echo ""
echo "Note: Alfred Powerpack (paid) is required for workflows."
