#!/bin/bash
# happ-proxy-manager.sh – simple wrapper to turn the Happ proxy on/off
# Usage: happ-proxy-manager.sh [on|off|status]

set -euo pipefail

# ---- Configuration ---------------------------------------------------------
STATE_FILE="/opt/happvpn/state.json"
LOG_FILE="/opt/happvpn/monitor.log"

# ---- Helper ---------------------------------------------------------------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# ---- Ensure state file exists ---------------------------------------------
if [ ! -f "$STATE_FILE" ]; then
    log "State file not found – creating with default 'off'"
    echo '{"status":"off"}' > "$STATE_FILE"
fi

# ---- Command handling -------------------------------------------------------
case "${1:-status}" in
    on)
        # Here you would actually enable the SOCKS5 listener or modify iptables.
        # For the demo we just update the status flag.
        log "Executing 'on' – updating status"
        jq '.status="on"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        log "Proxy enabled (status=on)"
        ;;
    off)
        log "Executing 'off' – updating status"
        jq '.status="off"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        log "Proxy disabled (status=off)"
        ;;
    status)
        STATUS=$(jq -r '.status' "$STATE_FILE")
        if [ "$STATUS" = "on" ]; then
            echo "Proxy is currently: ON"
        else
            echo "Proxy is currently: OFF"
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        exit 1
        ;;
esac