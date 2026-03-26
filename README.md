# stickyAudio

> **v2.0** — Now with polling daemon, CLI debug tools, and pause/resume

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

> **Upgrading from v1.0?** Run `./uninstall.sh` first (from your old checkout), then pull the latest and run `./install.sh`.

## Requirements

- macOS (tested on Ventura/Sonoma/Sequoia on Apple Silicon Mac Mini)
- [Homebrew](https://brew.sh) package manager

## CLI Commands

After installation, the `stickyaudio` command is available in your terminal:

| Command | Description |
|---------|-------------|
| `stickyaudio status` | Full system status: current output, target device, services, Bluetooth devices, pause state |
| `stickyaudio devices` | List all audio output devices with active/target indicators |
| `stickyaudio doctor` | Run diagnostic checks and report any problems with fixes |
| `stickyaudio log` | Show recent log entries (wake + daemon activity) |
| `stickyaudio log -f` | Follow logs in real-time |
| `stickyaudio history` | Show audio switch history with timestamps and correction counts |
| `stickyaudio check` | Run a single daemon check manually (with interactive switch prompt) |
| `stickyaudio switch` | Immediately switch to the configured headphone device |
| `stickyaudio pause` | Pause the daemon indefinitely |
| `stickyaudio pause 30` | Pause the daemon for 30 minutes |
| `stickyaudio resume` | Resume the daemon after pausing |
| `stickyaudio watch` | Live-monitor audio output changes in your terminal (1s resolution) |
| `stickyaudio config` | Show all configuration paths and current settings |
| `stickyaudio help` | Show help message |

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

## Using Internal Speakers with Headphones Plugged In

By default, stickyAudio will correct any fallback to the internal speaker within 10 seconds — which is exactly what you want 99% of the time. But if you intentionally want to use the built-in speakers while keeping headphones plugged in (e.g., playing audio for the room during a call), the daemon would switch it back.

**To temporarily disable the daemon:**

```bash
# Pause indefinitely
stickyaudio pause

# Or pause for a set duration (auto-resumes)
stickyaudio pause 60    # pauses for 1 hour

# When you're done, resume
stickyaudio resume
```

**Prefer a keyboard shortcut?** Ready-made hotkey integrations are available in [`hotkey-pause-scripts/`](hotkey-pause-scripts/). The recommended setup uses **macOS Shortcuts** (no extra software needed):

1. Run the setup helper:
   ```bash
   cd hotkey-pause-scripts
   chmod +x shortcuts/setup-shortcut.sh
   ./shortcuts/setup-shortcut.sh
   ```
2. Open the **Shortcuts** app and create a new Shortcut
3. Add a **Run Shell Script** action with: `~/.config/audio-wake-fix/stickyaudio-toggle.sh`
4. Optionally add a **Show Notification** action to see the toggle state
5. Name it "Toggle stickyAudio" and assign a keyboard shortcut (suggested: `Ctrl+Option+S`)

Integrations for **Automator** and **Alfred** are also included — see [`hotkey-pause-scripts/README.md`](hotkey-pause-scripts/README.md) for details.

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
| `~/.config/audio-wake-fix/stickyaudio-toggle.sh` | Pause/resume toggle (used by hotkey integrations) |
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

## Changelog

### v2.0
- **Polling daemon** — Checks audio routing every 10 seconds, catching Bluetooth disconnect fallback, coreaudiod restarts, and other events that sleepwatcher misses
- **Smart Bluetooth awareness** — Daemon only corrects when output falls back to the internal speaker; never interrupts AirPods or other Bluetooth devices
- **Pause/resume** — Temporarily disable the daemon when you intentionally want internal speakers (`stickyaudio pause` / `stickyaudio resume`), with optional timeout
- **CLI debug tool** (`stickyaudio`) — 13 commands for status, diagnostics, live monitoring, history, and configuration
- **Shared config file** — Single `~/.config/audio-wake-fix/config` file used by both daemon and wake script; edit once, applies everywhere
- **Hotkey integrations** — Ready-made toggle scripts for macOS Shortcuts, Automator, and Alfred
- **Built-in speaker auto-detection** — Installer now detects both the headphone device and the internal speaker name

### v1.0
- Initial release
- Sleepwatcher-based wake script to restore headphone output after sleep
- Automatic headphone device detection
- LaunchAgent for auto-start

## License

MIT - Use freely
