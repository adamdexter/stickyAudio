#!/bin/bash
# Creates a macOS Automator Quick Action for toggling stickyAudio pause.
#
# The Quick Action can be assigned a global keyboard shortcut via:
#   System Settings > Keyboard > Keyboard Shortcuts > Services

set -e

TOGGLE_SCRIPT="$HOME/.config/audio-wake-fix/stickyaudio-toggle.sh"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW_DIR="$HOME/Library/Services/Toggle stickyAudio.workflow"
CONTENTS_DIR="$WORKFLOW_DIR/Contents"

# Install the toggle script
mkdir -p "$HOME/.config/audio-wake-fix"
cp "$SCRIPT_DIR/stickyaudio-toggle.sh" "$TOGGLE_SCRIPT"
chmod +x "$TOGGLE_SCRIPT"

# Create the Automator Quick Action (workflow bundle)
mkdir -p "$CONTENTS_DIR"

# Info.plist - marks this as an Automator workflow
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Toggle stickyAudio</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
		</dict>
	</array>
</dict>
</plist>
PLIST_EOF

# document.wflow - the actual workflow definition
cat > "$CONTENTS_DIR/document.wflow" << WFLOW_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMCategory</key>
				<string>AMCategoryUtilities</string>
				<key>AMIconName</key>
				<string>Automator</string>
				<key>AMKeywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
				</array>
				<key>AMName</key>
				<string>Run Shell Script</string>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMRequiredResources</key>
				<array/>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Parameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>$TOGGLE_SCRIPT</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>0</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
			</dict>
		</dict>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>1.2.1</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMCategory</key>
				<string>AMCategoryUtilities</string>
				<key>AMIconName</key>
				<string>Automator</string>
				<key>AMName</key>
				<string>Display Notification</string>
				<key>AMParameterProperties</key>
				<dict>
					<key>subtitle</key>
					<dict/>
					<key>title</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Display Notification.action</string>
				<key>ActionName</key>
				<string>Display Notification</string>
				<key>BundleIdentifier</key>
				<string>com.apple.Automator.Display-Notification</string>
				<key>CFBundleVersion</key>
				<string>1.2.1</string>
				<key>Parameters</key>
				<dict>
					<key>subtitle</key>
					<string>Daemon toggle</string>
					<key>title</key>
					<string>stickyAudio</string>
				</dict>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict>
		<key>4A7D4C5C-E3A3-4D8A-B8E3-7C1F2B4A9D6E</key>
		<dict>
			<key>from</key>
			<string>3F8A2B1C-D4E5-6F7A-8B9C-0D1E2F3A4B5C</string>
			<key>to</key>
			<string>7E6D5C4B-A3B2-1C0D-9E8F-7A6B5C4D3E2F</string>
		</dict>
	</dict>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceApplicationGroupName</key>
		<string>General</string>
		<key>serviceApplicationPath</key>
		<string></string>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW_EOF

echo "=========================================="
echo "Automator Quick Action Installed!"
echo "=========================================="
echo ""
echo "Installed to: $WORKFLOW_DIR"
echo ""
echo "To assign a keyboard shortcut:"
echo ""
echo "  1. Open System Settings > Keyboard > Keyboard Shortcuts"
echo "  2. Click 'Services' (or 'App Shortcuts' on older macOS)"
echo "  3. Under 'General', find 'Toggle stickyAudio'"
echo "  4. Double-click to set a shortcut (suggested: Ctrl+Option+S)"
echo ""
echo "The action will toggle pause/resume and show a notification."
