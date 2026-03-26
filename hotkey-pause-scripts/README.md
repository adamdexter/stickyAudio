# Hotkey Pause Scripts

Optional integrations to toggle stickyAudio's daemon pause/resume with a keyboard shortcut or launcher command, instead of the CLI.

Pick whichever method matches your setup:

| Method | Requirements | Hotkey | Launcher Trigger |
|--------|-------------|--------|-----------------|
| **macOS Shortcuts** | None (built-in) | Yes (via System Settings) | Yes (Spotlight, Siri) |
| **Automator** | None (built-in) | Yes (via System Settings) | No |
| **Alfred** | Alfred + Powerpack | Yes (via Alfred prefs) | Yes (type "sticky") |

All three methods do the same thing: toggle the daemon between paused and active, with a notification showing the new state.

## macOS Shortcuts (Recommended)

The simplest option — no extra software needed.

```bash
chmod +x shortcuts/setup-shortcut.sh
./shortcuts/setup-shortcut.sh
```

Then follow the on-screen instructions to create the Shortcut in the Shortcuts app and assign a keyboard shortcut.

**Suggested hotkey:** `Ctrl+Option+S`

## Automator Quick Action

Creates a system-wide Quick Action (Service) with notification feedback.

```bash
chmod +x automator/setup-automator.sh
./automator/setup-automator.sh
```

Then assign a keyboard shortcut:
1. System Settings > Keyboard > Keyboard Shortcuts > Services
2. Find "Toggle stickyAudio" under General
3. Assign your preferred shortcut

## Alfred Workflow

For Alfred Powerpack users. Provides both a keyword trigger and a hotkey slot.

```bash
chmod +x alfred/setup-alfred.sh
./alfred/setup-alfred.sh
```

Then either:
- Double-click the generated `Toggle stickyAudio.alfredworkflow` to import
- Or type `sticky` in Alfred after importing

To assign a hotkey: Alfred Preferences > Workflows > Toggle stickyAudio > click the Hotkey trigger.

## How It Works

All methods call the same toggle script (`stickyaudio-toggle.sh`):

- If the daemon is **active** → creates a pause file → daemon stops correcting audio
- If the daemon is **paused** → removes the pause file → daemon resumes correcting

The toggle script is installed to `~/.config/audio-wake-fix/stickyaudio-toggle.sh` by any of the setup scripts above.

You can also always use the CLI directly:
```bash
stickyaudio pause       # Pause indefinitely
stickyaudio pause 30    # Pause for 30 minutes
stickyaudio resume      # Resume
```
