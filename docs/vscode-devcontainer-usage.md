# VS Code Dev Container Guide

This document walks through creating the Dev Container configuration, opening the workspace inside VS Code, and troubleshooting the desktop Web UI when using this repository.

## Prerequisites

- VS Code with the **Dev Containers** extension installed
- Docker + Docker Compose available on the host
- The user-specific image built via `./build-user-image.sh`

## Setup Workflow

### 1. Generate the Dev Container config

Use the interactive helper:

```bash
./create-devcontainer-config.sh
```

The script reuses `compose-env.sh` (the same logic as `start-container.sh`) to calculate environment variables and writes them into `.devcontainer/.env`. Before VS Code starts the container it runs `.devcontainer/sync-env.sh`, which copies this file to the workspace root so `docker compose` receives identical values whether you start the stack manually or through Dev Containers.

During generation you will be prompted for:

1. **GPU mode** – none / NVIDIA / Intel / AMD
2. **VNC type** – Selkies (WebRTC), KasmVNC, or noVNC
3. **TURN server** – enable only when you need remote Selkies/WebRTC access
4. **Display server** – Xorg or Xvfb
5. **Display settings** – resolution and refresh rate

Output files under `.devcontainer/`:

- `devcontainer.json`: main VS Code descriptor
- `docker-compose.override.yml`: workspace mount override
- `.env`: per-container environment produced by the script
- `README.md`: summary of the chosen options

### 2. Reopen the repo in the container

1. Open the folder in VS Code.
2. `F1` → "Dev Containers: Reopen in Container" (or use the status bar `><` icon).
3. VS Code builds the container, attaches, and runs the initialize/postCreate hooks.

### 3. Access the remote desktop

- The Web UI lives at `https://localhost:(10000 + UID)` (UID 1000 → 11000).
- Dev Containers forwards ports declared in `devcontainer.json`. Check the **Ports** panel and click "Open in Browser" to create the tunnel.
- Install the generated CA with `sudo ./install-ca-cert.sh` on any machine that opens the Web UI so HTTPS warnings disappear.

## Working inside the container

- **Terminal** – VS Code terminals run inside the container (`/home/<user>/workspace`).
- **Extensions** – declared under `devcontainer.json -> customizations.vscode.extensions` and installed automatically.
- **File sync** – the repo is bind-mounted; changes appear both on host and in container.

## Common issues

| Symptom | Fix |
| --- | --- |
| Web UI does not open on 11000 | Rebuild the Dev Container so `.devcontainer/sync-env.sh` re-copies `.env`, ensure `PULSE_SERVER=unix:/tmp/runtime-<user>/pulse/native`, and confirm port 11000 is forwarded. |
| GPU not detected | Re-run `./create-devcontainer-config.sh` with the desired GPU option, rebuild the Dev Container, and make sure the host user belongs to the `video`/`render` groups. |
| Environment changes ignored | After editing `.devcontainer/.env`, run `Dev Containers: Rebuild Container` so the new values sync into the runtime `.env`. |

## Resetting the Dev Container

Dev Containers reuse existing containers. To force a clean rebuild:

1. `F1` → "Dev Containers: Rebuild and Reopen in Container"
2. or run `Dev Containers: Reopen in Container` after deleting the previous container via Docker Desktop/CLI.

For CLI-only workflows, refer to `docs/docker-compose-usage.md`.
