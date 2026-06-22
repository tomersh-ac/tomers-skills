# tomers-skills

Claude Code skills for personal and team use.

## Skills

### meeting-alarm

Alerts you before meetings with:
- 🔴 Red gradient flash around all screen edges
- 🔔 macOS notification with meeting name and time
- 🎵 Spotify playback (optional, any track you choose)

Reads from macOS Calendar — works with Google Calendar synced into it. No API keys, no Python, no maintenance. Auto-starts on login.

**Requirements:** macOS + Claude Code

### Install

Paste this in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/tomersh-ac/tomers-skills/main/install.sh | bash
```

Then restart Claude Code and run `/meeting-alarm setup`.

### Commands

| Command | What it does |
|---|---|
| `/meeting-alarm setup` | One-time install |
| `/meeting-alarm status` | Check if running |
| `/meeting-alarm stop` | Stop the alarm |
| `/meeting-alarm start` | Restart after stopping |
| `/meeting-alarm spotify <URL>` | Change the Spotify track |
