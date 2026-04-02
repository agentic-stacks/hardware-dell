# Deploy Phase

## Purpose

Set up the Dell tools container and perform initial hardware configuration on a new or unconfigured Dell PowerEdge server.

## Sub-Skills

| Sub-Skill | Path | Use When |
|---|---|---|
| Container Setup | `container-setup/README.md` | You need to build, start, or troubleshoot the Dell tools container |
| Initial Config | `initial-config/README.md` | You need to configure iDRAC networking, credentials, NTP, DNS, SNMP, or export a baseline SCP |

## Decision Tree

```
Is the Dell tools container running?
  NO  --> Follow container-setup/README.md first
  YES --> Is iDRAC reachable and configured?
            NO  --> Follow initial-config/README.md
            YES --> Deploy phase is complete. Proceed to the next phase.
```

## Quick Verification

Run these commands to confirm the deploy phase is complete:

```bash
# Container is running
docker ps --filter name=dell-tools --format '{{.Names}} {{.Status}}'

# iDRAC is reachable
docker exec dell-tools racadm -r 192.168.1.100 -u root -p calvin ping

# Baseline SCP exists
ls -la workspace/configs/baseline-scp.xml
```

## Prerequisites

- Docker and docker-compose installed on the management host
- Network access to the target server's iDRAC management port
- iDRAC credentials (default: root / calvin)

## Ordering

Execute sub-skills in this order:

1. **Container Setup** -- the container provides all Dell management tools
2. **Initial Config** -- configure iDRAC and export baseline before any other operations
