#!/bin/bash
# stickyaudio-toggle.sh
# Toggles stickyAudio daemon pause state.
# Used by Shortcuts, Automator, and Alfred integrations.
#
# Returns a notification-friendly message on stdout.

PAUSE_FILE="$HOME/.config/audio-wake-fix/paused"

if [ -f "$PAUSE_FILE" ]; then
    rm -f "$PAUSE_FILE"
    echo "stickyAudio Resumed"
else
    echo "indefinite" > "$PAUSE_FILE"
    echo "stickyAudio Paused"
fi
