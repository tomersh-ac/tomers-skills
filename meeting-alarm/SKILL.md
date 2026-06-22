---
name: meeting-alarm
description: >
  Alerts you before meetings with a flashing red screen border, macOS notification, and optional Spotify playback.
  Reads from macOS Calendar — no Google API keys needed.
  Use when the user wants to set up, start, stop, or check the status of the meeting alarm.
  Commands: /meeting-alarm setup, /meeting-alarm start, /meeting-alarm stop, /meeting-alarm status, /meeting-alarm spotify <URL>
---

# Meeting Alarm Skill

Monitors macOS Calendar and fires 3 alerts when a meeting is 3 minutes away:
1. **Red gradient flash** — edges of the screen pulse red for 10 seconds
2. **macOS notification** — with sound, shows the meeting name and time remaining
3. **Spotify** — plays a chosen track (optional)

Works entirely through macOS built-in apps. No Google Cloud account, no API keys, no Python packages. Both background services auto-start on login — nothing to maintain.

---

## Architecture

Two background processes run as macOS Launch Agents (auto-start on login):

| Agent | Label | What it does |
|---|---|---|
| Daemon | `com.meetingalarm` | Polls Calendar every 30s via AppleScript; writes a trigger file when a meeting is near |
| Overlay helper | `com.meetingalarm.overlay` | Persistent GUI process; watches the trigger file and flashes the screen |

The overlay helper must be a separate persistent process because background daemons cannot open GUI windows directly on macOS. It stays alive permanently so it already has a WindowServer connection when it needs to flash.

All runtime files live in `~/.claude/scripts/meeting_alarm/`.

---

## Commands

### `/meeting-alarm setup`

Two steps require manual GUI interaction. Everything else is fully automated.

#### Manual step 1 — Sync Google Calendar to macOS Calendar

The alarm reads events from the macOS **Calendar** app. If the user's meetings are in Google Calendar (e.g. Google Workspace), they need to connect it once.

Tell the user:

> **Connect your Google Calendar to the macOS Calendar app:**
>
> 1. Open the **Calendar** app
> 2. Menu bar → **Calendar → Add Account…**
> 3. Choose **Google**, sign in with your work Google account
> 4. Make sure **Calendar** is ticked → Done
>
> Your Google calendars will appear in Calendar and sync automatically from now on.
> Let me know once you can see your meetings in Calendar.

Open Calendar automatically:
```bash
open -a Calendar
```

Wait for the user to confirm their calendars are visible before continuing.

#### Manual step 2 — Spotify track (optional)

Ask:
> "Do you want a specific Spotify track to play when an alarm fires? Right-click any song in Spotify → Share → Copy Song Link and paste it here. Or say skip."

Extract the track ID from the URL: `https://open.spotify.com/track/TRACK_ID?...` → `TRACK_ID`

#### Run the automated setup

Find this skill's `scripts/` directory (same folder as this SKILL.md). Run:

```bash
# With Spotify track:
bash "/path/to/skill/scripts/setup.sh" "TRACK_ID"

# Without Spotify:
bash "/path/to/skill/scripts/setup.sh"
```

The script handles everything automatically:
- Checks for Xcode CLI tools; if missing, triggers the macOS installer dialog and waits
- Copies scripts, compiles the Swift overlay binary for the machine's architecture
- Builds and signs the .app bundle
- Installs and loads both Launch Agents
- Verifies both services are running

After setup, tell the user:
> "All done! Add a Calendar event 2–3 minutes from now to test it — you'll see a red flashing border, get a notification, and Spotify will play. Quick overlay test: `touch ~/.claude/scripts/meeting_alarm/overlay_trigger`"

---

### `/meeting-alarm status`

```bash
echo "=== Meeting Alarm Status ==="

if launchctl list | grep -q "com.meetingalarm$"; then
    PID=$(launchctl list | awk '/com\.meetingalarm$/ {print $1}')
    echo "Daemon:          RUNNING (PID $PID)"
else
    echo "Daemon:          NOT RUNNING — run /meeting-alarm start"
fi

if launchctl list | grep -q "com.meetingalarm.overlay"; then
    PID=$(launchctl list | awk '/com\.meetingalarm\.overlay/ {print $1}')
    echo "Overlay helper:  RUNNING (PID $PID)"
else
    echo "Overlay helper:  NOT RUNNING — run /meeting-alarm start"
fi

echo ""
echo "=== Recent log ==="
tail -15 ~/.claude/scripts/meeting_alarm/alarm.log 2>/dev/null || echo "(no log yet)"
```

---

### `/meeting-alarm stop`

```bash
launchctl unload "$HOME/Library/LaunchAgents/com.meetingalarm.plist" 2>/dev/null && echo "Daemon stopped"
launchctl unload "$HOME/Library/LaunchAgents/com.meetingalarm.overlay.plist" 2>/dev/null && echo "Overlay helper stopped"
```

---

### `/meeting-alarm start`

```bash
launchctl load "$HOME/Library/LaunchAgents/com.meetingalarm.plist" 2>/dev/null && echo "Daemon started"
launchctl load "$HOME/Library/LaunchAgents/com.meetingalarm.overlay.plist" 2>/dev/null && echo "Overlay helper started"
sleep 2
launchctl list | grep meetingalarm
```

If the plist files don't exist, tell the user to run `/meeting-alarm setup` first.

---

### `/meeting-alarm spotify <URL>`

Change the Spotify track.

1. Extract the track ID: `https://open.spotify.com/track/TRACK_ID?...` → `TRACK_ID`
2. Update `play_spotify` in `~/.claude/scripts/meeting_alarm/daemon.sh`:
   ```bash
   play_spotify() { osascript -e 'tell application "Spotify" to play track "spotify:track:TRACK_ID"' &>/dev/null || true; }
   ```
3. Reload the daemon:
   ```bash
   launchctl unload "$HOME/Library/LaunchAgents/com.meetingalarm.plist"
   launchctl load "$HOME/Library/LaunchAgents/com.meetingalarm.plist"
   ```
4. Confirm: "Done — next alarm will play [song name]."

---

## Troubleshooting

**Calendar permission denied**: System Settings → Privacy & Security → Calendars → enable `bash`.

**Overlay doesn't appear**: Test with `touch ~/.claude/scripts/meeting_alarm/overlay_trigger`. If nothing shows within 1 second, check `launchctl list | grep meetingalarm.overlay` — if exit code is non-zero, run `/meeting-alarm start`.

**No alarms firing**: Check `~/.claude/scripts/meeting_alarm/alarm.log`. If it shows `0 event(s)` for a meeting that exists, the event may be in a calendar not synced to macOS Calendar.

**Spotify not playing**: If Spotify isn't open the command silently skips. Open Spotify first, then re-test.
