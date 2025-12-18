# Documentation

This folder collects the guides referenced throughout the project. Start here to
decide which workflow-specific document you need.

## Available Guides

- VS Code Dev Container guide:
  - [English](vscode-devcontainer-usage.md)
  - [日本語](vscode-devcontainer-usage_ja.md)
  Step-by-step instructions for creating the `.devcontainer` configuration,
  opening the workspace in VS Code, troubleshooting port forwarding, and
  rebuilding containers from the editor.

- Docker Compose guide:
  - [English](docker-compose-usage.md)
  - [日本語](docker-compose-usage_ja.md)
  CLI-focused guide that explains how to generate `.env`, start/stop the stack,
  pick Selkies/KasmVNC/noVNC modes, configure GPU options, and resolve common
  Compose issues when running outside VS Code.

## Conventions

- English documentation lives in `README.md` files; Japanese translations use
  the `_ja` suffix.
- Keep command snippets shell-ready and prefer fenced code blocks.
- When updating workflow steps, please reflect the change in both languages.

For high-level project information, refer to the repository root `README.md`.
