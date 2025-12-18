# Docker Compose Usage Guide

This guide mirrors what `start-container.sh` does, but with plain `docker compose` commands. The helper script `compose-env.sh` computes the same environment variables and writes them into `.env`, so Selkies, KasmVNC, and noVNC behave identically whether you launch from CLI, VS Code, or the provided scripts.

## Prerequisites

- Docker + Docker Compose installed
- User image already built via `./build-user-image.sh`

## Reproducing the default setup

1. Generate the environment variables using the same flags you would give `start-container.sh`.
2. Either keep them in the current shell or write them to `.env`, then run `docker compose -f docker-compose.user.yml up -d` from the repo root.

> When `.env` exists, Docker Compose loads it automatically—no need for `--env-file`.

## Basic workflow

### 1. Generate environment variables

```bash
# Example 1: export into the current shell
source <(./compose-env.sh --gpu nvidia --all --vnc-type selkies)

# Example 2: persist into .env
./compose-env.sh --gpu intel --vnc-type kasm --env-file .env
```

### 2. Start the stack

```bash
# Detached
docker compose -f docker-compose.user.yml up -d

# Attach logs
docker compose -f docker-compose.user.yml up
```

### 3. Stop / clean up

```bash
# Stop services
docker compose -f docker-compose.user.yml stop

# Remove containers (volumes remain)
docker compose -f docker-compose.user.yml down
```

## Selecting GPU & VNC modes

Use the helper to pick the combination you need:

```bash
# NVIDIA + Selkies
./compose-env.sh --gpu nvidia --all --vnc-type selkies --env-file .env

# Intel + KasmVNC
./compose-env.sh --gpu intel --vnc-type kasm --env-file .env

# Software rendering + noVNC
./compose-env.sh --gpu none --vnc-type novnc --env-file .env
```

Relevant ports (host side):

- Web UI: `10000 + UID` (example: UID 1000 → 11000)
- Selkies TURN: `13000 + UID`
- Selkies UDP range: `40000 + (UID-1000)*200` .. `+100`
- KasmVNC extras: WebSocket 6900+, kclient 3000+, audio 4900+, nginx 12000+ (add `UID % 1000`)

## Troubleshooting

- **KasmVNC port 11000 unavailable**: regenerate `.env` with `--vnc-type kasm`, run `docker compose down && up -d`, then confirm inside the container that `PULSE_SERVER=unix:/tmp/runtime-<user>/pulse/native`.
- **Env changes ignored**: ensure you run `docker compose` from the same directory as `.env`, or re-source `compose-env.sh` before launching.
- **Container fails to start**: verify the user image exists (`docker images | grep devcontainer-ubuntu-egl-desktop-$(whoami)`); rebuild with `./build-user-image.sh` if missing.

For VS Code specific usage, refer to `docs/vscode-devcontainer-usage.md`.
