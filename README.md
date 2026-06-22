# tomers-skills

Claude Code skills for personal and team use.

## Skills

### meeting-alarm

Alerts you before meetings with:
- 🔴 Red gradient flash around all screen edges
- 🔔 macOS notification with meeting name and time
- 🎵 Spotify playback (optional, any track you choose)

Reads from macOS Calendar — works with Google Calendar synced into it. No API keys, no Python, no maintenance. Auto-starts on login.

**Requirements:** macOS, Claude Code, Xcode CLI tools (auto-installed if missing)

**Install:**

1. Copy the `meeting-alarm/` folder into your Claude Code skills directory
2. In Claude Code, run: `/meeting-alarm setup`
3. Follow the 2 prompts (Google Calendar sync + optional Spotify track)

Everything else is automated.

**Commands:**
| Command | What it does |
|---|---|
| `/meeting-alarm setup` | One-time install |
| `/meeting-alarm status` | Check if running |
| `/meeting-alarm stop` | Stop the alarm |
| `/meeting-alarm start` | Restart after stopping |
| `/meeting-alarm spotify <URL>` | Change the Spotify track |
