#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <windows-user>@<windows-host>

Example:
  $0 alice@windows-laptop.local

This script installs the Docker CLI on macOS, removes Docker Desktop if present,
creates a remote Docker context that connects to your Windows laptop via SSH,
and configures your Mac to use that remote Docker host.

Prerequisites:
  - Homebrew installed on macOS
  - OpenSSH server running on the Windows laptop
  - Docker available on the Windows laptop

Tip: If your Windows machine doesn't have a .local DNS name, use its IP address
instead (e.g., Dell@192.168.1.18). Run 'ipconfig' on Windows to find the IPv4 address.
EOF
}

REMOTE_SSH="${1:-}"

if [[ -z "$REMOTE_SSH" ]]; then
  usage
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is required. Install Homebrew first: https://brew.sh"
  exit 1
fi

if command -v docker >/dev/null 2>&1 && [[ -d "/Applications/Docker.app" ]]; then
  echo "Stopping Docker Desktop if it is running..."
  osascript -e 'tell application "Docker" to quit' >/dev/null 2>&1 || true
fi

if [[ -d "/Applications/Docker.app" ]]; then
  echo "Removing Docker Desktop application files..."
  rm -rf "/Applications/Docker.app"
fi

if brew list --cask docker >/dev/null 2>&1; then
  echo "Uninstalling Docker Desktop cask..."
  brew uninstall --cask docker >/dev/null 2>&1 || true
fi

if [[ -d "$HOME/.docker" ]]; then
  echo "Removing old Docker Desktop settings..."
  rm -rf "$HOME/.docker"
fi

if [[ -d "$HOME/Library/Group Containers/group.com.docker" ]]; then
  echo "Removing Docker Group Containers (may require manual cleanup)..."
  rm -rf "$HOME/Library/Group Containers/group.com.docker" 2>/dev/null || echo "  Skipped (permission denied - manually remove via Finder if needed)"
fi

if [[ -f "/usr/local/bin/docker" ]] || [[ -f "/usr/local/bin/docker-compose" ]]; then
  echo "Removing old docker symlinks from /usr/local/bin..."
  rm -f /usr/local/bin/docker /usr/local/bin/docker-compose /usr/local/bin/docker-credential-osxkeychain || true
fi

echo "Installing Docker CLI tools via Homebrew..."
brew install docker docker-compose docker-buildx

CONTEXT_NAME="windows-remote"

if docker context ls --format '{{.Name}}' | grep -x "$CONTEXT_NAME" >/dev/null 2>&1; then
  echo "Updating existing Docker context '$CONTEXT_NAME'..."
  docker context update "$CONTEXT_NAME" --docker "host=ssh://$REMOTE_SSH"
else
  echo "Creating Docker context '$CONTEXT_NAME'..."
  docker context create "$CONTEXT_NAME" --description "Remote Docker on Windows laptop" --docker "host=ssh://$REMOTE_SSH"
fi

echo "Switching to Docker context '$CONTEXT_NAME'..."
docker context use "$CONTEXT_NAME"

cat <<EOF

Setup complete.

Next steps:
  1. Verify the remote connection:
       docker info
  2. Run a quick build/test:
       docker run --rm hello-world

If SSH keys are required, add them to your Mac SSH agent and make sure the Windows
user accepts your public key in ~/.ssh/authorized_keys on the Windows machine.

To switch back to the local Docker CLI in future, run:
  docker context use default
EOF
