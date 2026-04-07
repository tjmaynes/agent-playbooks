#!/usr/bin/env bash

set -euo pipefail

check_requirements() {
  if ! command -v orbctl &>/dev/null; then
    echo "Error: OrbStack CLI not found."
    echo "Install from: https://orbstack.dev"
    exit 1
  fi
}

usage() {
  echo "Usage: $0 [--arch <arm64|amd64>] [--distro <name:version>] [--user <username>]"
  echo ""
  echo "Create or select an OrbStack Linux machine for provisioning."
  echo "Lists existing machines and lets you pick one, or create a new one."
  echo ""
  echo "Options:"
  echo "  --arch <arch>          CPU architecture (default: arm64)"
  echo "  --distro <name:ver>    Distribution (default: ubuntu)"
  echo "  --user <username>      Default user for the machine"
  echo "  -h, --help             Show this help message"
}

select_or_create() {
  local arch="$1"
  local distro="$2"
  local user_flag="$3"

  # Parse machine names from orbctl list output
  local -a names=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local name
    name=$(echo "$line" | awk '{print $1}')
    names+=("$name")
  done < <(orbctl list 2>/dev/null || true)

  if [[ ${#names[@]} -gt 0 ]]; then
    echo ""
    echo "=== Existing OrbStack machines ==="
    echo ""
    for i in "${!names[@]}"; do
      local info
      info=$(orbctl list 2>/dev/null | grep "^${names[$i]} ")
      printf "  %d) %s\n" $((i + 1)) "$info"
    done
    echo ""
    printf "  N) Create a new machine\n"
    echo ""
    read -rp "Choice [1-${#names[@]}/N]: " choice
  else
    echo ""
    echo "No existing OrbStack machines found."
    choice="N"
  fi

  if [[ "$choice" =~ ^[Nn]$ ]]; then
    read -rp "Machine name: " machine_name
    if [[ -z "$machine_name" ]]; then
      echo "Error: machine name is required."
      exit 1
    fi

    echo "Creating '$machine_name' (distro=$distro, arch=$arch)..."
    local create_args=(-a "$arch")
    if [[ -n "$user_flag" ]]; then
      create_args+=(-u "$user_flag")
    fi

    orbctl create "${create_args[@]}" "$distro" "$machine_name"
    echo ""
    echo "Machine '$machine_name' created and running."
    orbctl info "$machine_name"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#names[@]} )); then
    local machine_name="${names[$((choice - 1))]}"

    local state
    state=$(orbctl info "$machine_name" -f json 2>/dev/null | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ "$state" != "running" ]]; then
      echo "Starting '$machine_name'..."
      orbctl start "$machine_name"
    fi

    echo ""
    echo "Machine '$machine_name' is ready."
    orbctl info "$machine_name"
  else
    echo "Invalid choice."
    exit 1
  fi
}

main() {
  local arch="arm64"
  local distro="ubuntu"
  local user_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --arch)
        arch="$2"
        shift 2
        ;;
      --distro)
        distro="$2"
        shift 2
        ;;
      --user)
        user_flag="$2"
        shift 2
        ;;
      *)
        echo "Error: unknown option '$1'"
        usage
        exit 1
        ;;
    esac
  done

  check_requirements
  select_or_create "$arch" "$distro" "$user_flag"
}

main "$@"
