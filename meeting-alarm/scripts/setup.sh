#!/bin/bash
# Meeting Alarm — automated setup script
# Usage: bash setup.sh [spotify_track_id]
# Example: bash setup.sh 2zYzyRzz6pRmhPzyfMEC8s

set -e

SCRIPTS_DIR="$HOME/.claude/scripts/meeting_alarm"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SPOTIFY_TRACK_ID="${1:-}"

echo ""
echo "=== Meeting Alarm Setup ==="
echo ""

# ── 1. Xcode CLI tools ────────────────────────────────────────────────────────
if ! xcode-select -p &>/dev/null; then
    echo "► Xcode Command Line Tools not found — triggering installation..."
    echo "  A dialog will appear. Click 'Install' and wait for it to finish."
    xcode-select --install 2>/dev/null || true
    read -r -p "  [Press Enter when Xcode tools are installed] "
    if ! xcode-select -p &>/dev/null; then
        echo "✗ Xcode tools still not detected. Run: xcode-select --install"
        exit 1
    fi
fi
echo "✓ Xcode Command Line Tools ready"

# ── 2. Create scripts directory ───────────────────────────────────────────────
mkdir -p "$SCRIPTS_DIR"
echo "✓ Scripts directory: $SCRIPTS_DIR"

# ── 3. Copy daemon.sh ─────────────────────────────────────────────────────────
cp "$SKILL_DIR/daemon.sh" "$SCRIPTS_DIR/daemon.sh"
chmod +x "$SCRIPTS_DIR/daemon.sh"

if [ -n "$SPOTIFY_TRACK_ID" ]; then
    sed -i '' \
        "s|play_spotify() { osascript -e 'tell application \"Spotify\" to play' .*|play_spotify() { osascript -e 'tell application \"Spotify\" to play track \"spotify:track:${SPOTIFY_TRACK_ID}\"' \&>/dev/null || true; }|" \
        "$SCRIPTS_DIR/daemon.sh"
    echo "✓ Spotify track configured: spotify:track:$SPOTIFY_TRACK_ID"
else
    echo "✓ daemon.sh installed (will resume whatever is playing in Spotify)"
fi

# ── 4. Compile Swift overlay helper ──────────────────────────────────────────
cp "$SKILL_DIR/overlay_helper.swift" "$SCRIPTS_DIR/overlay_helper.swift"
echo "► Compiling overlay helper (~10 seconds)..."
SDK=$(xcrun --show-sdk-path)
swiftc "$SCRIPTS_DIR/overlay_helper.swift" \
    -o "$SCRIPTS_DIR/overlay_helper_bin" \
    -sdk "$SDK"
echo "✓ Overlay helper compiled"

# ── 5. Build .app bundle ──────────────────────────────────────────────────────
APP="$SCRIPTS_DIR/MeetingOverlayHelper.app"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.meetingalarm.overlayhelper</string>
  <key>CFBundleName</key><string>MeetingOverlayHelper</string>
  <key>CFBundleExecutable</key><string>MeetingOverlayHelper</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

cp "$SCRIPTS_DIR/overlay_helper_bin" "$APP/Contents/MacOS/MeetingOverlayHelper"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "✓ Overlay .app bundle built and signed"

# ── 6. Install Launch Agents ──────────────────────────────────────────────────
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS"

cat > "$LAUNCH_AGENTS/com.meetingalarm.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.meetingalarm</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPTS_DIR}/daemon.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF

cat > "$LAUNCH_AGENTS/com.meetingalarm.overlay.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.meetingalarm.overlay</string>
  <key>ProgramArguments</key>
  <array>
    <string>${APP}/Contents/MacOS/MeetingOverlayHelper</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF

echo "✓ Launch Agents installed"

# ── 7. Load agents ────────────────────────────────────────────────────────────
launchctl unload "$LAUNCH_AGENTS/com.meetingalarm.plist" 2>/dev/null || true
launchctl unload "$LAUNCH_AGENTS/com.meetingalarm.overlay.plist" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS/com.meetingalarm.plist"
launchctl load "$LAUNCH_AGENTS/com.meetingalarm.overlay.plist"
sleep 2

# ── 8. Verify ─────────────────────────────────────────────────────────────────
DAEMON_OK=false; OVERLAY_OK=false
launchctl list | grep -q "com.meetingalarm$" && DAEMON_OK=true
launchctl list | grep -q "com.meetingalarm.overlay" && OVERLAY_OK=true

echo ""
echo "=== Status ==="
$DAEMON_OK  && echo "✓ Daemon running"         || echo "✗ Daemon failed to start"
$OVERLAY_OK && echo "✓ Overlay helper running" || echo "✗ Overlay helper failed to start"

if $DAEMON_OK && $OVERLAY_OK; then
    echo ""
    echo "✓ Meeting Alarm installed and running! Both services start automatically on login."
    echo ""
    echo "  Add a Calendar event 2-3 minutes from now to test."
    echo "  Quick overlay test: touch ~/.claude/scripts/meeting_alarm/overlay_trigger"
else
    echo "Something went wrong. Check: cat ~/.claude/scripts/meeting_alarm/alarm.log"
    exit 1
fi
