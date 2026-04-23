# Dockerfile for Happ VPN Auto‑Switch (Xray-core based)
# Build a lightweight container that runs Xray-core directly with auto-switch monitoring

# ---- Base image -----------------------------------------------------------
FROM ubuntu:22.04

# ---- Metadata -------------------------------------------------------------
LABEL maintainer="OpenClaw Team <openclaw@happ.su>"
LABEL description="Docker image for automatic VPN proxy switching using Xray-core"
LABEL version="2.0"
LABEL source="https://github.com/XTLS/Xray-core"

# ---- Environment -----------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
ENV HAPP_DIR=/opt/happvpn
ENV STATE_FILE=/opt/happvpn/state.json
ENV LOG_DIR=/var/log/happvpn
ENV XRAY_CONFIG=/opt/happvpn/config.json
# TEMPORARY: Ports changed to 11808/11809 to avoid conflict with running VPN.
# Will revert to 10808/10809 after testing.
ENV HAPP_PORT=11808

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
        jq && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy Xray-core binaries ----------------------------------------------
# Xray-core from Happ package
COPY extracted/opt/happ/bin/core/xray ${HAPP_DIR}/xray
COPY extracted/opt/happ/bin/core/geoip.dat ${HAPP_DIR}/geoip.dat
COPY extracted/opt/happ/bin/core/geosite.dat ${HAPP_DIR}/geosite.dat
COPY extracted/opt/happ/bin/core/routing ${HAPP_DIR}/core/routing

RUN chmod +x ${HAPP_DIR}/xray

# ---- Copy configuration & helper scripts ----------------------------------
COPY key.txt ${HAPP_DIR}/key.txt
COPY scripts/xray-config.json ${HAPP_DIR}/config.json
COPY scripts/happ-proxy-manager.sh ${HAPP_DIR}/scripts/happ-proxy-manager.sh
COPY scripts/happ-monitor.sh ${HAPP_DIR}/scripts/happ-monitor.sh
COPY scripts/happ-config.yaml ${HAPP_DIR}/happ-config.yaml
COPY entrypoint.sh ${HAPP_DIR}/entrypoint.sh

RUN chmod +x ${HAPP_DIR}/entrypoint.sh && \
    chmod +x ${HAPP_DIR}/scripts/happ-monitor.sh && \
    chmod +x ${HAPP_DIR}/scripts/happ-proxy-manager.sh

# ---- Create runtime directory for logs ------------------------------------
RUN touch $LOG_DIR/monitor.log && \
    touch $LOG_DIR/access.log && \
    touch $LOG_DIR/error.log && \
    chown -R happuser:happuser $LOG_DIR

# ---- Switch to non‑root user ---------------------------------------------
USER happuser
WORKDIR $HAPP_DIR

# ---- Entrypoint -----------------------------------------------------------
# The container will run Xray-core with monitoring.
ENTRYPOINT ["./entrypoint.sh"]
