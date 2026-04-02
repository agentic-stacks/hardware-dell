# Architecture: Container-Based Tooling

## Why Containerize Dell Tools?

Dell's hardware management tools (racadm, perccli64, mvcli) have specific OS and library dependencies that vary by version. Running them in a container solves three problems:

1. **OS independence** — racadm ships as RPMs targeting RHEL/SLES. The container runs Rocky Linux regardless of the operator's host OS (Ubuntu, Debian, macOS via Docker Desktop, etc.)
2. **Version pinning** — every tool version is locked in the Dockerfile. Two operators on different machines get identical tool behavior.
3. **Reproducibility** — `docker build` produces the same toolkit every time. No "works on my machine" when troubleshooting across a team.

## Container Modes

### Privileged Mode (Local Hardware Access)

```bash
docker compose -f container/docker-compose.yaml up -d dell-tools
```

Uses:
- `privileged: true` — access to host kernel modules and devices
- `network_mode: host` — shares host network stack
- `/dev:/dev:ro` and `/sys:/sys:ro` — read host hardware info

**When to use:** managing the server the container is running on. Required for:
- `dmidecode` (reads SMBIOS from /dev/mem)
- `lshw` (reads /sys and /dev)
- `ipmitool` local mode (needs /dev/ipmi0)
- `perccli64` and `mvcli` local mode (need direct controller access)
- `racadm` local mode (needs the iDRAC service driver)

**iDRAC service driver:** The container entrypoint automatically runs `/usr/libexec/instsvcdrv-helper start` on startup. This loads the kernel modules that enable communication between the host OS and the iDRAC BMC. Without this service, local `racadm` commands will fail. The service requires privileged mode and `/dev` access to function.

**Security note:** privileged containers have full host access. Only use on the server being managed, not on a management workstation.

### Remote-Only Mode

```bash
docker compose -f container/docker-compose.yaml --profile remote up -d dell-tools-remote
```

Uses:
- No privileged mode
- No device passthrough
- Standard container networking

**When to use:** managing remote servers over the network. Sufficient for:
- `racadm -r <IDRAC_IP>` (HTTPS to iDRAC)
- `ipmitool -I lanplus -H <IDRAC_IP>` (IPMI over LAN)
- Ansible playbooks targeting remote iDRACs
- Redfish API calls via curl

**Security note:** this is the safer option. Use this on a management workstation or jump host.

## Network Flow

```
Operator Workstation                Container                    Target Server
┌─────────────────┐    docker exec   ┌──────────────┐   HTTPS/443   ┌──────────┐
│                 │ ──────────────── │ dell-tools   │ ────────────── │  iDRAC   │
│  Terminal/Agent │                  │              │   IPMI/623     │          │
│                 │                  │  racadm      │ ────────────── │  BMC     │
│                 │                  │  ipmitool    │   SSH/22       │          │
│                 │                  │  ansible     │ ────────────── │          │
└─────────────────┘                  └──────────────┘                └──────────┘
                                           │
                                     /workspace (mounted)
                                           │
                                    ┌──────────────┐
                                    │ SCP exports  │
                                    │ Firmware DUPs│
                                    │ Playbooks    │
                                    │ Inventory    │
                                    └──────────────┘
```

## Credential Handling

Credentials never go in committed files. Three approaches, from simplest to most secure:

### 1. Environment File (.env)

The `.env` file at the project root is loaded by docker-compose automatically:

```bash
# .env (gitignored)
IDRAC_HOST=192.168.1.100
IDRAC_USER=root
IDRAC_PASS=changeme
```

The container receives these as environment variables. Commands inside the container use them:

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getsysinfo
```

### 2. Ansible Vault (Fleet Operations)

For managing multiple servers, store credentials in an Ansible vault:

```bash
ansible-vault create workspace/playbooks/vault.yaml
```

Reference in playbooks with `--ask-vault-pass` or a vault password file.

### 3. Environment Variables (CI/CD)

In automated pipelines, inject credentials as environment variables at runtime:

```bash
docker exec -e IDRAC_HOST=10.0.0.1 -e IDRAC_PASS=secret dell-tools racadm getsysinfo
```

## Container Lifecycle

```bash
# Build (or rebuild after Dockerfile changes)
docker compose -f container/docker-compose.yaml build

# Build with Rocky 10
docker compose -f container/docker-compose.yaml build --build-arg ROCKY_VERSION=10

# Start
docker compose -f container/docker-compose.yaml up -d dell-tools

# Execute a command
docker exec dell-tools racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getsysinfo

# Interactive shell
docker exec -it dell-tools bash

# Stop
docker compose -f container/docker-compose.yaml down

# Rebuild with updated tool versions
docker compose -f container/docker-compose.yaml build --no-cache
```

## Volume Mounts

The `/workspace` directory inside the container maps to `workspace/` in the operator's project:

| Container Path | Host Path | Purpose |
|---|---|---|
| `/workspace/configs/` | `workspace/configs/` | SCP XML/JSON exports per server |
| `/workspace/firmware/` | `workspace/firmware/` | Downloaded Dell Update Packages |
| `/workspace/playbooks/` | `workspace/playbooks/` | Ansible playbooks |
| `/workspace/inventory/` | `workspace/inventory/` | Hardware inventory exports |

Files created inside the container appear on the host and vice versa. This enables a GitOps workflow: export configs inside the container, commit them from the host.
