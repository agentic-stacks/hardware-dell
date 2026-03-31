# Container Setup

## Purpose

Build and start the Dell tools container that provides racadm, perccli64, mvcli, and Ansible Dell EMC collections in a single environment.

## Prerequisites

| Requirement | Check Command | Expected Output |
|---|---|---|
| Docker Engine | `docker --version` | Docker version 24.x or later |
| Docker Compose v2 | `docker compose version` | Docker Compose version v2.x or later |
| Network access to iDRAC | `ping -c 3 192.168.1.100` | 0% packet loss |
| Repository cloned | `ls container/docker-compose.yaml` | File exists |

## Step 1: Build the Container Image

```bash
docker compose -f container/docker-compose.yaml build
```

This compiles all Dell management tools into a single image. Build time is approximately 5-10 minutes depending on network speed.

## Step 2: Create the Environment File

Copy the example environment file and edit it with your site-specific values:

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

| Variable | Example Value | Description |
|---|---|---|
| `IDRAC_HOST` | `192.168.1.100` | iDRAC IP address or hostname |
| `IDRAC_USER` | `root` | iDRAC username |
| `IDRAC_PASS` | `calvin` | iDRAC password |
| `WORKSPACE_DIR` | `./workspace` | Local directory mounted into container |

## Step 3: Start the Container

Choose the profile that matches your deployment scenario.

### Option A: Local Management (Privileged)

Use this when the management host is the Dell server itself or has direct USB/serial access. The container runs in privileged mode to access local hardware devices.

> **Privileged mode is required** for local hardware access. The container entrypoint automatically starts the iDRAC service driver (`/usr/libexec/instsvcdrv-helper start`) which loads kernel modules for BMC communication. Without privileged mode and `/dev` access, local racadm, perccli64, and mvcli commands will fail.

```bash
docker compose -f container/docker-compose.yaml up -d dell-tools
```

### Option B: Remote-Only Management

Use this when managing the server exclusively over the network via iDRAC. No privileged access is required.

```bash
docker compose -f container/docker-compose.yaml --profile remote up -d dell-tools-remote
```

### Decision Tree: Which Profile?

```
Are you running on the Dell server itself (or need /dev access)?
  YES --> Option A: Local Management (privileged)
  NO  --> Are you managing only via iDRAC over the network?
            YES --> Option B: Remote-Only
            NO  --> Option A: Local Management (privileged)
```

## Step 4: Verify the Container

Run each verification command. All four must succeed before proceeding.

### Verify racadm

```bash
docker exec dell-tools racadm help
```

Expected: help text listing racadm subcommands.

### Verify perccli64

```bash
docker exec dell-tools perccli64 show
```

Expected: controller summary table or "No Controller found" (acceptable if no local PERC card).

### Verify mvcli

```bash
docker exec dell-tools mvcli help
```

Expected: help text listing mvcli commands.

### Verify Ansible Dell EMC Collections

```bash
docker exec dell-tools ansible-galaxy collection list | grep dellemc
```

Expected: one or more lines showing `dellemc.openmanage` or `dellemc.enterprise_sonic`.

### Verification Decision Tree

```
Did all four commands succeed?
  YES --> Proceed to initial-config
  NO  --> Which command failed?
            racadm     --> See Troubleshooting: Missing racadm
            perccli64  --> See Troubleshooting: Missing perccli64
            mvcli      --> See Troubleshooting: Missing mvcli
            ansible    --> See Troubleshooting: Missing Ansible collections
            all        --> See Troubleshooting: Container not running
```

## Interactive Shell

To open an interactive shell inside the container for ad-hoc commands:

```bash
docker exec -it dell-tools bash
```

Exit with `exit` or Ctrl-D. The container continues running after you exit the shell.

### Build with Rocky 10

```bash
docker compose -f container/docker-compose.yaml build --build-arg ROCKY_VERSION=10
```

### Build with Custom Tool Versions

Override any tool version or URL at build time:

```bash
docker compose -f container/docker-compose.yaml build \
  --build-arg ROCKY_VERSION=10 \
  --build-arg ANSIBLE_VERSION=10.6.0 \
  --build-arg GALAXY_DELLOM_VERSION=9.9.0
```

> **Dell download note:** Dell's download servers (dl.dell.com) block requests without a browser User-Agent header. The Dockerfile handles this automatically via the `DELL_UA` environment variable. If you see "403 Forbidden" errors during build, the User-Agent may need updating.

## Rebuilding After Tool Version Updates

When Dockerfiles or tool versions are updated, rebuild and restart:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml down
docker compose -f container/docker-compose.yaml up -d dell-tools
```

For remote-only deployments, replace the last two lines:

```bash
docker compose -f container/docker-compose.yaml --profile remote down
docker compose -f container/docker-compose.yaml --profile remote up -d dell-tools-remote
```

## Troubleshooting

### Container not running

```bash
# Check container status
docker compose -f container/docker-compose.yaml ps

# Check container logs for startup errors
docker compose -f container/docker-compose.yaml logs dell-tools
```

If the container exited immediately, check the logs for missing environment variables or mount path errors.

### DNS Resolution Failures Inside Container

Symptom: commands inside the container cannot resolve hostnames.

```bash
# Test DNS from inside the container
docker exec dell-tools nslookup google.com
```

Fix: add DNS servers to the docker-compose.yaml or pass them at runtime:

```bash
docker compose -f container/docker-compose.yaml down
```

Then add to the service definition in `container/docker-compose.yaml`:

```yaml
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

Restart the container after editing.

### Network: Cannot Reach iDRAC from Container

```bash
# Test connectivity from inside the container
docker exec dell-tools ping -c 3 192.168.1.100
```

If unreachable:

| Cause | Fix |
|---|---|
| iDRAC on a separate VLAN | Add the iDRAC network to the container's docker network or use `network_mode: host` |
| Firewall blocking ports | Open TCP ports 443 (HTTPS/Redfish), 22 (SSH), 5900 (VNC), 623 (IPMI) from the Docker host to the iDRAC IP |
| Wrong iDRAC IP in .env | Verify the IP with `racadm getniccfg` on the physical host or check your DHCP leases |

### Privilege Errors (Local Management)

Symptom: "Permission denied" accessing `/dev/ipmi0` or similar device nodes.

Verify the container is running in privileged mode:

```bash
docker inspect dell-tools --format '{{.HostConfig.Privileged}}'
```

Expected: `true`. If `false`, you started the remote-only profile. Stop it and start with Option A instead.

### Missing Tools After Build

If a specific tool binary is missing after build, rebuild without cache to pull fresh packages:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
```

Then restart the container.
