#!/bin/bash
# TS6-Manager runtime launcher.
# Baked into the GHCR image at /app/start.sh.
# Generates .env on first boot, launches sidecar + backend + proxy.
set -u

cd /home/container

# ---------- first boot: generate .env with fresh secrets ----------
if [ ! -f .env ]; then
    echo "[start] First boot - generating .env with fresh secrets..."
    JWT_SECRET_VAL=$(head -c 48 /dev/urandom | base64 | tr -d '=+/' | head -c 48)
    ENCRYPTION_KEY_VAL=$(head -c 48 /dev/urandom | base64 | tr -d '=+/' | head -c 48)
    cat > .env <<EOF
NODE_ENV=production
JWT_SECRET=${JWT_SECRET_VAL}
ENCRYPTION_KEY=${ENCRYPTION_KEY_VAL}
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d
BACKEND_PORT=3001
SIDECAR_PORT=9800
EOF
    chmod 600 .env
fi

# Load env
set -a
# shellcheck disable=SC1091
. ./.env
set +a

# Pelican allocates the external port in SERVER_PORT
export BACKEND_PORT="${BACKEND_PORT:-3001}"
export SIDECAR_PORT="${SIDECAR_PORT:-9800}"
export SIDECAR_URL="http://127.0.0.1:${SIDECAR_PORT}"
export FRONTEND_URL="${FRONTEND_URL:-http://0.0.0.0:${SERVER_PORT}}"
export DATABASE_URL="${DATABASE_URL:-file:/home/container/data/ts6webui.db}"
export MUSIC_DIR="${MUSIC_DIR:-/home/container/data/music}"
export PORT="${BACKEND_PORT}"
export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

mkdir -p /home/container/data/music

# ---------- Prisma: idempotent schema sync ----------
echo "[start] prisma db push (idempotent)..."
(
    cd /app/packages/backend
    npx prisma db push --skip-generate || echo "[start] prisma db push failed - continuing"
)

# ---------- Seed default TS server connection from env (idempotent) ----------
# Only seeds when TS_API_KEY is set and no TsServerConfig row exists yet.
# Runs in the backend package dir so the compiled Prisma client resolves.
echo "[start] Checking for default TS connection to seed..."
(
    cd /app/packages/backend
    node /app/seed-connection.mjs || echo "[start] seed-connection failed - continuing"
)

# ---------- spawn sidecar ----------
echo "[start] Launching Go sidecar on :${SIDECAR_PORT}..."
SIDECAR_PORT="$SIDECAR_PORT" /usr/local/bin/sidecar &
SIDECAR_PID=$!

# ---------- spawn backend ----------
echo "[start] Launching backend on :${BACKEND_PORT}..."
(
    cd /app/packages/backend
    node dist/index.js
) &
BACKEND_PID=$!

# Wait for backend TCP accept
for _ in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/"$BACKEND_PORT") 2>/dev/null; then
        echo "[start] Backend listening on :${BACKEND_PORT}"
        break
    fi
    sleep 1
done

# Clean shutdown on signal from Wings (^C / SIGTERM)
shutdown() {
    echo "[start] Shutting down children..."
    kill -TERM "$SIDECAR_PID" "$BACKEND_PID" 2>/dev/null || true
    wait "$SIDECAR_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
    exit 0
}
trap shutdown INT TERM

# Figure out a sensible public base URL for the banner. The runtime does not
# know the external host, so prefer FRONTEND_URL, then SERVER_IP:SERVER_PORT
# (Pelican sets SERVER_IP to the allocation IP), then 0.0.0.0:SERVER_PORT.
BANNER_URL="${FRONTEND_URL:-}"
if [ -z "$BANNER_URL" ] && [ -n "${SERVER_IP:-}" ]; then
    BANNER_URL="http://${SERVER_IP}:${SERVER_PORT}"
fi
BANNER_URL="${BANNER_URL:-http://0.0.0.0:${SERVER_PORT}}"

echo ""
echo "============================================================"
echo "  TS6-Manager is ready on port ${SERVER_PORT}"
echo "  Open in your browser:  ${BANNER_URL}/setup"
echo "  (create the admin account on first visit)"
echo "============================================================"
echo ""

# Run proxy+frontend in foreground so Wings sees the server as alive
exec node /app/proxy.cjs
