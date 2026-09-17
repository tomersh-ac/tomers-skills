#!/bin/bash
# Meeting alarm daemon — queries macOS Calendar app via AppleScript.
# Installed as a Launch Agent so it runs in the GUI session with Calendar access.

SCRIPTS_DIR="$HOME/.claude/scripts/meeting_alarm"
LOG_FILE="$SCRIPTS_DIR/alarm.log"
ALERTED_FILE="$SCRIPTS_DIR/alerted_keys.txt"
DISABLED_FILE="$SCRIPTS_DIR/disabled"
PID_FILE="/tmp/meeting_alarm.pid"
POLL_INTERVAL=30
ALERT_WINDOW=3  # minutes ahead to look

echo "$$" > "$PID_FILE"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }
log "INFO Daemon started (PID $$)"

cleanup() { log "INFO Daemon stopping"; rm -f "$PID_FILE"; exit 0; }
trap cleanup SIGTERM SIGINT

notify() {
    local summary="$1" mins="$2"
    local safe="${summary//\"/\\\"}"
    osascript -e "display notification \"${safe} starts in ${mins} minute(s)!\" with title \"Meeting Alert\" sound name \"Ping\""
}

show_overlay() { touch "$HOME/.claude/scripts/meeting_alarm/overlay_trigger"; }

play_spotify() { osascript -e 'tell application "Spotify" to play track "spotify:track:2zYzyRzz6pRmhPzyfMEC8s"' &>/dev/null || true; }

trim_alerted() {
    local lines; lines=$(wc -l < "$ALERTED_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt 1000 ]; then
        tail -500 "$ALERTED_FILE" > "${ALERTED_FILE}.tmp" && mv "${ALERTED_FILE}.tmp" "$ALERTED_FILE"
    fi
}

while true; do
    if [ -f "$DISABLED_FILE" ]; then
        log "INFO Paused — skipping Calendar poll"
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Check Calendar is running before querying
    if ! pgrep -x "Calendar" > /dev/null; then
        log "WARN Calendar app is not running — cannot detect meetings. Open Calendar.app to enable alarms."
        sleep "$POLL_INTERVAL"
        continue
    fi

    # If a meeting is coming up in the next 15 min, refresh Calendar before alerting
    UPCOMING=$(osascript -e 'tell application "Calendar"
        set theDate to current date
        set soonFuture to theDate + (15 * minutes)
        repeat with cal in calendars
            try
                if (count of (events of cal whose start date >= theDate and start date <= soonFuture and allday event is false)) > 0 then return "true"
            end try
        end repeat
        return "false"
    end tell' 2>/dev/null)
    if [ "$UPCOMING" = "true" ]; then
        osascript -e 'tell application "Calendar" to reload calendars' &>/dev/null || true
        sleep 2
    fi

    # Use (start date of ev) as string for key — avoids "minutes" keyword conflict
    EVENTS=$(osascript << APPLESCRIPT
tell application "Calendar"
    set theDate to current date
    set nearFuture to theDate + ($ALERT_WINDOW * minutes)
    set resultText to ""
    repeat with cal in calendars
        try
            set calEvents to (events of cal whose start date >= theDate and start date <= nearFuture)
            repeat with ev in calEvents
                set secUntil to ((start date of ev) - theDate) as integer
                set startKey to (start date of ev) as string
                set evLine to (summary of ev) & "||" & (secUntil as string) & "||" & startKey
                set resultText to resultText & evLine & linefeed
            end repeat
        end try
    end repeat
    return resultText
end tell
APPLESCRIPT
)

    EVENT_COUNT=$(echo "$EVENTS" | grep -c "||" 2>/dev/null || echo 0)
    log "INFO Polled — ${EVENT_COUNT} event(s) in ${ALERT_WINDOW}-min window"

    if [ -n "$EVENTS" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            SUMMARY=$(echo "$line" | awk -F'\\|\\|' '{print $1}')
            SEC_UNTIL=$(echo "$line" | awk -F'\\|\\|' '{print $2}')
            START_KEY=$(echo "$line" | awk -F'\\|\\|' '{print $3}')
            ALERT_KEY="${SUMMARY}|${START_KEY}"
            [ -z "$SEC_UNTIL" ] && continue

            if ! grep -qF "$ALERT_KEY" "$ALERTED_FILE" 2>/dev/null; then
                MINS=$(( (SEC_UNTIL + 59) / 60 ))
                [ "$MINS" -lt 1 ] && MINS=1
                log "INFO ALERT: '$SUMMARY' starts in ${MINS}m"
                show_overlay
                notify "$SUMMARY" "$MINS"
                play_spotify
                echo "$ALERT_KEY" >> "$ALERTED_FILE"
                trim_alerted
            fi
        done <<< "$EVENTS"
    fi

    sleep "$POLL_INTERVAL"
done
