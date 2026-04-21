# TS6-Manager Yolk Image

Pre-built Pelican-compatible Docker image for [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager).

Published automatically to GHCR by the `build-ts6-manager` GitHub Actions workflow whenever this directory changes on `main`:

```
ghcr.io/snxrcs/ts6-manager:latest
ghcr.io/snxrcs/ts6-manager:sha-<commit>
```

## What's inside

| Component | Source | Location in image |
|---|---|---|
| `node` 20 | from `node:20-slim` | `/usr/local/bin/node` |
| `ffmpeg` | Debian bookworm | `/usr/bin/ffmpeg` |
| `yt-dlp` | upstream static binary | `/usr/local/bin/yt-dlp` |
| Go WebRTC sidecar | built from `packages/sidecar` of ts6-manager | `/usr/local/bin/sidecar` |
| Backend (Express API) | built from `packages/backend` | `/app/packages/backend/dist` |
| Frontend (React/Vite) | built from `packages/frontend` | `/app/packages/frontend/dist` |
| Shared common | built from `packages/common` | `/app/packages/common/dist` |
| Proxy (express + http-proxy-middleware) | built in `proxy-builder` stage | `/app/runtime_proxy/node_modules` |
| `start.sh`, `proxy.cjs` | this directory | `/app/start.sh`, `/app/proxy.cjs` |

The image uses `tini` as PID 1 so the three spawned processes (sidecar, backend, proxy) get cleanly reaped on `SIGTERM`.

A `container` user (uid/gid 988) is created so Pelican Wings can `exec` as non-root; its home is `/home/container`.

## Runtime behaviour

`start.sh` on first boot generates a fresh `.env` with random `JWT_SECRET` and `ENCRYPTION_KEY` into `/home/container/.env` (persistent across restarts thanks to the Pelican volume mount).

Then it launches:

1. `sidecar` on `SIDECAR_PORT` (default 9800, localhost only)
2. `node /app/packages/backend/dist/index.js` on `BACKEND_PORT` (default 3001, localhost only)
3. `node /app/proxy.cjs` on `SERVER_PORT` (the Pelican allocation, public)

The proxy serves the built frontend and transparently forwards `/api` and `/ws` to the backend.

## Rebuilding locally

```bash
docker build \
  --build-arg TS6_REPO=https://github.com/clusterzx/ts6-manager.git \
  --build-arg TS6_REF=main \
  -t ts6-manager:dev \
  images/ts6-manager
```

## Security

- Non-root at runtime (uid 988).
- Only one port is exposed through Pelican allocation; sidecar and backend stay on localhost.
- `.env` is `chmod 600`.
- Image has no package manager lockfile vulnerabilities at build time (pnpm `--no-frozen-lockfile` used because upstream occasionally updates the lockfile; swap to frozen once you pin a ref).
