#!/bin/bash
set -e

CONFIG="/app/settings.ini"

# 1. Ensure settings.ini exists (user must mount it; fall back to example with a warning)
if [ ! -f "$CONFIG" ]; then
    echo "[WARN] /app/settings.ini not found — copying settings.ini.example as a placeholder"
    echo "[WARN] Please mount your configured settings.ini to /app/settings.ini"
    cp /app/settings.ini.example "$CONFIG"
fi

# 2. Force headless_mode = true — Docker has no display; forgetting this causes a silent hang
# Use tmp file + cp (not sed -i) because sed -i does rename() which fails on single-file bind mounts
_tmp=$(mktemp)
if grep -q "headless_mode" "$CONFIG"; then
    sed 's/^\(headless_mode\s*=\s*\).*/\1true/' "$CONFIG" > "$_tmp"
else
    sed '/^\[app\]/a headless_mode = true' "$CONFIG" > "$_tmp"
fi
cp "$_tmp" "$CONFIG" && rm -f "$_tmp"
echo "[INFO] headless_mode forced to true for Docker environment"

# 3. Ensure data directories exist and redirect state JSON files to /app/data/
#    so they survive container restarts when /app/data is mounted as a volume
mkdir -p /app/downloads /app/data
for f in strava_upload_state.json onelap_download_state.json; do
    if [ -f "/app/$f" ] && [ ! -L "/app/$f" ] && [ ! -f "/app/data/$f" ]; then
        mv "/app/$f" "/app/data/$f"
    fi
    if [ ! -L "/app/$f" ]; then
        ln -sf "/app/data/$f" "/app/$f"
    fi
done

# 4. Dispatch based on arguments or CRON_SCHEDULE env var

MODE="${1:-}"

# Pass through special CLI modes directly
if [[ "$MODE" == --strava-* ]]; then
    echo "[INFO] Running in special mode: $*"
    exec python SyncOnelapToXoss.py "$@"
fi

# Cron mode: install schedule and park in foreground
if [ -n "${CRON_SCHEDULE:-}" ]; then
    echo "[INFO] Installing cron schedule: $CRON_SCHEDULE"
    echo "${CRON_SCHEDULE} root cd /app && python SyncOnelapToXoss.py >> /proc/1/fd/1 2>&1" \
        > /etc/cron.d/synconelap
    chmod 0644 /etc/cron.d/synconelap
    # Export current environment so cron jobs can see PATH, CHROMIUM_PATH, etc.
    printenv | sed 's/^\(.*\)=\(.*\)$/export \1="\2"/' > /etc/profile.d/docker-env.sh
    echo "[INFO] Cron daemon starting — logs will appear here on each run"
    exec cron -f
fi

# Default: one-shot run
echo "[INFO] Running one-shot sync"
exec python SyncOnelapToXoss.py
