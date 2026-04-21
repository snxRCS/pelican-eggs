#!/bin/bash
# TS6-Manager Pelican install script (thin variant).
# All heavy lifting is done by the pre-built GHCR image
# (ghcr.io/snxrcs/ts6-manager). This script only ensures
# persistent directories exist.

set -e
echo "=== TS6-Manager (prebuilt image) install: start ==="
date -u

TARGET="/mnt/server"
mkdir -p "${TARGET}/data/music"

# Nothing else to do. .env is generated on first boot by /app/start.sh.
echo "[install] Data dirs ready. Start-up files live inside the image at /app/."
echo "[install] The runtime image will auto-generate .env on first boot."
echo "=== TS6-Manager install: done ==="
date -u
