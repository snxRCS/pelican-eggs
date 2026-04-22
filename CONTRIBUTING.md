# Contributing

Thanks for your interest in contributing to this collection of Pelican Panel eggs.

## Adding a new egg

1. Fork the repo and create a feature branch.
2. 2. Place the egg JSON under the appropriate category directory, e.g. `voice/<egg-name>/egg-<name>.json`.
   3. 3. If the egg ships a pre-built Docker image, add the Dockerfile under `images/<name>/` and a matching workflow under `.github/workflows/` that builds and pushes to GHCR on `main`.
      4. 4. Reference the GHCR image in the egg's `docker_images` block.
         5. 5. Add a short entry to the "Available eggs" table in `README.md`.
           
            6. ## Coding style
           
            7. - Keep install scripts thin. Any heavy lifting belongs in the pre-built image so nodes only pull and run.
               - - Pin base image tags (`debian:bookworm-slim`, not `latest`) so builds stay reproducible.
                 - - `startup` in the egg should match a string the runtime actually prints on boot, so Pelican detects "running".
                  
                   - ## Opening a pull request
                  
                   - - Describe what the egg does, which upstream project it wraps, and any caveats (licensing, file uploads, etc.).
                     - - If the PR closes an issue, use `Closes #N` in the description.
                       - - Small focused PRs merge faster than big mixed ones.
                        
                         - ## License
                        
                         - By contributing you agree that your contributions are licensed under the repo's MIT license.
                         - 
