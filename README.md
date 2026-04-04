# agent-server

> AI agent servers running on ARM64 Ubuntu Server VMs, provisioned via Ansible and managed by [lume](https://github.com/trycua/lume).

## Servers

| Name | Group | Roles | Purpose |
|------|-------|-------|---------|
| **helios** | `openclaw_servers` | openclaw.installer, debian, tailscale, mise, openclaw | OpenClaw personal assistant gateway with Discord integration |
| **athena** | `claude_servers` | debian, security, docker, mise, claude | Claude Code server with Discord integration |

## Requirements

- [Python 3](https://www.python.org/)
- [lume](https://github.com/trycua/lume) (macOS VM manager)
- [Ubuntu Server ARM64 ISO](https://ubuntu.com/download/server/arm)

## Getting Started

### 1. Create VMs

```bash
make setup_helios    # Create helios VM (4GB RAM, 60GB disk)
make setup_athena    # Create athena VM (8GB RAM, 110GB disk)
make setup           # Create both
```

This runs `scripts/setup-vm.sh` which creates the lume VM and boots the Ubuntu installer. The script is idempotent — it skips creation if the VM already exists.

### 2. Install Ansible and dependencies

```bash
make install
```

### 3. Configure secrets

```bash
make decrypt
# Edit vars/vault.yml with real values
make encrypt
```

### 4. Deploy

```bash
make deploy_openclaw # Deploy OpenClaw (helios)
make deploy_claude   # Deploy Claude server (athena)
make deploy          # Deploy both
```

### 5. Post-deploy

On first deploy, the claude role generates an SSH key for its service user and prints the public key. Add it to the appropriate GitHub account under Settings > SSH and GPG keys.

### 6. Start Claude Code (athena)

Start a Claude Code session with Discord integration:

```bash
make connect_athena
# Then inside the tmux session:
start-claude
```

Or as a one-liner:

```bash
ssh -t athena "sudo -iu claude start-claude"
```

### 7. Discord bot setup (athena)

The Claude Code server on athena uses the [Discord plugin](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/discord/README.md). After deploy, complete these one-time steps:

**a. Create a Discord application and bot**

Go to the [Discord Developer Portal](https://discord.com/developers/applications) and click **New Application**. Navigate to **Bot**, give it a username, then scroll to **Privileged Gateway Intents** and enable **Message Content Intent**.

**b. Generate a bot token**

On the **Bot** page, click **Reset Token** and copy it. Store it in `vars/vault.yml` as `athena_bot_token`, then run `make encrypt`.

**c. Invite the bot to a server**

Navigate to **OAuth2** > **URL Generator**. Select the `bot` scope and enable these permissions:
- View Channels
- Send Messages
- Send Messages in Threads
- Read Message History
- Attach Files
- Add Reactions

Set integration type to **Guild Install**, copy the generated URL, and add the bot to your server.

**d. Deploy and start**

```bash
make deploy_claude
ssh -t athena "sudo -iu claude start-claude"
```

**e. Pair your Discord account**

DM your bot on Discord — it replies with a pairing code. In the Claude Code session on athena:

```
/discord:access pair <code>
```

**f. Lock down access**

Once paired, switch to allowlist mode so strangers can't trigger pairing:

```
/discord:access policy allowlist
```

## Available Commands

| Command | Purpose |
|---|---|
| `make install` | Install Ansible, ansible-lint, and collections |
| `make setup_helios` | Create helios VM |
| `make setup_athena` | Create athena VM |
| `make setup` | Create both VMs |
| `make deploy_openclaw` | Deploy OpenClaw to helios |
| `make deploy_claude` | Deploy Claude server to athena |
| `make deploy` | Deploy both servers |
| `make check` | Dry-run to preview changes |
| `make lint` | Lint playbooks and roles |
| `make encrypt` | Encrypt the vault file |
| `make decrypt` | Decrypt the vault file |
| `make start_helios` | Start Helios VM |
| `make start_athena` | Start Athena VM |
| `make connect_athena` | SSH into athena as claude user in tmux |

## Architecture

Two playbooks provision different server groups:

**`playbooks/deploy-openclaw.yml`** (openclaw_servers — helios):
1. **`openclaw.installer.openclaw`** — official collection handling Node.js, pnpm, Docker, OpenClaw, systemd, UFW, fail2ban, and unattended-upgrades
2. **`debian`** — base packages (including `gh`), SSH server, service user creation, timezone, unattended-upgrades
3. **`tailscale`** — joins the VM to a Tailscale tailnet and locks down access
4. **`mise`** — installs polyglot runtimes (Node, Python, Go, direnv, just)
5. **`openclaw`** — configures the daemon, Discord integration, and environment variables

**`playbooks/deploy-claude.yml`** (claude_servers — athena):
1. **`debian`** — base packages (including `gh`), SSH server, service user creation, timezone, unattended-upgrades
2. **`security`** — SSH hardening (key-only, no root login), UFW firewall (rate-limited SSH, deny-by-default), fail2ban (24h progressive bans)
3. **`docker`** — rootless Docker running under the service user (no docker group escalation)
4. **`mise`** — installs runtimes including bun (configured per-host)
5. **`claude`** — scoped sudoers, Claude Code install, Anthropic plugin marketplace, Discord plugin, systemd service template, mise/env activation in bashrc, `start-claude` tmux helper, and SSH-based GitHub access

Roles are parameterized via host variables in `inventory/hosts.yml`. User variables reference vault-backed defaults (`openclaw_default_user` / `claude_default_user`). Discord bot tokens and git credentials are per-host, mapped from vault variables.
