#!/bin/bash

# stickyAudio Installer v2.0
# Ensures audio output stays on the headphone jack, even after
# sleep/wake, Bluetooth connect/disconnect, and coreaudiod restarts.

set -e

echo "=========================================="
echo "stickyAudio Installer"
echo "=========================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed."
    echo "   Install it first: https://brew.sh"
    echo "   Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "✓ Homebrew found"

# Install SwitchAudioSource if not present
if ! command -v SwitchAudioSource &> /dev/null; then
    echo "→ Installing SwitchAudioSource..."
    brew install switchaudio-osx
else
    echo "✓ SwitchAudioSource already installed"
fi

# Install sleepwatcher if not present
if ! command -v sleepwatcher &> /dev/null; then
    echo "→ Installing sleepwatcher..."
    brew install sleepwatcher
else
    echo "✓ sleepwatcher already installed"
fi

# Show available audio devices
echo ""
echo "=========================================="
echo "Available Audio Output Devices:"
echo "=========================================="
SwitchAudioSource -a -t output
echo ""

# Detect the 3.5mm jack device name (common names)
AUDIO_DEVICE=""
for name in "External Headphones" "Headphones" "Built-in Output" "Line Out"; do
    if SwitchAudioSource -a -t output | grep -q "$name"; then
        AUDIO_DEVICE="$name"
        break
    fi
done

if [ -z "$AUDIO_DEVICE" ]; then
    echo "⚠️  Could not auto-detect 3.5mm audio device."
    echo "   Please enter the exact name from the list above:"
    read -r AUDIO_DEVICE
fi

echo "→ Using audio device: \"$AUDIO_DEVICE\""

# Detect built-in speaker name (what macOS falls back to)
BUILTIN_SPEAKER=""
for name in "MacBook Pro Speakers" "MacBook Air Speakers" "Mac Mini Speakers" "Mac Pro Speakers" "Built-in Speaker" "Internal Speakers"; do
    if SwitchAudioSource -a -t output | grep -q "$name"; then
        BUILTIN_SPEAKER="$name"
        break
    fi
done

if [ -z "$BUILTIN_SPEAKER" ]; then
    echo ""
    echo "⚠️  Could not auto-detect built-in speaker name."
    echo "   The daemon needs to know the internal speaker name so it only"
    echo "   corrects audio when macOS falls back to internal speakers"
    echo "   (it will NOT interrupt Bluetooth/AirPods)."
    echo ""
    echo "   Please enter the built-in speaker name from the list above"
    echo "   (or press Enter to use 'Mac Mini Speakers'):"
    read -r BUILTIN_SPEAKER
    BUILTIN_SPEAKER="${BUILTIN_SPEAKER:-Mac Mini Speakers}"
fi

echo "→ Built-in speaker detected as: \"$BUILTIN_SPEAKER\""

# Create config directory
SCRIPT_DIR="$HOME/.config/audio-wake-fix"
mkdir -p "$SCRIPT_DIR"

# Write config file (used by both daemon and CLI)
cat > "$SCRIPT_DIR/config" << EOF
# stickyAudio configuration
# Edit this file to change settings, then restart the daemon:
#   launchctl unload ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist
#   launchctl load -w ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist

# Target audio output device (your headphone jack)
DEVICE="$AUDIO_DEVICE"

# Built-in speaker name (what macOS falls back to when BT disconnects)
# The daemon ONLY corrects when output is this device.
# This means AirPods/Bluetooth won't be interrupted.
BUILTIN_SPEAKER="$BUILTIN_SPEAKER"

# Polling interval in seconds (how often the daemon checks)
POLL_INTERVAL=10
EOF

echo "✓ Created config file"

# Create the wake script (for sleepwatcher - handles sleep/wake events)
cat > "$SCRIPT_DIR/set-audio-output.sh" << 'WAKE_EOF'
#!/bin/bash
# stickyAudio - Wake event handler
# Triggered by sleepwatcher when Mac wakes from sleep

SCRIPT_DIR="$HOME/.config/audio-wake-fix"
LOG_FILE="$SCRIPT_DIR/audio-wake.log"
CONFIG_FILE="$SCRIPT_DIR/config"
SAS="/opt/homebrew/bin/SwitchAudioSource"

# Load config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi
DEVICE="${DEVICE:-External Headphones}"

# Delay to let the system fully wake
sleep 2

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [wake] $1" >> "$LOG_FILE"
}

log "System woke from sleep"

# Check if the headphone device is available (i.e., something is plugged in)
if "$SAS" -a -t output | grep -q "$DEVICE"; then
    CURRENT=$("$SAS" -c -t output)
    log "Device '$DEVICE' available. Current output: $CURRENT"

    # Switch to headphones
    "$SAS" -s "$DEVICE" -t output 2>> "$LOG_FILE"

    CURRENT=$("$SAS" -c -t output)
    log "Output is now: $CURRENT"
else
    log "Device '$DEVICE' not detected (nothing plugged in), skipping"
fi

# Keep log file manageable (last 500 lines)
tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
WAKE_EOF

chmod +x "$SCRIPT_DIR/set-audio-output.sh"
echo "✓ Created wake script"

# Create the polling daemon script
cat > "$SCRIPT_DIR/stickyaudio-daemon.sh" << 'DAEMON_EOF'
#!/bin/bash
# stickyAudio Daemon - Polls audio output and corrects when needed
#
# This daemon catches audio routing changes that sleepwatcher misses:
# - Bluetooth device disconnects (macOS falls back to internal speaker)
# - coreaudiod restarts
# - Apps changing the default output
#
# IMPORTANT: The daemon ONLY switches audio when the current output is the
# built-in speaker. If you're using AirPods or any other Bluetooth device,
# it will NOT interrupt. It only corrects the "fell back to internal speaker"
# scenario.

SCRIPT_DIR="$HOME/.config/audio-wake-fix"
LOG_FILE="$SCRIPT_DIR/daemon.log"
CONFIG_FILE="$SCRIPT_DIR/config"
SAS="/opt/homebrew/bin/SwitchAudioSource"

# Load config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    DEVICE="${DEVICE:-External Headphones}"
    BUILTIN_SPEAKER="${BUILTIN_SPEAKER:-Mac Mini Speakers}"
    POLL_INTERVAL="${POLL_INTERVAL:-10}"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [daemon] $1" >> "$LOG_FILE"
}

trim_log() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
        tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

is_paused() {
    PAUSE_FILE="$SCRIPT_DIR/paused"
    if [ ! -f "$PAUSE_FILE" ]; then
        return 1  # not paused
    fi
    PAUSE_UNTIL=$(cat "$PAUSE_FILE" 2>/dev/null)
    if [ "$PAUSE_UNTIL" = "indefinite" ]; then
        return 0  # paused indefinitely
    fi
    if [ -n "$PAUSE_UNTIL" ] && [ "$(date +%s)" -lt "$PAUSE_UNTIL" ] 2>/dev/null; then
        return 0  # paused with time remaining
    fi
    # Pause expired, clean up
    rm -f "$PAUSE_FILE"
    return 1  # not paused
}

load_config
log "Daemon started (target: $DEVICE, builtin: $BUILTIN_SPEAKER, interval: ${POLL_INTERVAL}s)"

LAST_OUTPUT=""
CHECK_COUNT=0

while true; do
    # Reload config periodically (every 30 checks) so edits take effect
    CHECK_COUNT=$((CHECK_COUNT + 1))
    if [ $((CHECK_COUNT % 30)) -eq 0 ]; then
        load_config
        trim_log
    fi

    # Skip correction if paused (via 'stickyaudio pause')
    if is_paused; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    CURRENT=$("$SAS" -c -t output 2>/dev/null)

    # Log output changes for debugging
    if [ "$CURRENT" != "$LAST_OUTPUT" ]; then
        log "Output changed: '$LAST_OUTPUT' → '$CURRENT'"
        LAST_OUTPUT="$CURRENT"
    fi

    # Only correct if ALL of these are true:
    # 1. Daemon is not paused
    # 2. Target device is available (headphones plugged in)
    # 3. Current output is the built-in speaker (not AirPods or other BT)
    # 4. Current output is not already the target device
    if [ "$CURRENT" != "$DEVICE" ] && [ "$CURRENT" = "$BUILTIN_SPEAKER" ]; then
        if "$SAS" -a -t output 2>/dev/null | grep -q "$DEVICE"; then
            log "CORRECTED: '$CURRENT' → '$DEVICE' (headphones plugged in but output was on internal speaker)"
            "$SAS" -s "$DEVICE" -t output 2>> "$LOG_FILE"
            LAST_OUTPUT="$DEVICE"
        fi
    fi

    sleep "$POLL_INTERVAL"
done
DAEMON_EOF

chmod +x "$SCRIPT_DIR/stickyaudio-daemon.sh"
echo "✓ Created polling daemon script"

# Create sleepwatcher wakeup hook
ln -sf "$SCRIPT_DIR/set-audio-output.sh" "$HOME/.wakeup"
echo "✓ Created ~/.wakeup symlink"

# Create LaunchAgent for sleepwatcher
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

cat > "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.sleepwatcher.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.audio-wake-fix.sleepwatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/sbin/sleepwatcher</string>
        <string>-V</string>
        <string>-w</string>
        <string>$HOME/.wakeup</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

echo "✓ Created sleepwatcher LaunchAgent"

# Create LaunchAgent for the polling daemon
cat > "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.daemon.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.audio-wake-fix.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/stickyaudio-daemon.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/daemon-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/daemon-stderr.log</string>
</dict>
</plist>
EOF

echo "✓ Created daemon LaunchAgent"

# Load the LaunchAgents
launchctl unload "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.sleepwatcher.plist" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.sleepwatcher.plist"
echo "✓ Loaded sleepwatcher LaunchAgent"

launchctl unload "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.daemon.plist" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENTS_DIR/com.audio-wake-fix.daemon.plist"
echo "✓ Loaded daemon LaunchAgent"

# Install the CLI tool
CLI_INSTALL_DIR="/usr/local/bin"
if [ -d "/opt/homebrew/bin" ]; then
    CLI_INSTALL_DIR="/opt/homebrew/bin"
fi

SCRIPT_SOURCE="$(cd "$(dirname "$0")" && pwd)/stickyaudio"
if [ -f "$SCRIPT_SOURCE" ]; then
    chmod +x "$SCRIPT_SOURCE"
    if ln -sf "$SCRIPT_SOURCE" "$CLI_INSTALL_DIR/stickyaudio" 2>/dev/null; then
        echo "✓ Installed 'stickyaudio' CLI to $CLI_INSTALL_DIR/stickyaudio"
    else
        echo "→ Could not symlink to $CLI_INSTALL_DIR (try: sudo ln -sf $SCRIPT_SOURCE $CLI_INSTALL_DIR/stickyaudio)"
        echo "  You can still run it directly: ./stickyaudio"
    fi
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "stickyAudio is now running with two layers of protection:"
echo ""
echo "  1. Sleepwatcher  - immediately fixes audio after sleep/wake"
echo "  2. Polling daemon - checks every ${POLL_INTERVAL:-10}s, catches Bluetooth"
echo "     disconnect, coreaudiod restarts, and other edge cases"
echo ""
echo "The daemon will ONLY switch to headphones when macOS falls back"
echo "to the internal speaker. It will NOT interrupt AirPods or other"
echo "Bluetooth audio devices."
echo ""
echo "Target device:     \"$AUDIO_DEVICE\""
echo "Built-in speaker:  \"$BUILTIN_SPEAKER\""
echo "Config file:       $SCRIPT_DIR/config"
echo ""
echo "Debug commands:"
echo "  stickyaudio status   - Show full system status"
echo "  stickyaudio doctor   - Run diagnostics"
echo "  stickyaudio log -f   - Follow live logs"
echo "  stickyaudio watch    - Monitor audio output in real-time"
echo "  stickyaudio help     - Show all commands"
echo ""
echo "To uninstall: ./uninstall.sh"
