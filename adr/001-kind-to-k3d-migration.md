# ADR: Migrate from Kind to k3d for Remote Docker Support

**Date:** 2026-08-12
**Status:** Accepted
**Deciders:** Arun Subramanian

## Context

We need to run Kubernetes locally for development. The goal is to keep macOS clean by using a Windows laptop as the remote Docker host, running all Docker builds and workloads on Windows while using Docker CLI on Mac.

### Previous Approach (Kind)

- Used Kind (Kubernetes in Docker) for local K8s clusters
- Required Docker Desktop on Mac to run Kind locally
- Kind binds ports to the host's localhost, assuming local Docker

### Problem with Remote Docker

When Docker runs remotely on Windows:
1. Kind attempts to bind ports to Mac's localhost, but Docker daemon is on Windows
2. Port bindings fail with "Operation not permitted" or "address already in use"
3. Kind cluster creation fails because it cannot map ports correctly

Error encountered:
```
docker: Error response from daemon: ports are not available: exposing port TCP 127.0.0.1:54060 -> 127.0.0.1:0: listen tcp4 127.0.0.1:54060: bind: An attempt was made to access a socket in a way forbidden by its access permissions.
```

## Decision

Migrate from Kind to k3d as the local Kubernetes solution when using remote Docker.

### Why k3d?

1. **Better Remote Docker Compatibility**
   - k3d uses a loadbalancer (traefik/nginx) that handles port mapping differently
   - NodePorts are exposed on the Docker host (Windows) and accessible via SSH

2. **Simpler Port Management**
   - k3d supports port ranges via `-p` flag without recreating clusters
   - No need to define `extraPortMappings` in config files

3. **SSH Tunnel Architecture**
   - API server (port 6550) forwarded via SSH tunnel to Mac localhost
   - NodePorts (30000-30009) accessible directly on Windows IP
   - Existing code continues to use `localhost` for API server access

4. **Lightweight**
   - k3d runs K3s (lightweight Kubernetes) instead of full Kubernetes
   - Lower resource footprint than Kind

## Consequences

### Positive

- Mac remains clean (no Docker Desktop required)
- All Docker workloads run on Windows
- Existing code requires minimal changes (only environment variables)
- SSH tunnel provides secure access to K8s API

### Negative

- Additional setup step (SSH tunnel)
- NodePorts require Windows IP access (network dependency)
- k3d is a new dependency to maintain

### Neutral

- `K8S_NODE_HOST` environment variable must be set to Windows IP
- Kubeconfig file stored at `~/.kube/config-remote-k3d`

## Implementation

### New Scripts

1. **`scripts/setup-remote-k3d.sh`**
   - Creates k3d cluster on remote Docker
   - Sets up SSH tunnel for API server
   - Configures kubeconfig

2. **`scripts/local-stack-k8s-remote.sh`**
   - Wrapper that runs setup-remote-k3d.sh then local:stack-k8s

### Package.json Changes

Added new script:
```json
"local:stack-k8s:remote": "bash scripts/local-stack-k8s-remote.sh"
```

### Usage

```bash
# Quick start
pnpm local:stack-k8s:remote Dell@192.168.1.18

# Manual setup
./scripts/setup-remote-k3d.sh Dell@192.168.1.18
export KUBECONFIG=~/.kube/config-remote-k3d
export K8S_NODE_HOST=192.168.1.18
pnpm local:stack-k8s
```

## Alternatives Considered

1. **Keep Kind with SSH port forwarding**
   - Kind's port binding mechanism is fundamentally incompatible with remote Docker
   - Would require significant workarounds

2. **Make all URLs configurable**
   - Replace hardcoded `localhost` with environment variables
   - Requires modifying 87+ files with hardcoded localhost references
   - High risk of breaking existing functionality

3. **Reinstall Docker Desktop on Mac**
   - Defeats the purpose of remote Docker setup
   - Reintroduces Docker Desktop overhead on Mac

## References

- [k3d Documentation](https://k3d.io/)
- [k3d Remote Docker Issue](https://github.com/k3d-io/k3d/issues)
- [SSH Port Forwarding](https://www.ssh.com/academy/ssh/tunneling)
