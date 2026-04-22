# Dockerfile for Happ VPN Auto‑Switch
# Build a lightweight container that runs the Happ monitor and proxy manager
# on a headless Linux server.

# ---- Base image -----------------------------------------------------------
FROM ubuntu:22.04

# ---- Metadata -------------------------------------------------------------
LABEL maintainer="OpenClaw Team <openclaw@happ.su>"
LABEL description="Docker image for automatic Happ proxy switching with failover"
LABEL version="1.0"
LABEL source="https://github.com/Happ-proxy/happ-desktop"

# ---- Environment -----------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
ENV HAPP_DIR=/opt/happvpn
ENV STATE_FILE=/opt/happvpn/state.json
ENV LOG_DIR=/var/log/happvpn

# Create non‑root user for security
RUN useradd --uid 1001 --create-home happuser && \
    mkdir -p $HAPP_DIR && \
    mkdir -p $LOG_DIR && \
    chown -R happuser:happuser $HAPP_DIR $LOG_DIR

# ---- Install dependencies --------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        iptables \
        procps \
        net-tools \
        systemd && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy extracted Happ binaries ------------------------------------
# The build context must contain the folder 'extracted' produced by the
# tar/zstd extraction steps described earlier.
COPY extracted/* ${HAPP_DIR}/
RUN chmod +x ${HAPP_DIR}/happ ${HAPP_DIR}/happd ${HAPP_DIR}/scripts/*.sh

# ---- Copy configuration & helper scripts ----------------------------
COPY key.txt ${HAPP_DIR}/key.txt
COPY scripts/happ-proxy-manager.sh ${HAPP_DIR}/scripts/happ-proxy-manager.sh
COPY scripts/happ-monitor.sh ${HAPP_DIR}/scripts/happ-monitor.sh
COPY scripts/happ-config.yaml ${HAPP_DIR}/config.yaml

# Apply executable permissions
RUN chmod +x ${HAPP_DIR}/scripts/happ-monitor.sh && \
    chmod +x ${HAPP_DIR}/scripts/happ-proxy-manager.sh && \
    chmod +x ${HAPP_DIR}/happ ${HAPP_DIR}/happd

# ---- Create runtime directory for logs ------------------------------------
RUN touch $LOG_DIR/monitor.log && \
    chown happuser:happuser $LOG_DIR/monitor.log

# ---- Switch to non‑root user ---------------------------------------------
USER happuser
WORKDIR $HAPP_DIR

# ---- Entrypoint -----------------------------------------------------------
# The container will run the monitor in the foreground.
ENTRYPOINT ["./scripts/happ-monitor.sh"]