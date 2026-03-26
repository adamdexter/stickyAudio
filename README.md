# stickyAudio

Keeps your Mac's audio output pinned to the headphone jack. Automatically corrects when macOS switches to the internal speaker after sleep/wake, Bluetooth disconnect, or coreaudiod restarts.

## How It Works

Two layers of protection:

1. **Sleepwatcher** - Immediately restores headphone output after sleep/wake events
2. **Polling daemon** - Checks every 10 seconds for audio routing drift, catches Bluetooth disconnect fallback, coreaudiod restarts, and other edge cases

**Smart Bluetooth handling:** The daemon only corrects when macOS falls back to the **internal speaker**. If you're actively using AirPods or other Bluetooth audio, it will **not** interrupt.

## Installation

```bash
chmod +x install.sh
./install.sh
```

The installer will:
- Install `switchaudio-osx` and `sleepwatcher` via Homebrew (if not present)
- Auto-detect your headphone device and built-in speaker names
- Create and start both the wake script and polling daemon
- Install the `stickyaudio` CLI tool

## Requirements

- macOS (tested on Ventura/Sonoma/Sequoia on Apple Silicon Mac Mini)
- [Homebrew](https://brew.sh) package manager

## CLI Debug Tool

After installation, the `stickyaudio` command is available in your terminal:

```bash
stickyaudio status      # Full system status (services, devices, current output)
stickyaudio devices     # List all audio output devices
stickyaudio doctor      # Run diagnostic checks and report problems
stickyaudio log         # Show recent log entries
stickyaudio log -f      # Follow log in real-time
stickyaudio history     # Show audio switch history with timestamps
stickyaudio check       # Run a single daemon check manually
stickyaudio switch      # Manually switch to the configured device
stickyaudio pause       # Pause daemon indefinitely (use internal speaker freely)
stickyaudio pause 30    # Pause daemon for 30 minutes
stickyaudio resume      # Resume daemon after pausing
stickyaudio watch       # Live-monitor audio output changes
stickyaudio config      # Show current configuration
```

### Quick Diagnostics

```bash
# Is everything healthy?
stickyaudio doctor

# What's happening right now?
stickyaudio status

# Watch audio output in real-time (useful when debugging BT issues)
stickyaudio watch

# See when corrections happened
stickyaudio history
```

## Configuration

The config file is at `~/.config/audio-wake-fix/config`:

```bash
# Target audio output device (your headphone jack)
DEVICE="External Headphones"

# Built-in speaker name (what macOS falls back to)
BUILTIN_SPEAKER="Mac Mini Speakers"

# Polling interval in seconds
POLL_INTERVAL=10
```

Edit this file to change settings, then restart the daemon:

```bash
launchctl unload ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist
launchctl load -w ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist
```

## Troubleshooting

### Hotkey Pause/Resume

If you want to toggle pause with a keyboard shortcut instead of the CLI, see [`hotkey-pause-scripts/`](hotkey-pause-scripts/) for ready-made integrations with macOS Shortcuts, Automator, and Alfred.

### Check if services are running:
```bash
stickyaudio doctor
```

### View live logs:
```bash
stickyaudio log -f
```

### Manually test the switch:
```bash
stickyaudio check
```

### Restart all services:
```bash
launchctl unload ~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist
launchctl unload ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist
launchctl load -w ~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist
launchctl load -w ~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist
```

### Intel Mac users:
Change `/opt/homebrew/` paths to `/usr/local/` in the config and scripts.

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Files Created

| Path | Purpose |
|------|---------|
| `~/.config/audio-wake-fix/config` | Configuration (device names, poll interval) |
| `~/.config/audio-wake-fix/set-audio-output.sh` | Wake event handler |
| `~/.config/audio-wake-fix/stickyaudio-daemon.sh` | Polling daemon |
| `~/.config/audio-wake-fix/audio-wake.log` | Wake event log |
| `~/.config/audio-wake-fix/daemon.log` | Daemon activity log |
| `~/.wakeup` | Symlink to wake script (sleepwatcher convention) |
| `~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist` | Sleepwatcher LaunchAgent |
| `~/Library/LaunchAgents/com.audio-wake-fix.daemon.plist` | Daemon LaunchAgent |

## Known Device Names

Common headphone jack names on Mac Mini:
- `External Headphones` (most common on Apple Silicon)
- `Headphones`
- `Built-in Output`
- `Line Out`

## License

MIT - Use freely
