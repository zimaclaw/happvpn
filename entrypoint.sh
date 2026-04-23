#!/usr/bin/env bash
set -euo pipefail

HAPP_DIR="/opt/happvpn"
LOG_DIR="/var/log/happvpn"
XRAY_BIN="${HAPP_DIR}/xray"
XRAY_CONFIG="${HAPP_DIR}/config.json"
MONITOR_SCRIPT="${HAPP_DIR}/scripts/happ-monitor.sh"

# 1️⃣ Проверка обязательных файлов
[[ -f "$XRAY_BIN" ]] || { echo "ERROR: xray binary missing" >&2; exit 1; }
[[ -f "$XRAY_CONFIG" ]] || { echo "ERROR: config.json missing" >&2; exit 1; }
[[ -f "${HAPP_DIR}/geoip.dat" ]] || { echo "ERROR: geoip.dat missing" >&2; exit 1; }
[[ -f "${HAPP_DIR}/geosite.dat" ]] || { echo "ERROR: geosite.dat missing" >&2; exit 1; }

echo "=== Starting Xray-core VPN ==="
echo "Xray binary: $XRAY_BIN"
echo "Config: $XRAY_CONFIG"
echo "Logs: $LOG_DIR"

# 2️⃣ Запуск Xray-core в фоне (stdout/stderr в log файл)
echo "🚀 Launching Xray-core..."
"$XRAY_BIN" run -c "$XRAY_CONFIG" > "$LOG_DIR/xray.log" 2>&1 &
XRAY_PID=$!
echo "✅ Xray-core started (PID: $XRAY_PID)"

# 3️⃣ Запуск мониторинга в фоне
echo "📊 Starting monitor..."
"$MONITOR_SCRIPT" >> "$LOG_DIR/monitor.log" 2>&1 &
MONITOR_PID=$!
echo "✅ Monitor started (PID: $MONITOR_PID)"

# 4️⃣ Watchdog – реакция на SIGTERM/SIGINT
cleanup() {
    echo ""
    echo "⚠️  Stopping services..."
    echo "Stopping monitor (PID $MONITOR_PID)…"
    kill "$MONITOR_PID" 2>/dev/null || true
    echo "Stopping Xray-core (PID $XRAY_PID)…"
    kill "$XRAY_PID" 2>/dev/null || true
    echo "✅ Cleanup complete"
    exit 0
}
trap cleanup SIGINT SIGTERM

# 5️⃣ Keep container running — watch logs if they exist
echo ""
echo "📋 Services started. Container running in foreground..."
echo "=========================================="
echo "Use 'docker logs happvpn' to view logs"
echo "Press Ctrl+C to stop"

# Simple sleep loop to keep container alive
while true; do
    sleep 3600
done
