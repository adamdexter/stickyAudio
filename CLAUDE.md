# stickyAudio — notes for Claude Code

macOS utility that keeps audio output pinned to the headphone jack across
sleep/wake, Bluetooth disconnects, and coreaudiod restarts. Pure bash, no
build step.

## Architecture

Two layers of protection, installed by `install.sh`:

1. **Wake script** (`~/.config/audio-wake-fix/set-audio-output.sh`) — run by
   sleepwatcher via `~/.wakeup` symlink on every wake. Switches to the target
   device whenever it's available (intentionally does NOT respect Bluetooth —
   wake always restores the jack).
2. **Polling daemon** (`~/.config/audio-wake-fix/stickyaudio-daemon.sh`) —
   LaunchAgent, polls every 10s. ONLY corrects when current output == the
   built-in speaker, so it never interrupts AirPods/Bluetooth. Honors the
   pause file written by `stickyaudio pause` / the hotkey toggle script.

The wake and daemon scripts do not exist as files in this repo — they are
**generated from quoted heredocs inside install.sh** (`WAKE_EOF`,
`DAEMON_EOF`). To change daemon/wake behavior, edit those heredocs. To
syntax-check them: extract with awk and run `bash -n` (see tests).

`stickyaudio` (repo root) is the user-facing CLI. Both it and the generated
scripts read `~/.config/audio-wake-fix/config`, which is **`source`d as
shell** — see the escaping rule below.

## Install paths

- Git checkout install → CLI is **symlinked** into the brew bin dir (so
  `git pull` updates it).
- Tarball / `curl | bash` install → CLI is **copied** (the source tmpdir is
  deleted after install; a symlink would dangle). The uninstaller must
  therefore handle both symlink and regular file.
- `install-curl.sh` reattaches stdin to `/dev/tty` before running install.sh —
  required because the curl pipe is at EOF when the interactive device prompt
  fires. Removing that redirect silently breaks `curl | bash` installs
  (issue #6, twice).
- The CLI install block in install.sh is fenced by `# CLI_INSTALL_BLOCK_START`
  / `_END` markers; tests extract and run it standalone. Keep the markers and
  keep the block self-contained.

## Hard-won rules (each of these was a real bug)

- **Device-name matching must be `grep -qxF`** (exact whole line, fixed
  string). Substring/regex matching is wrong: device names contain each other
  (`LG TV SSCR2` vs `LG TV SSCR2 (eqMac)`) and contain regex metacharacters.
- **Never hardcode `/opt/homebrew`**. Intel Macs use `/usr/local`. launchd
  runs with a minimal PATH, so scripts must probe both prefixes explicitly
  before falling back to PATH lookup (`SwitchAudioSource` in bin,
  `sleepwatcher` in **sbin**, which is also why `command -v sleepwatcher`
  alone is unreliable in user shells).
- **The config file is sourced** — any user-controlled value written into it
  must go through `escape_for_config()` in install.sh (escapes `\ " $ \``).
- **`set -e` + `read`**: a failed `read` (EOF) kills the script silently.
  Always `read -r VAR || true`, then validate VAR and fail loudly.
- **Don't name a variable `TMPDIR`** — it's commonly exported on macOS and
  assignment leaks to children (brew).
- **`$(grep -c ... || echo 0)`** is a footgun: grep -c prints `0` AND exits 1
  on zero matches, yielding `"0\n0"`. Use `|| true` plus `${var:-0}`.
- **Arithmetic on user input** (`$((MINUTES * 60))`) is an eval vector —
  validate numeric first (see `cmd_pause`).

## Tests & CI

- `bash tests/run.sh` runs every `tests/test_*.sh` (auto-discovered).
  Helpers in `tests/lib.sh`. CI (`.github/workflows/tests.yml`) runs the
  suite on ubuntu + macos; tests must not require SwitchAudioSource,
  Homebrew, network, or a real `$HOME` (sandbox HOME with mktemp).
- New shell scripts must be added to the list in `tests/test_syntax.sh`.
- When fixing a bug, first confirm the new test fails on the pre-fix code
  (e.g. `git stash` the fix, run the test, unstash).

## Issue automation

An hourly Claude routine ("stickyAudio issue triage & auto-fix", managed at
claude.ai/code/routines) auto-triages open GitHub issues: it diagnoses bugs,
writes a regression test, fixes, and replies to the poster. The
`claude-auto` label marks issues it has already handled — don't re-triage
those, and apply the label if you handle an issue manually. Push policy:
direct to main only when the full test suite is green and the diff is small
(≲50 lines, shell/docs only); otherwise a `claude/issue-<n>-*` branch + PR.
It never closes issues and never touches `.github/workflows/`.

## Known design decisions

- Wake script switching away from Bluetooth on wake is intentional (differs
  from the daemon's BT-respecting behavior). Flagged to the user 2026-06-09;
  unchanged.
- Versioning is informal — changelog lives in README.md (`## Changelog`).
  Add an entry there for user-visible changes.
