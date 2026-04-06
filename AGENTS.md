# Agents

## Project overview

Ansible project that provisions Hermes Agent servers on ARM64 Ubuntu Server VMs managed by [lume](https://github.com/trycua/lume). Currently manages two hosts: **rosie** and **athena**. A single playbook (`deploy.yml`) deploys to any host using `--limit`.

## Structure

```
playbooks/
  deploy.yml                # Hermes Agent deployment (all hosts)
  deploy.openclaw.example.yml  # OpenClaw deployment example (commented out)
  deploy.claude.example.yml    # Claude deployment example (commented out)
roles/
  debian/                 # Base packages, SSH, GitHub CLI, service user creation, unattended-upgrades, custom DNS, git config
    templates/
      resolved-custom.conf.j2  # systemd-resolved drop-in for split DNS
  security/               # SSH hardening, UFW firewall, fail2ban, custom CA certificate (system + Chromium NSS)
  docker/                 # Rootless Docker (per-user daemon, no root access), Honcho docker-compose
  mise/                   # Runtime installer (Node, Python, Go, bun, etc.)
  hermes/                 # Hermes Agent install, Playwright, Discord gateway, sudoers, systemd, .env, SSH/GitHub
vars/
  common.yml              # Shared variables and defaults
  vault.yml               # Encrypted secrets (ansible-vault)
inventory/hosts.yml       # Host definitions with per-host variables
scripts/
  setup-vm.sh             # Idempotent lume VM creation script
```

## Key conventions

- One playbook (`deploy.yml`) targets all hosts; use `--limit <host>` to deploy individually
- Hosts are defined flat under `all.hosts` in inventory — no group hierarchy needed
- Per-host variables (secrets, model config, optional features) are in inventory/vault; shared config (users, ports, API keys) is in play-level vars
- System-level tasks run as root (`become: true` at play level)
- The `debian` role creates the service user (skips if already exists), installs base packages including `gh`, configures SSH + unattended-upgrades, optionally configures custom DNS via `systemd-resolved` split DNS (when `custom_dns_server` is defined), and optionally sets git identity
- The `security` role hardens SSH (key-only auth, no root login), rate-limits SSH via UFW, configures fail2ban (24h bans, progressive), and optionally installs a custom CA certificate to the system trust store and Chromium NSS database (when `custom_ca_certificate_path` is defined)
- The `docker` role runs Docker in rootless mode under the service user — no docker group escalation. Also deploys Honcho (memory backend) via docker-compose template
- The `hermes` role manages scoped sudoers (hermes-gateway.service only), Hermes Agent install (official curl installer), Playwright browser install (`npx playwright install --with-deps`), Discord gateway config, `.env` file with per-host environment variables (including optional `GITHUB_TOKEN`, `HASS_URL`/`HASS_TOKEN`), systemd service via `hermes gateway install`, SSH/GitHub keys, mise/env activation in bashrc, and a `hermes-logs` helper function
- Secrets are stored in `vars/vault.yml` and encrypted with `ansible-vault`
- Discord bot tokens are per-host: defined as `rosie_bot_token` / `athena_bot_token` in vault, mapped to `discord_bot_token` per-host in inventory
- Optional features are conditionally enabled via `when: <var> is defined` — including custom CA certs, custom DNS, GitHub tokens, and Home Assistant integration
- SSH keys for GitHub access are generated on-server (never committed) — managed by the `hermes` role
- All tasks must be idempotent — safe to re-run without side effects
- VM creation via `scripts/setup-vm.sh` is idempotent — skips if VM already exists
- Named setup targets: `make setup_rosie` (4GB RAM, 60GB disk), `make setup_athena` (8GB RAM, 110GB disk)
- Generic setup: `make setup HOST=<name>` creates a VM with default 8GB RAM / 110GB disk

## Secrets

Sensitive values use `no_log: true` and file mode `0600`. Always run `make encrypt` after editing `vars/vault.yml`.

This repo is public — never commit plaintext secrets. Host IPs, tokens, and auth keys go in the encrypted vault.
