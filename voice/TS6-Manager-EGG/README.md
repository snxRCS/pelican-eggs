# TS6 Manager — Pelican Egg (GHCR image)

Pelican egg for [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) — a web-based management interface for TeamSpeak 6 servers.

## How this egg works

Instead of building everything on your Pelican node (which needs ~3 GB temp disk and 10 minutes of CPU per install), this egg uses a **pre-built Docker image** published to GHCR by the `build-ts6-manager` GitHub Actions workflow in this repository:

```
ghcr.io/snxrcs/ts6-manager:latest
```

The image contains the built React frontend, the Express backend, the Go WebRTC sidecar binary, ffmpeg and yt-dlp. On the Pelican side the egg's install script only creates the persistent-data directory — nothing else. The container is launched with `bash /app/start.sh`, which generates a fresh `.env` on first boot and spawns sidecar + backend + proxy.

## Install

Admin → **Eggs → Import → URL** and paste:

```
https://raw.githubusercontent.com/snxRCS/pelican-eggs/main/voice/TS6-Manager-EGG/egg-teamspeak6-manager.json
```

## Resources

- **Memory:** 512 MB is enough for idle + one small TeamSpeak. Go higher if you'll run YouTube/music bots (ffmpeg transcoding).
- **Disk:** 500 MB is plenty — the SQLite DB and downloaded music go into `/home/container/data/`.
- **Allocation:** one TCP port for the web UI (the frontend+API proxy listens on `SERVER_PORT`).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `BACKEND_PORT` | `3001` | Internal only. Change if 3001 collides. |
| `SIDECAR_PORT` | `9800` | Internal only. Video WebRTC relay. |
| `FRONTEND_URL` | *(empty)* | Set to your public URL (e.g. `https://ts6.example.com`) if you front it with a reverse proxy. Used as CORS origin. |
| `TS_ALLOW_SELF_SIGNED` | `false` | Set to `true` if your TeamSpeak WebQuery uses a self-signed cert. |

`JWT_SECRET` and `ENCRYPTION_KEY` are generated automatically on first boot and stored in `/home/container/.env` (persistent across restarts / reinstalls).

## First-boot steps

1. Start the server. It pulls the image (~200-300 MB) and launches the stack. Logs end with `TS6-Manager ready on port <port>`.
2. Open `http://<your-node>:<port>/setup` and create the admin account.
3. Log in, go to **Settings → Connections**, add your TeamSpeak server (WebQuery host, port, API key).

## Updating

Push to `main` in this repo touching `images/ts6-manager/**` triggers the GitHub Actions workflow, which rebuilds and publishes `ghcr.io/snxrcs/ts6-manager:latest`. Restart the server in Pelican to pull the new image (or trigger Reinstall to also flush `/home/container`).

To rebuild manually against a different upstream ref, run the workflow from the Actions tab with a custom `ts6_ref` input (branch / tag / commit).

## Persistent data

Under `/home/container`:

- `data/ts6webui.db` — SQLite (users, flows, bots, widget tokens)
- `data/music/` — downloaded YouTube / radio tracks
- `.env` — auto-generated secrets (do **not** delete unless you want to invalidate all tokens)

## Caveats

- WebRTC video streaming currently only reaches localhost inside the container. For public WebRTC delivery you need an additional UDP allocation and firewall rules; not wired up in this egg yet.
- The egg pins `ghcr.io/snxrcs/ts6-manager:latest`. Pelican will pull on server start; there's no explicit version pinning in the egg. Use image tags like `:sha-<commit>` in the `docker_images` field if you want reproducibility.
- Not an official egg from clusterzx — report issues in this repo, not upstream.
