#!/bin/bash
# Meeting Alarm — update to latest version
# Preserves your Spotify track setting

set -e

REPO="https://raw.githubusercontent.com/tomersh-ac/tomers-skills/main"
SCRIPTS_DIR="$HOME/.claude/scripts/meeting_alarm"
SKILL_DIR="$HOME/.claude/skills/meeting-alarm"

echo ""
echo "=== Meeting Alarm Update ==="
echo ""

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "✗ Meeting Alarm not installed. Run the install script first."
    exit 1
fi

# ── Save current Spotify setting ───────────────────────────────────────────────
SPOTIFY_URI=""
if [ -f "$SCRIPTS_DIR/daemon.sh" ]; then
    SPOTIFY_URI=$(grep -o 'spotify:track:[A-Za-z0-9]*' "$SCRIPTS_DIR/daemon.sh" || true)
fi
[ -n "$SPOTIFY_URI" ] && echo "► Preserving Spotify track: $SPOTIFY_URI"

# ── Download latest scripts ────────────────────────────────────────────────────
echo "► Downloading latest version..."
curl -fsSL "$REPO/meeting-alarm/scripts/daemon.sh"          -o "$SCRIPTS_DIR/daemon.sh"
curl -fsSL "$REPO/meeting-alarm/scripts/overlay_helper.swift" -o "$SCRIPTS_DIR/overlay_helper.swift"
curl -fsSL "$REPO/meeting-alarm/SKILL.md"                   -o "$SKILL_DIR/SKILL.md" 2>/dev/null || true
curl -fsSL "$REPO/meeting-alarm/scripts/setup.sh"           -o "$SKILL_DIR/scripts/setup.sh" 2>/dev/null || true
curl -fsSL "$REPO/meeting-alarm/scripts/update.sh"          -o "$SKILL_DIR/scripts/update.sh" 2>/dev/null || true
chmod +x "$SCRIPTS_DIR/daemon.sh"
echo "✓ Scripts updated"

# ── Restore Spotify setting ────────────────────────────────────────────────────
if [ -n "$SPOTIFY_URI" ]; then
    sed -i '' \
        "s|play_spotify() { osascript -e 'tell application \"Spotify\" to play' .*|play_spotify() { osascript -e 'tell application \"Spotify\" to play track \"$SPOTIFY_URI\"' \&>/dev/null || true; }|" \
        "$SCRIPTS_DIR/daemon.sh"
    echo "✓ Spotify track restored"
fi

# ── Recompile Swift overlay ────────────────────────────────────────────────────
echo "► Recompiling overlay (~10 seconds)..."
SDK=$(xcrun --show-sdk-path)
swiftc "$SCRIPTS_DIR/overlay_helper.swift" \
    -o "$SCRIPTS_DIR/overlay_helper_bin" \
    -sdk "$SDK"
echo "✓ Overlay recompiled"

# ── Rebuild .app bundle ────────────────────────────────────────────────────────
APP="$SCRIPTS_DIR/MeetingOverlayHelper.app"
cp "$SCRIPTS_DIR/overlay_helper_bin" "$APP/Contents/MacOS/MeetingOverlayHelper"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "✓ App bundle rebuilt"

# ── Reload agents ──────────────────────────────────────────────────────────────
launchctl unload "$HOME/Library/LaunchAgents/com.meetingalarm.plist" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.meetingalarm.overlay.plist" 2>/dev/null || true
launchctl load "$HOME/Library/LaunchAgents/com.meetingalarm.plist"
launchctl load "$HOME/Library/LaunchAgents/com.meetingalarm.overlay.plist"
sleep 2

echo ""
echo "✓ Meeting Alarm updated and restarted!"
