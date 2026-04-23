#!/bin/bash
# happ-monitor.sh – monitor for Xray-core auto‑switch
# Runs inside the Docker container

set -euo pipefail

# ---- Configuration ---------------------------------------------------------
XRAY_PROCESS="xray"                  # process name to watch
PORT="${HAPP_PORT:-10808}"          # SOCKS5 port (default 10808)
STATE_FILE="${HAPP_DIR:-/opt/happvpn}/state.json"
LOG_FILE="${HAPP_DIR:-/opt/happvpn}/monitor.log"
DOWN_DELAY=420                      # 7 minutes (seconds) before forced OFF
UP_DELAY=120                        # 2 minutes (seconds) before turning ON again

# ---- Helper functions -------------------------------------------------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# Load or initialise state
if [ -f "$STATE_FILE" ]; then
    STATUS=$(jq -r '.status' "$STATE_FILE" 2>/dev/null || echo "off")
else
    STATUS="on"
    echo "{\"status\":\"$STATUS\"}" > "$STATE_FILE"
fi

# Check if the Xray process is alive
is_running() {
    pgrep -f "$XRAY_PROCESS" > /dev/null
}

# Check if the listening port is open
port_open() {
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/${PORT}" 2>/dev/null
}

# Persist new status
save_state() {
    jq -n --arg s "$1" '{status:$s}' > "$STATE_FILE"
}

# ---- Main loop -------------------------------------------------------------
log "Starting Xray monitor – status: $STATUS"
log "Monitoring process: $XRAY_PROCESS, port: $PORT"

while true; do
    # Determine current availability
    RUNNING=$(is_running && echo "yes" || echo "no")
    OPEN=$(port_open && echo "yes" || echo "no")
    AVAILABLE="$RUNNING|$OPEN"

    log "Status check – Process: $RUNNING, Port: $OPEN, State: $STATUS"

    # Decide action based on current status and availability
    if [ "$STATUS" = "on" ]; then
        if [ "$AVAILABLE" != "yes|yes" ]; then
            # Availability lost – start down timer
            if [ ! -f "${STATE_FILE}.down_start" ] || [ "$(cat "${STATE_FILE}.down_start" 2>/dev/null || echo 0)" -eq 0 ]; then
                log "⚠️  Availability lost – recording down start"
                echo "$(date +%s)" > "${STATE_FILE}.down_start"
            fi
            # Check elapsed time
            DOWN_START=$(cat "${STATE_FILE}.down_start")
            ELAPSED=$(( $(date +%s) - DOWN_START ))
            if [ "$ELAPSED" -ge "$DOWN_DELAY" ]; then
                log "⚠️  Down time exceeded $DOWN_DELAY sec – turning OFF"
                "${HAPP_DIR:-/opt/happvpn}/scripts/happ-proxy-manager.sh" off
                save_state "off"
                rm -f "${STATE_FILE}.down_start"
            else
                log "⏳ Waiting for recovery (elapsed $ELAPSED / $DOWN_DELAY sec)"
            fi
        else
            # All good – reset any previous down timer
            rm -f "${STATE_FILE}.down_start"
            log "✅ All good – keeping ON"
        fi
    else
        # STATUS is "off"
        if [ "$AVAILABLE" = "yes|yes" ]; then
            # Service came back – start up timer
            if [ ! -f "${STATE_FILE}.up_start" ]; then
                log "🔄 Recovery detected – starting up delay"
                echo "$(date +%s)" > "${STATE_FILE}.up_start"
            fi
            UP_START=$(cat "${STATE_FILE}.up_start")
            ELAPSED_UP=$(( $(date +%s) - UP_START ))
            if [ "$ELAPSED_UP" -ge "$UP_DELAY" ]; then
                log "🔄 Up delay satisfied – turning ON"
                "${HAPP_DIR:-/opt/happvpn}/scripts/happ-proxy-manager.sh" on
                save_state "on"
                rm -f "${STATE_FILE}.up_start"
            else
                log "⏳ Waiting for stable period (up elapsed $ELAPSED_UP / $UP_DELAY sec)"
            fi
        else
            # Still down – reset up timer
            rm -f "${STATE_FILE}.up_start"
            log "⚠️  Still down – resetting up timer"
        fi
    fi

    sleep 60
done
