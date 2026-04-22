#!/usr/bin/env bash
set -euo pipefail

HAPP_DIR="/opt/happ"

# 1️⃣ Проверка обязательных файлов
[[ -f "${HAPP_DIR}/key.txt" ]]      || { echo "ERROR: key.txt missing" >&2; exit 1; }
[[ -f "${HAPP_DIR}/config.yaml" ]]  || { echo "ERROR: config.yaml missing" >&2; exit 1; }

# 2️⃣ Если пользователь включил iptables‑менеджмент, проверяем наличие CAP
if [[ "${ENABLE_IPTABLES}" == "true" && "$(id -u)" -ne 0 ]]; then
    echo "ERROR: iptables operations require container run with --cap-add=NET_ADMIN"
    exit 1
fi

# 3️⃣ Запуск мониторинга в фоне
"${HAPP_DIR}/scripts/happ-monitor.sh" &
MONITOR_PID=$!

# 5️⃣ Watchdog – реакция на SIGTERM/SIGINT
cleanup() {
    echo "Stopping monitor (PID $MONITOR_PID)…" >&2
    kill "$MONITOR_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# 5️⃣ Таailing log (позволяет видеть live‑логи)
exec tail -f "${LOG_DIR}/monitor.log"