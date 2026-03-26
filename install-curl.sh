#!/bin/bash

# stickyAudio - Remote installer (curl | bash)
# Usage: curl -fsSL https://raw.githubusercontent.com/adamdexter/stickyaudio/main/install-curl.sh | bash

set -e

REPO="adamdexter/stickyaudio"
BRANCH="main"
TMPDIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Downloading stickyAudio..."

# Download and extract the repo
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMPDIR"

# The extracted folder is named stickyaudio-main
cd "$TMPDIR/stickyaudio-$BRANCH"

# Run the real installer
chmod +x install.sh
./install.sh
