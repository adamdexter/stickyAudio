# stickyAudio

> **v2.0.3** — Hardened daemon & wake script, wake-time device retries, expanded test suite & CI

Keeps your Mac's audio output pinned to the headphone jack. Automatically corrects when macOS switches to the internal speaker after sleep/wake, Bluetooth disconnect, or coreaudiod restarts.

## How It Works

Two layers of protection:

1. **Sleepwatcher** - Immediately restores headphone output after sleep/wake events
2. **Polling daemon** - Checks every 10 seconds for audio routing drift, catches Bluetooth disconnect fallback, coreaudiod restarts, and other edge cases

**Smart Bluetooth handling:** The daemon only corrects when macOS falls back to the **internal speaker**. If you're actively using AirPods or other Bluetooth audio, it will **not** interrupt.

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/adamdexter/stickyaudio/main/install-curl.sh | bash
```

### From source

```bash
git clone https://github.com/adamdexter/stickyaudio.git
cd stickyaudio
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

# Seconds the wake script waits after wake before checking devices.
# It also retries for ~10s on top of this if the device hasn't appeared
# yet (USB DACs and the jack can be slow to re-enumerate).
WAKE_SETTLE_DELAY=2
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
As of v2.0.2, all scripts auto-detect the Homebrew prefix (`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel) — no manual path editing needed. If you installed an earlier version, re-run the installer.

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

### v2.0.3
- **Wake script retries device detection** — USB DACs and the headphone jack can take several seconds to re-enumerate after wake; the wake script now retries for up to ~10 seconds instead of checking once. The initial settle delay is configurable via `WAKE_SETTLE_DELAY` in the config file.
- **Daemon survives bad config edits** — a non-numeric or zero `POLL_INTERVAL` previously made the daemon's `sleep` fail and spin at 100% CPU; it now falls back to 10 seconds. The daemon also logs (and recovers) if `SwitchAudioSource` disappears mid-flight, e.g. during a brew upgrade, and verifies each correction actually took effect.
- **Safer re-install over a running daemon** — generated scripts and the config are now written to a temp file and atomically `mv`'d into place, so a running daemon can't execute a half-written script.
- **Installer robustness** — manually entered built-in speaker names are validated like the target device; a warning is printed if the target and built-in speaker are the same device; plist paths are XML-escaped; the curl-pipe extracted-directory name is no longer hardcoded (it only matched by case-insensitivity luck); `install-curl.sh` fails loudly if the download/extraction produced nothing.
- **Uninstaller** — no longer hangs silently when removing the CLI needs a sudo password (prints the manual command instead); also removes the Automator Quick Action.
- **CLI** — `devices`, `check`, `switch`, and `watch` now fail with a clear message when `SwitchAudioSource` isn't installed instead of printing empty output.
- **Tests & CI** — new suites cover the generated wake/daemon scripts (extracted from install.sh heredocs), the config-escaping round-trip against hostile device names, and the hotkey toggle script; the CLI install-block tests no longer require network access and pass when run as root; CI additionally runs the suite under macOS system bash 3.2 (what users actually get) and shellchecks every script including the generated ones.

### v2.0.2
- **Fix curl-pipe install prompt swallowed by closed stdin** — `curl ... | bash` left install.sh reading from the exhausted curl pipe, so the device-name prompt EOF'd instantly, the installer exited silently, and the user's typed answer leaked to their shell. install-curl.sh now reattaches stdin to `/dev/tty`.
- **Intel Mac support** — the daemon, wake script, CLI, and sleepwatcher LaunchAgent hardcoded Apple Silicon Homebrew paths (`/opt/homebrew`). All now probe both prefixes and fall back to PATH.
- **Exact device-name matching** — availability checks used substring/regex grep, so e.g. `LG TV SSCR2` matched the `LG TV SSCR2 (eqMac)` line. All device checks now use exact whole-line fixed-string matching.
- **Config hardening** — device names are escaped before being written to the sourced config file, so names containing `$`, backticks, or quotes can't execute as shell.
- **Installer robustness** — empty input at the device prompt now fails loudly instead of dying silently under `set -e`; a typed name that doesn't match any listed device prints a warning; sleepwatcher detection checks Homebrew's sbin paths (no more spurious reinstall).
- **Uninstaller** — also removes the CLI when it's a copied file (tarball/curl installs), not just a symlink.
- **CLI fixes** — `pause`/`log` validate numeric arguments; `pause` works before first daemon run; `switch` errors clearly when the device is unplugged and verifies the switch took effect; `history` correction counts no longer break when a log has zero matches.

### v2.0.1
- **Fix `command not found: stickyaudio` after curl-script install** — `install-curl.sh` extracted the repo to a temp dir, and the installer symlinked the CLI into that dir. When the temp dir was cleaned up, the symlink dangled and the command vanished. The installer now copies the CLI when run from a tarball, symlinks only when run from a git checkout, and falls back to downloading the CLI from GitHub when piped directly to bash.

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
