# Agents

## Project overview

Ansible project that provisions AI agent servers on ARM64 Ubuntu Server VMs managed by [lume](https://github.com/trycua/lume). Currently manages two servers: **helios** (OpenClaw gateway) and **athena** (Claude Code server).

## Structure

```
playbooks/
  deploy-openclaw.yml     # OpenClaw deployment (openclaw_servers)
  deploy-claude.yml       # Claude server deployment (claude_servers)
roles/
  debian/                 # Base packages, SSH, GitHub CLI, service user creation, unattended-upgrades
  security/               # SSH hardening, UFW firewall (rate-limited SSH, deny-by-default), fail2ban
  docker/                 # Rootless Docker (per-user daemon, no root access)
  openclaw/               # Daemon setup, Discord integration, env vars
  tailscale/              # Tailnet join, firewall rules, binary permissions
  mise/                   # Runtime installer (Node, Python, Go, bun, etc.)
  claude/                 # Claude Code, Discord plugin, sudoers, systemd, SSH/GitHub, tmux helper
vars/
  common.yml              # Shared variables
  vault.yml               # Encrypted secrets (ansible-vault)
inventory/hosts.yml       # Host definitions with per-host variables
scripts/
  setup-vm.sh             # Idempotent lume VM creation script
```

## Key conventions

- Two playbooks: `deploy-openclaw.yml` for openclaw_servers, `deploy-claude.yml` for claude_servers
- System-level tasks run as root (`become: true` at play level)
- Host variables use vault-backed defaults: `openclaw_default_user` / `claude_default_user` for all role user params
- The `debian` role creates the service user (skips if already exists), installs base packages including `gh`, and configures SSH + unattended-upgrades
- The `security` role hardens SSH (key-only auth, no root login), rate-limits SSH via UFW, and configures fail2ban (24h bans, progressive)
- The `docker` role runs Docker in rootless mode under the service user — no docker group escalation
- The `claude` role manages scoped sudoers (claude-code.service only), Claude Code install, Discord plugin, systemd service template, SSH/GitHub keys, mise/env activation in bashrc, and a `start-claude` tmux helper function
- Secrets are stored in `vars/vault.yml` and encrypted with `ansible-vault`
- Discord bot tokens are per-host: defined as `helios_bot_token` / `athena_bot_token` in vault, mapped to `discord_bot_token` per-host in inventory
- Git user credentials for athena are stored in vault (`athena_git_user_name`, `athena_git_user_email`), mapped to `git_user_name`/`git_user_email` per-host
- SSH keys for GitHub access are generated on-server (never committed) — managed by the `claude` role
- The systemd service unit for claude-code is a Jinja2 template (`roles/claude/templates/claude-code.service.j2`)
- All tasks must be idempotent — safe to re-run without side effects
- VM creation via `scripts/setup-vm.sh` is idempotent — skips if VM already exists

## Secrets

Sensitive values use `no_log: true` and file mode `0600`. Always run `make encrypt` after editing `vars/vault.yml`.

This repo is public — never commit plaintext secrets. Host IPs, tokens, and auth keys go in the encrypted vault.
