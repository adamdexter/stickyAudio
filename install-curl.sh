#!/bin/bash

# stickyAudio - Remote installer (curl | bash)
# Usage: curl -fsSL https://raw.githubusercontent.com/adamdexter/stickyaudio/main/install-curl.sh | bash

set -e

REPO="adamdexter/stickyaudio"
BRANCH="main"
# Not named TMPDIR: that env var is commonly exported on macOS, and
# overwriting it would leak our (soon-deleted) directory to child
# processes like brew.
WORKDIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Downloading stickyAudio..."

# Download and extract the repo
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$WORKDIR"

# The extracted folder is named stickyaudio-main
cd "$WORKDIR/stickyaudio-$BRANCH"

# Run the real installer.
#
# When invoked as `curl ... | bash`, stdin is the curl pipe — which is
# already at EOF by the time install.sh reaches its `read` prompts. Without
# a redirect, `read` returns immediately and the user's typed answer goes
# to the surrounding shell (often producing a confusing parser error from
# zsh). Reattach stdin to the controlling terminal so interactive prompts
# actually reach the user. Fall back to inherited stdin when no tty is
# available (e.g. an unattended CI run that pre-detects the device).
chmod +x install.sh
if [ -e /dev/tty ]; then
    ./install.sh < /dev/tty
else
    ./install.sh
fi
