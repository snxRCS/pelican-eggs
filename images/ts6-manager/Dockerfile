# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------
# Multi-stage build for clusterzx/ts6-manager packed into one
# Pelican-compatible yolk image with container user (uid 988).
#
# Final image contains: Node 20, ffmpeg, yt-dlp, built frontend,
# backend and Go WebRTC sidecar binary. Nothing needs to be
# installed at server creation time.
# ---------------------------------------------------------------

ARG TS6_REPO=https://github.com/clusterzx/ts6-manager.git
ARG TS6_REF=main

# ---------- stage 1: build node packages with pnpm -----------
FROM node:20-slim AS node-builder

RUN corepack enable && corepack prepare pnpm@9 --activate

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates openssl python3 build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG TS6_REPO
ARG TS6_REF
RUN git clone --depth 1 --branch "${TS6_REF}" "${TS6_REPO}" .

RUN pnpm install --no-frozen-lockfile
RUN pnpm --filter @ts6/common run build
RUN pnpm --filter @ts6/backend exec prisma generate
RUN pnpm --filter @ts6/backend run build
RUN pnpm --filter @ts6/frontend run build

# ---------- stage 2: build the Go WebRTC sidecar -----------
FROM golang:1.22-bookworm AS go-builder

WORKDIR /build
COPY --from=node-builder /build/packages/sidecar /build/sidecar
WORKDIR /build/sidecar
RUN CGO_ENABLED=0 go build -ldflags='-s -w' -o /sidecar main.go

# ---------- stage 3: build proxy helper deps -----------
FROM node:20-slim AS proxy-builder

WORKDIR /proxy
COPY proxy-package.json package.json
RUN npm install --omit=dev --no-audit --no-fund --silent

# ---------- stage 4: final runtime image -----------
# node:20-slim already provides node+npm+npx with correct shared libs.
FROM node:20-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl bash tini \
        ffmpeg python3 openssl \
 && rm -rf /var/lib/apt/lists/*

# yt-dlp static binary
ADD --chmod=755 https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux /usr/local/bin/yt-dlp

# Go sidecar binary
COPY --from=go-builder /sidecar /usr/local/bin/sidecar
RUN chmod +x /usr/local/bin/sidecar

# Copy the built TS6 Manager application
RUN mkdir -p /app
COPY --from=node-builder /build/package.json        /app/package.json
COPY --from=node-builder /build/pnpm-workspace.yaml /app/pnpm-workspace.yaml
COPY --from=node-builder /build/node_modules        /app/node_modules
COPY --from=node-builder /build/packages            /app/packages

# Copy proxy deps (express + http-proxy-middleware) built in proxy stage
COPY --from=proxy-builder /proxy/node_modules /app/runtime_proxy/node_modules
COPY --from=proxy-builder /proxy/package.json /app/runtime_proxy/package.json

# Start scripts live in /app and stay in the image
COPY start.sh /app/start.sh
COPY proxy.cjs /app/proxy.cjs
COPY seed-connection.mjs /app/seed-connection.mjs
RUN chmod +x /app/start.sh

# Pelican-style container user (uid/gid 988) so Wings can exec as non-root
RUN groupadd --gid 988 container \
 && useradd  --uid 988 --gid 988 --home-dir /home/container --create-home --shell /bin/bash container \
 && chown -R container:container /app /home/container

ENV HOME=/home/container \
    NODE_ENV=production \
    PATH=/usr/local/bin:/usr/bin:/bin

USER container
WORKDIR /home/container

# tini reaps orphaned child processes (sidecar, backend) cleanly
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["bash", "/app/start.sh"]
