# TS6 Manager — Pelican Egg

Pelican egg for [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) — a web-based management interface for TeamSpeak 6 servers.

This egg packs the original 3-container docker-compose setup (backend, frontend, Go WebRTC sidecar) into a **single Pelican server** via a small start script that supervises all three processes.

## What gets deployed

| Service | Language | Internal Port | Exposed |
|---|---|---|---|
| Frontend (React SPA) + API reverse proxy | Node (express) | `SERVER_PORT` | yes — this is the only public port |
| Backend (Express API + WebQuery client + bot engine) | Node 20 | `BACKEND_PORT` (3001) | internal only |
| Sidecar (WebRTC media relay) | Go (Pion) | `SIDECAR_PORT` (9800) | internal only |

The external-facing port is **`SERVER_PORT`** (your primary allocation). A tiny Node proxy serves the built frontend and forwards `/api` and `/ws` to the backend on localhost.

## Requirements

- Pelican Panel with the `ghcr.io/pelican-eggs/installers:debian` installer image available.
- Node 20 or 22 runtime yolk (`ghcr.io/parkervcp/yolks:nodejs_20` / `nodejs_22`). Included in the egg.
- A primary allocation for the frontend (HTTP).
- **Memory ≥ 1 GB** recommended (build step uses pnpm + Go + Vite — at least **2 GB** is safer for the first install).
- **Disk ≥ 3 GB**. The build pulls a full pnpm workspace, Go toolchain temp files, and yt-dlp.

## Install

Admin area → **Eggs → Import → URL** and paste the raw URL:

```
https://raw.githubusercontent.com/snxRCS/pelican-eggs/main/voice/TS6-Manager-EGG/egg-teamspeak6-manager.json
```

Or upload the file via the **File** tab.

## First boot

1. Create a new server using the `Teamspeak 6 Manager` egg.
2. Assign one allocation — that port is where the UI will be served.
3. Start the server. First install takes a few minutes (pnpm + Vite + Go build).
4. Open `http://<your-ip>:<allocated-port>/setup` and create the admin account.
5. Connect your TeamSpeak server under **Settings → Connections** (WebQuery host, port, API key).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `BRANCH` | `main` | Git ref to check out from clusterzx/ts6-manager. |
| `BACKEND_PORT` | `3001` | Internal. Must not collide with anything else in the container. |
| `SIDECAR_PORT` | `9800` | Internal. |
| `JWT_SECRET` | auto-generated | Regenerated on first install. Rotate to invalidate all tokens. |
| `ENCRYPTION_KEY` | auto-generated | Separate AES-256-GCM key for stored credentials. |
| `FRONTEND_URL` | *(empty)* | Set to the public URL (e.g. `https://ts6.example.com`) if you front the server with a reverse proxy. Used as CORS origin. |
| `TS_ALLOW_SELF_SIGNED` | `false` | Set to `true` if your TeamSpeak WebQuery uses a self-signed cert. |

## Persistent data

Lives under the server's `/home/container`:

- `packages/backend/data/ts6webui.db` — SQLite (users, flows, bots, etc.)
- `data/music/` — downloaded music files
- `.env` — auto-generated secrets (do **not** delete unless you want to reset)

## Reinstall / upgrade

Reinstalling the server re-pulls the repo at `BRANCH`, rebuilds all three services, and keeps `packages/backend/data/` and `data/music/` intact. The `.env` is preserved if present.

## Caveats

- **Single-process limitation of Pelican.** Pelican supervises one top-level process per server. We work around this with a thin `start.sh` that forks the sidecar and backend in the background, then execs the frontend+proxy server in the foreground. If the backend crashes, only the proxy's `/api` calls will fail — the container stays "online" from Pelican's point of view. Restart the server to restart all three services.
- **Video streaming (Pion sidecar)** is built but only reachable on localhost. For it to deliver WebRTC video out of the container, a UDP allocation + firewall rules would need to be added. Default deployment works for all non-video features.
- **Resource usage.** The first install is heavy (Go toolchain, Vite build). After that, runtime is lightweight — backend usually < 300 MB RAM idle.
- This is **not** an official egg from clusterzx. If you hit issues, report them here first, not on the upstream repo.

## License

Egg: MIT.
Upstream project (clusterzx/ts6-manager): MIT.
