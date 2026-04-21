#!/bin/bash
# TS6-Manager Pelican install script
# Installs Node 20, Go 1.22, ffmpeg, builds all three services, writes start.sh + proxy.cjs.

set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== TS6-Manager install: start ==="
date -u

REPO_URL="https://github.com/clusterzx/ts6-manager.git"
BRANCH="${BRANCH:-main}"
TARGET="/mnt/server"

# 1. Base system tools
echo "[install] Installing base packages..."
apt-get update
apt-get install -y --no-install-recommends \
    git curl wget ca-certificates xz-utils build-essential \
    ffmpeg python3 python3-pip tar gnupg openssl jq

# 2. Node 20 via NodeSource if missing
if ! command -v node >/dev/null 2>&1; then
    echo "[install] Installing Node.js 20 from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y --no-install-recommends nodejs
fi
echo "[install] node: $(node -v), npm: $(npm -v)"

# 3. pnpm via corepack (comes with Node)
echo "[install] Enabling pnpm via corepack..."
corepack enable || npm install -g corepack
corepack prepare pnpm@9 --activate
echo "[install] pnpm: $(pnpm -v)"

# 4. Go 1.22 (install manually to get current version)
echo "[install] Installing Go 1.22.5..."
GO_VERSION="1.22.5"
cd /tmp
rm -rf /tmp/go
wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz
export PATH=/usr/local/go/bin:$PATH
echo "[install] go: $(go version)"

# 5. Clone repo
mkdir -p "$TARGET"
cd "$TARGET"
if [ -d ".git" ]; then
    echo "[install] Existing repo, pulling latest..."
    git fetch --all
    git checkout "$BRANCH"
    git pull
else
    echo "[install] Cloning $REPO_URL (branch $BRANCH)..."
    rm -rf /tmp/ts6_src
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" /tmp/ts6_src
    shopt -s dotglob nullglob
    mv /tmp/ts6_src/* . 2>/dev/null || true
    mv /tmp/ts6_src/.[!.]* . 2>/dev/null || true
    rm -rf /tmp/ts6_src
fi

# 6. Install + build packages
echo "[install] pnpm install..."
pnpm install --no-frozen-lockfile

echo "[install] Building @ts6/common..."
pnpm --filter @ts6/common run build

echo "[install] prisma generate..."
pnpm --filter @ts6/backend exec prisma generate

echo "[install] Building @ts6/backend..."
pnpm --filter @ts6/backend run build

echo "[install] Building @ts6/frontend..."
pnpm --filter @ts6/frontend run build

# 7. Build Go sidecar binary
echo "[install] Building Go sidecar..."
mkdir -p "$TARGET/bin"
( cd packages/sidecar && CGO_ENABLED=0 go build -ldflags='-s -w' -o "$TARGET/bin/sidecar" main.go )
chmod +x "$TARGET/bin/sidecar"
echo "[install] sidecar built: $(ls -la $TARGET/bin/sidecar)"

# 8. yt-dlp static binary
echo "[install] Fetching yt-dlp..."
curl -fsSL -o "$TARGET/bin/yt-dlp" https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux
chmod +x "$TARGET/bin/yt-dlp"

# 9. Runtime deps for proxy.cjs (simple npm, not pnpm workspace to avoid conflicts)
echo "[install] Installing runtime proxy deps (express + http-proxy-middleware)..."
mkdir -p "$TARGET/runtime_proxy"
cd "$TARGET/runtime_proxy"
cat > package.json <<'PKGJSON'
{
  "name": "ts6-manager-proxy",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "express": "^4.19.2",
    "http-proxy-middleware": "^3.0.0"
  }
}
PKGJSON
npm install --omit=dev --no-audit --no-fund --silent
cd "$TARGET"

# 10. Persistent dirs
mkdir -p "$TARGET/packages/backend/data" "$TARGET/data/music"

# 11. .env (first install only)
if [ ! -f "$TARGET/.env" ]; then
    echo "[install] Generating .env with fresh secrets..."
    JWT_SECRET_VAL=$(head -c 48 /dev/urandom | base64 | tr -d '=+/' | head -c 48)
    ENCRYPTION_KEY_VAL=$(head -c 48 /dev/urandom | base64 | tr -d '=+/' | head -c 48)
    cat > "$TARGET/.env" <<EOF
NODE_ENV=production
JWT_SECRET=${JWT_SECRET_VAL}
ENCRYPTION_KEY=${ENCRYPTION_KEY_VAL}
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d
BACKEND_PORT=3001
SIDECAR_PORT=9800
DATABASE_URL=file:./data/ts6webui.db
MUSIC_DIR=/home/container/data/music
SIDECAR_URL=http://127.0.0.1:9800
EOF
fi

# 12. Write start.sh
cat > "$TARGET/start.sh" <<'STARTSH'
#!/bin/bash
set -u
cd /home/container

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

export PATH="/home/container/bin:${PATH}"
export BACKEND_PORT="${BACKEND_PORT:-3001}"
export SIDECAR_PORT="${SIDECAR_PORT:-9800}"
export SIDECAR_URL="http://127.0.0.1:${SIDECAR_PORT}"
export FRONTEND_URL="${FRONTEND_URL:-http://0.0.0.0:${SERVER_PORT}}"
export DATABASE_URL="${DATABASE_URL:-file:./data/ts6webui.db}"
export MUSIC_DIR="${MUSIC_DIR:-/home/container/data/music}"
export PORT="${BACKEND_PORT}"

mkdir -p packages/backend/data "$MUSIC_DIR"

echo "[start] prisma db push (idempotent)..."
( cd packages/backend && npx prisma db push --skip-generate || true )

echo "[start] Launching Go sidecar on :${SIDECAR_PORT}..."
SIDECAR_PORT="$SIDECAR_PORT" /home/container/bin/sidecar &
SIDECAR_PID=$!

echo "[start] Launching backend on :${BACKEND_PORT}..."
( cd packages/backend && node dist/index.js ) &
BACKEND_PID=$!

for _ in $(seq 1 30); do
    if (echo > /dev/tcp/127.0.0.1/"$BACKEND_PORT") 2>/dev/null; then
        echo "[start] Backend up on :$BACKEND_PORT"
        break
    fi
    sleep 1
done

trap 'kill -TERM $SIDECAR_PID $BACKEND_PID 2>/dev/null || true; exit 0' INT TERM

echo "TS6-Manager ready on port ${SERVER_PORT}"
exec node /home/container/proxy.cjs
STARTSH
chmod +x "$TARGET/start.sh"

# 13. Write proxy.cjs
cat > "$TARGET/proxy.cjs" <<'PROXYJS'
const path = require('path');
const express = require('/home/container/runtime_proxy/node_modules/express');
const { createProxyMiddleware } = require('/home/container/runtime_proxy/node_modules/http-proxy-middleware');

const PORT = parseInt(process.env.SERVER_PORT || '3000', 10);
const BACKEND = `http://127.0.0.1:${process.env.BACKEND_PORT || '3001'}`;
const STATIC_DIR = path.resolve('/home/container/packages/frontend/dist');

const app = express();

app.use('/api', createProxyMiddleware({
  target: BACKEND,
  changeOrigin: true,
  ws: true,
  xfwd: true,
}));

app.use('/ws', createProxyMiddleware({
  target: BACKEND,
  changeOrigin: true,
  ws: true,
  xfwd: true,
}));

app.use(express.static(STATIC_DIR, { index: 'index.html' }));

app.get('*', (req, res) => {
  res.sendFile(path.join(STATIC_DIR, 'index.html'));
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[proxy] Frontend+API on 0.0.0.0:${PORT} -> backend ${BACKEND}`);
});
PROXYJS

echo "[install] Files in $TARGET:"
ls -la "$TARGET" | head -40
echo "=== TS6-Manager install: done ==="
date -u
