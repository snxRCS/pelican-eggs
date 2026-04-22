# pelican-eggs

Community-maintained [Pelican Panel](https://pelican.dev) eggs by [@snxRCS](https://github.com/snxRCS).

Eggs in this repo aim to stay **thin**: heavy build artifacts are packed into pre-built Docker images published via GitHub Actions to GHCR, so Pelican nodes only need to pull and run — no on-server compilation, no disk-space surprises.

## Available eggs

### Voice

| Egg | Description | Image | Egg JSON |
|---|---|---|---|
| [TS6-Manager](voice/TS6-Manager-EGG) | All-in-one egg for [clusterzx/ts6-manager](https://github.com/clusterzx/ts6-manager) — React frontend + Express backend + Go WebRTC sidecar, pre-built. | `ghcr.io/snxrcs/ts6-manager:latest` | [egg JSON](voice/TS6-Manager-EGG/egg-teamspeak6-manager.json) |

## How to use an egg

In your Pelican admin area:

**Eggs → Import → URL** and paste the raw egg JSON URL, e.g.:

```
https://raw.githubusercontent.com/snxRCS/pelican-eggs/main/voice/TS6-Manager-EGG/egg-teamspeak6-manager.json
```

Then create a server that uses it — Pelican pulls the GHCR image automatically.

## Repo layout

```
pelican-eggs/
├── .github/workflows/       # GitHub Actions that build + push images to GHCR
├── images/                  # Dockerfiles + companion files for each prebuilt yolk image
│   └── ts6-manager/
│       ├── Dockerfile
│       ├── start.sh
│       ├── proxy.cjs
│       └── proxy-package.json
└── voice/                   # Egg category
    └── TS6-Manager-EGG/
        ├── egg-teamspeak6-manager.json
        ├── install.sh          # what goes into scripts.installation.script
        └── README.md
```

Keep the egg JSON, `install.sh`, and the image files in sync: a change in `images/<name>/` triggers a rebuild; a change in the egg JSON's `docker_images` needs to match the new image tag.

## Private deployments

If a GHCR package is set to private visibility, each Wings node must authenticate once so Docker can pull the image:

```bash
echo <PAT-with-read:packages> | docker login ghcr.io -u <username> --password-stdin
```

The PAT only needs the `read:packages` scope. Without this step, install will fail with `unauthorized: authentication required` on first image pull.


## License

MIT. Individual upstream projects retain their own licenses.
