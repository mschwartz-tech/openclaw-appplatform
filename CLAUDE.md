# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains the Docker configuration and deployment templates for running [OpenClaw](https://github.com/openclaw/openclaw) on DigitalOcean App Platform with Tailscale networking. It is not the OpenClaw application itself — it's the container packaging and infrastructure layer.

## Commands

```bash
# Local development
cp .env.example .env           # Configure environment variables (first time)
make rebuild                   # Build and start container (docker compose down + up --build)
make logs                      # Follow container logs
make shell                     # Shell into running container

# Testing
make test CONFIG=minimal       # Build, start, and test a specific config
make test CONFIG=ssh-enabled   # Test SSH configuration
make test-all                  # Run all configs in example_configs/

# Inside the container
/command/s6-svc -r /run/service/openclaw      # Restart OpenClaw service
/command/s6-svc -r /run/service/<name>        # Restart any service (tailscale, etc.)
/command/s6-svstat /run/service/<name>        # Check service status
```

## Architecture

**Container structure:** Ubuntu Noble base image with s6-overlay for process supervision. The entrypoint is `/init` (s6-overlay), which runs init scripts in order, then starts supervised services.

**Boot sequence:**
1. Init scripts (`rootfs/etc/cont-init.d/`) run in numeric order (00→99999)
2. `20-setup-openclaw` builds `openclaw.json` from env vars and the default template (`rootfs/etc/openclaw/openclaw.default.json`)
3. Services (`rootfs/etc/services.d/*/run`) start under s6 supervision
4. Services that aren't enabled exit immediately (checked via env vars like `TAILSCALE_ENABLE`, etc.)

**Key runtime paths (inside container):**
- `/data/.openclaw/openclaw.json` — generated gateway config (preserved across restarts if backup enabled)
- `/data/.openclaw/` — all gateway state (sessions, agents, memory)
- `/run/s6/container_environment/` — s6 environment variable store
- `/etc/s6-overlay/lib/env-utils.sh` — shared shell library for env persistence (`persist_env_var`, `source_env_prefix`, `with_env_prefix`, `apply_permissions`)

**Shared library (`rootfs/etc/s6-overlay/lib/env-utils.sh`):** All init scripts and service run scripts source this. It provides `persist_env_var` (write vars to s6 env store), `source_env_prefix` (load vars by prefix), `with_env_prefix` (exec with filtered env), and `apply_permissions` (apply ownership/mode from `permissions.yaml`).

**Config generation (`20-setup-openclaw`):** Copies the default JSON template to the state dir, then layers on jq transformations based on env vars (Tailscale serve mode, UI toggle, auth token). If a config already exists (e.g. restored from backup), it is preserved — delete it to regenerate from defaults.

## Testing

Tests use a config-matrix approach. Each test configuration is an `.env` file in `example_configs/` with a matching test directory in `tests/<config-name>/`.

**Test configs:** `minimal`, `ssh-enabled`, `ssh-and-ui`, `ui-disabled`, `all-optional-disabled`, `persistence-enabled`

**Writing tests:**
- Add `example_configs/<name>.env` with `STABLE_HOSTNAME=<name>`
- Create executable `.sh` scripts in `tests/<name>/` with numeric prefixes for ordering
- Scripts receive the container name as `$1`
- Use helpers from `tests/lib.sh`: `wait_for_container`, `wait_for_service`, `assert_service_up`, `assert_service_down`, `assert_process_running`, `assert_process_not_running`

**CI** (`.github/workflows/test.yml`): Build → Setup (per config) → Scenario (per script). Each test script runs as a separate CI job.

## Gotchas

- **Use `openclaw` wrapper in console sessions** — The wrapper in `/usr/local/bin/openclaw` runs commands as the correct user with proper environment. Running the binary directly as root won't work.
- **s6 commands not in PATH** — Use full paths: `/command/s6-svc`, `/command/s6-svok`, `/command/s6-svstat`
- **Don't push-to-deploy for development** — Make changes inside the container and restart the service with `/command/s6-svc -r /run/service/openclaw`
- **Networking** — By default (App Platform mode), gateway binds to `0.0.0.0:8080` and is exposed via App Platform's built-in HTTP routing. When Tailscale is enabled, it binds to `127.0.0.1` and Tailscale serve handles external access. Note: OpenClaw expects IP addresses for `gateway.bind` (e.g. `"0.0.0.0"`, `"127.0.0.1"`), not symbolic names like `"all"` or `"loopback"`.
- **Config preservation** — If `openclaw.json` already exists at startup (e.g. restored from backup), `20-setup-openclaw` will not overwrite it. Delete the file to regenerate.
- **See `CHEATSHEET.md`** for detailed command reference and troubleshooting
