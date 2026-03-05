# OpenClaw on DigitalOcean App Platform

Deploy [OpenClaw](https://github.com/openclaw/openclaw) - a multi-channel AI messaging gateway - on DigitalOcean App Platform in minutes.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/digitalocean-labs/openclaw-appplatform/tree/main)

## Quick Start: Choose Your Stage

| Stage                      | What You Get            | Access Method                    |
|----------------------------|-------------------------|----------------------------------|
| **1. App Platform Service**| Gateway + Web UI + URL  | Stable `*.ondigitalocean.app` URL|
| **2. + Tailscale**         | Private Network         | Tailscale hostname               |
| **+ Persistence**          | Data survives restarts  | DO Spaces                        |

**Start simple, add features as needed.** Most users deploy as an App Platform service (Stage 1) for the easiest setup with a stable URL.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                      openclaw-appplatform                           │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ s6-overlay - Process supervision and init system             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌─────────────┐  ┌───────────────────┐                            │
│  │ Ubuntu      │  │ OpenClaw Gateway  │                            │
│  │ Noble+Node  │  │ WebSocket :8080   │                            │
│  │ + nvm       │  │ + Control UI      │                            │
│  └─────────────┘  └───────────────────┘                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Access Layer:                                                │  │
│  │  • App Platform service (default) - stable *.ondigitalocean  │  │
│  │    .app URL, no tunnel needed                                │  │
│  │  • Tailscale (TAILSCALE_ENABLE) - Private network            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Optional: SSH Server (SSH_ENABLE=true)                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │ WhatsApp │        │ Telegram │        │ Discord  │
   │ Signal   │        │ Slack    │        │ MS Teams │
   │ iMessage │        │ Matrix   │        │ + more   │
   └──────────┘        └──────────┘        └──────────┘
```

---

## Stage 1: App Platform Service (Recommended)

Deploy as an App Platform **service** to get a stable public URL with no tunneling required. This is the recommended setup.

### Deploy

```bash
# Clone the repo
git clone https://github.com/digitalocean-labs/openclaw-appplatform
cd openclaw-appplatform

# Deploy (creates the app with a stable URL)
doctl apps create --spec app.yaml
```

### Important: Deploying Code Changes

When you push code changes, App Platform with `git` source may reuse a cached build. To force a fresh build from the latest commit:

```bash
# Get your app ID
doctl apps list

# Force rebuild from latest commit
doctl apps create-deployment <app-id> --force-rebuild
```

**Note:** Spec-only updates (`doctl apps update`) do NOT rebuild the image — they reuse the cached build. Always use `--force-rebuild` after pushing code changes.

### Get Your URL

After deployment, your app gets a stable URL:

```
https://openclaw-<name>-<hash>.ondigitalocean.app
```

Find it in the DigitalOcean dashboard under your app's overview page, or:

```bash
doctl apps list --format ID,DefaultIngress
```

### Connect via Console

```bash
doctl apps console <app-id> openclaw

# Verify gateway is running
openclaw gateway health --url ws://127.0.0.1:8080

# Check channel status
openclaw channels status --probe
```

### What's Included

- ✅ OpenClaw gateway (HTTP on port 8080)
- ✅ Web Control UI with stable public URL
- ✅ CLI access via `openclaw` command
- ✅ All channel plugins (WhatsApp, Telegram, Discord, etc.)
- ✅ HTTPS with auto-managed TLS certificate
- ❌ Data lost on restart (add Spaces for persistence)

---

## Stage 2: Production with Tailscale

Private network access via your Tailscale tailnet. **Recommended for production.**

### Get Tailscale Auth Key

See [Setting up Tailscale](#setting-up-tailscale) for a detailed walkthrough with screenshots.

1. Go to <https://login.tailscale.com/admin/settings/keys>
2. Generate a reusable auth key

### Deploy

Update `app.yaml`:

```yaml
instance_size_slug: apps-s-1vcpu-2gb  # 1 CPU, 2GB

envs:
  - key: ENABLE_NGROK
    value: "false"
  - key: TAILSCALE_ENABLE
    value: "true"
  - key: TS_AUTHKEY
    type: SECRET
  - key: STABLE_HOSTNAME
    value: openclaw
```

### Access

```
https://openclaw.<your-tailnet>.ts.net
```

### What's Added

- ✅ Everything from Stage 1
- ✅ Stable hostname on your tailnet
- ✅ Private access (only your devices)
- ✅ Production-grade security
- ❌ Data lost on restart (add Spaces for persistence)

---

## Setting up Tailscale

This section walks you through creating a Tailscale auth key for your OpenClaw deployment.

### 1. Sign in to Tailscale

Go to <https://login.tailscale.com> and sign in with your preferred identity provider (Google, Microsoft, GitHub, etc.).

### 2. Access the Admin Console

Once signed in, you'll be taken to the Tailscale admin console. This is where you manage your tailnet (your private network).

### 3. Navigate to Auth Keys

1. Click **Settings** in the left sidebar
2. Click **Keys** under the Personal Settings section
3. Or go directly to <https://login.tailscale.com/admin/settings/keys>

<!-- Screenshot: Settings > Keys navigation -->

### 4. Generate an Auth Key

1. Click **Generate auth key**
2. Configure the key settings:
   - **Reusable**: Enable this so the key can be used if the container restarts
   - **Ephemeral**: Optional - nodes using this key will be automatically removed when they go offline
   - **Tags**: Optional - apply ACL tags to control access
   - **Expiration**: Choose an appropriate expiration (default is 90 days)

![Tailscale Auth Key Settings](ts-auth-key.png)

### 5. Copy Your Auth Key

After clicking **Generate key**, your auth key will be displayed. Copy it immediately as it won't be shown again.

The key format looks like: `tskey-auth-xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxx`

### 6. Add the Key to Your Deployment

Set the `TS_AUTHKEY` environment variable in your `app.yaml` or in the DigitalOcean dashboard:

```yaml
envs:
  - key: TS_AUTHKEY
    type: SECRET
    value: "tskey-auth-xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### 7. Verify the Connection

After deploying, your OpenClaw instance will appear in the **Machines** tab of your Tailscale admin console.

You can access your instance at:
```
https://<hostname>.<your-tailnet>.ts.net
```

---

## Adding Persistence (Any Stage)

Without persistence, all data is lost when the container restarts. Add DO Spaces to preserve:

- Channel sessions (WhatsApp linking, etc.)
- Configuration changes
- Memory/search index
- Tailscale state

### Setup DO Spaces

1. **Create a Spaces bucket** in the same region as your app
   - Go to **Spaces Object Storage** → **Create Bucket**

2. **Create access keys**
   - Go to **API** → **Spaces Keys** → **Generate New Key**

3. **Update app.yaml**:

```yaml
envs:
  - key: ENABLE_SPACES
    value: "true"
  - key: RESTIC_SPACES_ACCESS_KEY_ID
    type: SECRET
  - key: RESTIC_SPACES_SECRET_ACCESS_KEY
    type: SECRET
  - key: RESTIC_SPACES_ENDPOINT
    value: tor1.digitaloceanspaces.com  # Match your region
  - key: RESTIC_SPACES_BUCKET
    value: openclaw-backup
  - key: RESTIC_PASSWORD
    type: SECRET
```

### What Gets Persisted

The backup system uses [Restic](https://restic.net/) for incremental, encrypted snapshots to DigitalOcean Spaces.

| Path              | Contents                                         | Backup Frequency         |
|-------------------|--------------------------------------------------|--------------------------|
| `/data/.openclaw` | Gateway config, channel sessions, agents, memory | Every 30s (configurable) |
| `/data/tailscale` | Tailscale connection state (persistent device)   | Every 30s                |
| `/etc`            | System configuration                             | Every 30s                |
| `/home`           | User files, Homebrew packages                    | Every 30s                |
| `/root`           | Root user data                                   | Every 30s                |

**Automatic Restore:**
- On container restart, `10-restore-state` init script automatically restores the latest snapshot for each path
- Restores are fast and incremental
- Data survives deployments, restarts, and instance replacements

**Repository Management:**
- Old snapshots are automatically pruned every hour
- Repository is encrypted with `RESTIC_PASSWORD`
- Stored in: `s3:<endpoint>/<bucket>/<hostname>/restic`

**Configuration File:**
Backup behavior is controlled by `/etc/digitalocean/backup.yaml`:
- **Backup paths**: What directories to back up
- **Exclusions**: Files to skip (*.lock, *.pid, *.sock)
- **Intervals**: Backup frequency (default: 30s), prune frequency (default: 1h)
- **Retention policy**: How many snapshots to keep (last 10, hourly 48, daily 30, etc.)

To customize, create `rootfs/etc/digitalocean/backup.yaml` in your repo and rebuild.

---

## AI-Assisted Setup

Want an AI assistant to help deploy and configure OpenClaw? See **[AI-ASSISTED-SETUP.md](AI-ASSISTED-SETUP.md)** for:

- Copy-paste prompts for each stage
- WhatsApp channel setup (with QR code handling)
- Verification steps
- Works with Claude Code, Cursor, Codex, Gemini, etc.

---

## CLI Cheat Sheet

The `openclaw` command is a wrapper that runs openclaw with the correct user and environment. **Always use `openclaw` in console sessions.**

```bash
# Gateway
openclaw gateway health --url ws://127.0.0.1:8080
openclaw gateway status

# Channels
openclaw channels status --probe
openclaw channels login                    # WhatsApp QR code

# Messages
openclaw message send --channel whatsapp --target "+1234567890" --message "Hello!"

# Services
/command/s6-svc -r /run/service/openclaw    # Restart
/command/s6-svc -r /run/service/ngrok      # Restart ngrok

# Logs
tail -f /data/.openclaw/logs/gateway.log

# Config
cat /data/.openclaw/openclaw.json | jq .
```

See **[CHEATSHEET.md](CHEATSHEET.md)** for the complete reference.

---

## Environment Variables

### Required

| Variable                 | Description                         |
|--------------------------|-------------------------------------|
| `OPENCLAW_GATEWAY_TOKEN` | Password for web setup wizard       |
| `STABLE_HOSTNAME`        | A stable hostname for this instance |

### Feature Flags

| Variable             | Default | Description                  |
|----------------------|---------|------------------------------|
| `TAILSCALE_ENABLE`   | `false` | Enable Tailscale             |
| `ENABLE_SPACES`      | `false` | Enable DO Spaces persistence |
| `ENABLE_UI`          | `true`  | Enable web Control UI        |
| `SSH_ENABLE`         | `false` | Enable SSH server            |
| `ENABLE_NGROK`       | `false` | Enable ngrok tunnel (legacy) |

### Tailscale (when TAILSCALE_ENABLE=true)

| Variable     | Description        |
|--------------|--------------------|
| `TS_AUTHKEY` | Tailscale auth key |

### Spaces (when ENABLE_SPACES=true)

| Variable                          | Description                         |
|-----------------------------------|-------------------------------------|
| `RESTIC_SPACES_ACCESS_KEY_ID`     | Spaces access key                   |
| `RESTIC_SPACES_SECRET_ACCESS_KEY` | Spaces secret key                   |
| `RESTIC_SPACES_ENDPOINT`          | e.g., `tor1.digitaloceanspaces.com` |
| `RESTIC_SPACES_BUCKET`            | Your bucket name                    |
| `RESTIC_PASSWORD`                 | Backup encryption password          |

### Optional

| Variable                 | Description                                    |
|--------------------------|------------------------------------------------|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token (auto-generated if not set) |
| `GRADIENT_API_KEY`       | DigitalOcean Gradient AI key                   |
| `GITHUB_USERNAME`        | For SSH key fetching                           |

---

## Customization (s6-overlay)

The container uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision.

### Dynamic MOTD

On login, you'll see a colorful status display. Run `motd` anytime to refresh.

| Section      | Info                                               |
|--------------|----------------------------------------------------|
| 🖥️ System   | Hostname, uptime, load, memory, disk (color-coded) |
| 🔗 Tailscale | Status, IP, relay, serve URL (if enabled)          |
| 🦞 OpenClaw  | Health status, configured channels, agent count    |
| 📚 Links     | OpenClaw docs, App Platform docs, source repo      |

### Add Custom Init Scripts

Create `rootfs/etc/cont-init.d/30-my-script`:

```bash
#!/command/with-contenv bash
echo "Running my custom setup..."
```

### Add Custom Services

Create `rootfs/etc/services.d/my-daemon/run`:

```bash
#!/command/with-contenv bash
exec my-daemon --foreground
```

### Built-in Services

| Service     | Description                                              |
|-------------|----------------------------------------------------------|
| `openclaw`  | OpenClaw gateway                                         |
| `ngrok`     | ngrok tunnel (if enabled)                                |
| `tailscale` | Tailscale daemon (if enabled)                            |
| `backup`    | Restic backup service - creates snapshots (if enabled)   |
| `prune`     | Restic prune service - cleans old snapshots (if enabled) |
| `crond`     | Cron daemon for scheduled tasks                          |
| `sshd`      | SSH server (if enabled)                                  |

---

## Available Regions

| Code  | Location          |
|-------|-------------------|
| `nyc` | New York          |
| `atl` | Atlanta           |
| `ams` | Amsterdam         |
| `sfo` | San Francisco     |
| `sgp` | Singapore         |
| `lon` | London            |
| `fra` | Frankfurt         |
| `blr` | Bangalore         |
| `syd` | Sydney            |
| `tor` | Toronto (default) |

---

## Documentation

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [DigitalOcean App Platform](https://docs.digitalocean.com/products/app-platform/)
- [AI-Assisted Setup Guide](AI-ASSISTED-SETUP.md)
- [CLI Cheat Sheet](CHEATSHEET.md)

---

## License

MIT
