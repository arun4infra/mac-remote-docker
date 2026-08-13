# Remote Docker Setup: macOS client + Windows Docker host

This workspace contains helper scripts to configure a macOS machine to use a Windows laptop as the remote Docker host.

## Goals

- Keep macOS clean by uninstalling Docker Desktop on Mac
- Use Docker CLI on Mac only
- Run all Docker builds and workloads on Windows
- Connect from Mac to Windows using SSH and a Docker remote context

## Files

- `setup-mac-remote-docker.sh`: macOS setup script
- `setup-windows-docker.ps1`: Windows setup script

## Recommended workflow

1. On Windows, run PowerShell as Administrator:
   ```powershell
   .\setup-windows-docker.ps1 -WindowsUser Dell -WindowsHost winpc.local -InstallDockerDesktop -CreateFirewallRule
   ```
   Replace `Dell` and `winpc.local` with your actual Windows username and host/IP address.
2. On the Windows machine, ensure the SSH server is accepting your Mac login and the Docker Desktop engine is running. 
3. On macOS, run:
   ```bash
   ./setup-mac-remote-docker.sh <your-windows-user>@<windows-hostname-or-ip>
   ```
4. Verify with:
   ```bash
   docker info
   docker run --rm hello-world
   ```

## Notes

- `setup-mac-remote-docker.sh` uses Homebrew to install the Docker CLI.
- It removes Docker Desktop application files if present on macOS.
- `setup-windows-docker.ps1` installs OpenSSH Server and optionally installs Docker Desktop using winget.
- The Mac communicates with Windows using `ssh://` over the Docker context.

## Troubleshooting

- If SSH public key authentication is required, add your Mac public key to Windows `~/.ssh/authorized_keys`.
- If Docker commands still point to local Docker on Mac, run `docker context use windows-remote`.
- If Windows uses Docker Desktop, ensure Docker Desktop is running and the daemon is healthy.
