# Mac Mini Audio Wake Fix

Fixes the macOS bug where audio output defaults to the built-in speaker after waking from sleep, even when external speakers or headphones are connected to the 3.5mm audio jack.

## How It Works

1. **sleepwatcher** monitors system sleep/wake events
2. When your Mac wakes, it triggers a script (`~/.wakeup`)
3. The script uses **SwitchAudioSource** to set audio output to your 3.5mm device
4. A 2-second delay ensures the system is fully awake before switching

## Installation

```bash
chmod +x install.sh
./install.sh
```

The installer will:
- Install `switchaudio-osx` and `sleepwatcher` via Homebrew (if not present)
- Auto-detect your 3.5mm audio device (or prompt you to select one)
- Create the wake script and configure it to run automatically

## Requirements

- macOS (tested on Ventura/Sonoma on Apple Silicon Mac Mini)
- [Homebrew](https://brew.sh) package manager

## Manual Configuration

If you need to change the audio device after installation:

1. List available devices:
   ```bash
   SwitchAudioSource -a -t output
   ```

2. Edit the script:
   ```bash
   nano ~/.config/audio-wake-fix/set-audio-output.sh
   ```

3. Change the `DEVICE=` line to match your desired output

## Troubleshooting

### Check if sleepwatcher is running:
```bash
launchctl list | grep sleepwatcher
```

### View the log:
```bash
cat ~/.config/audio-wake-fix/audio-wake.log
```

### Manually test the switch:
```bash
SwitchAudioSource -s "External Headphones" -t output
```

### Restart the service:
```bash
launchctl unload ~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist
launchctl load -w ~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist
```

### Intel Mac users:
Change `/opt/homebrew/` paths to `/usr/local/` in the scripts.

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Files Created

| Path | Purpose |
|------|---------|
| `~/.config/audio-wake-fix/set-audio-output.sh` | The wake script |
| `~/.config/audio-wake-fix/audio-wake.log` | Event log |
| `~/.wakeup` | Symlink to wake script (sleepwatcher convention) |
| `~/Library/LaunchAgents/com.audio-wake-fix.sleepwatcher.plist` | Auto-start sleepwatcher |

## Alternative: Using pmset (No Dependencies)

If you prefer not to install additional tools, you can use a native approach with `pmset` notifications, but it's less reliable. The sleepwatcher method above is the most robust solution.

## Known Device Names

Common 3.5mm audio device names on Mac Mini:
- `External Headphones` (most common on Apple Silicon)
- `Headphones`
- `Built-in Output`
- `Line Out`

## License

MIT - Use freely
