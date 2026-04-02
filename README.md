# Dell Hardware — Agentic Stack

An [agentic stack](https://github.com/agentic-stacks/agentic-stacks) that teaches AI agents to manage Dell PowerEdge server hardware — BIOS configuration, iDRAC remote management, RAID setup, firmware updates, and hardware inventory.

Includes a container-based toolkit (racadm, perccli, mvcli, ipmitool, Ansible OpenManage) so operators can manage Dell servers from any OS without local tool installation.

## Supported Hardware

- **iDRAC9** — PowerEdge 14G, 15G, 16G (R640, R740, R650, R750, R660, R760, etc.)
- **iDRAC10** — PowerEdge 17G (R770, R670, T370, etc.)

## Quick Start

```bash
# Clone the stack
git clone https://github.com/agentic-stacks/hardware-dell.git
cd hardware-dell

# Set up credentials
cp .env.example .env
# Edit .env with your iDRAC IP, username, and password

# Build the container (Rocky 9 default)
docker compose -f container/docker-compose.yaml build

# Or build with Rocky 10
docker compose -f container/docker-compose.yaml build --build-arg ROCKY_VERSION=10

# Start the container (privileged mode for local hardware access)
docker compose -f container/docker-compose.yaml up -d dell-tools

# Or remote-only mode (no host hardware passthrough)
docker compose -f container/docker-compose.yaml --profile remote up -d dell-tools-remote

# Run a command
docker exec dell-tools racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getsysinfo
```

## What's Inside

### Container Tools

| Tool | Purpose |
|---|---|
| racadm | iDRAC remote administration CLI |
| perccli64 | PERC RAID controller CLI |
| mvcli | Marvell/S150/BOSS software RAID CLI |
| ipmitool | IPMI standard protocol CLI |
| Ansible + dellemc.openmanage | Fleet-wide server management |
| dmidecode, lshw, lspci | Local hardware discovery |

### Skills (17)

| Phase | Skills |
|---|---|
| **Foundation** | [Concepts](skills/foundation/concepts), [Tools](skills/foundation/tools), [Architecture](skills/foundation/architecture) |
| **Deploy** | [Container Setup](skills/deploy/container-setup), [Initial Config](skills/deploy/initial-config) |
| **Operations** | [BIOS](skills/operations/bios), [iDRAC](skills/operations/idrac), [RAID](skills/operations/raid), [Firmware](skills/operations/firmware), [Inventory](skills/operations/inventory), [OpenManage](skills/operations/openmanage) |
| **Diagnose** | [Hardware](skills/diagnose/hardware), [Connectivity](skills/diagnose/connectivity), [Storage](skills/diagnose/storage) |
| **Reference** | [Known Issues](skills/reference/known-issues), [Compatibility](skills/reference/compatibility), [Decision Guides](skills/reference/decision-guides) |

### BIOS Profiles

Pre-built BIOS configurations in `profiles/`:

- **Virtualization Host** — ESXi, Proxmox, KVM (VT-x, VT-d, SR-IOV)
- **Database Server** — PostgreSQL, MySQL, Oracle (HT disabled, NUMA-aware)
- **HPC / Compute** — AI/ML, scientific computing (max throughput, GPU support)
- **Storage Server** — Ceph, MinIO, ZFS (I/O optimized, HBA passthrough)

## Using with an AI Agent

Point your agent (Claude Code, etc.) at this directory. The agent reads `CLAUDE.md` for identity, safety rules, and skill routing, then navigates to the relevant skill for the operator's task.

```bash
# Open in Claude Code
cd hardware-dell
claude
```

The agent can then help with tasks like:
- "Set up iDRAC on a new server"
- "Create a RAID 6 array with 8 drives"
- "Update firmware on all servers in the fleet"
- "Why is the chassis LED blinking amber?"
- "Export BIOS config and apply it to 10 other servers"

## Project Structure

```
hardware-dell/
├── CLAUDE.md                    # Agent entry point
├── stack.yaml                   # Stack manifest
├── .env.example                 # Credential template
├── container/                   # Dockerfile + docker-compose
├── profiles/                    # BIOS profiles by workload
└── skills/                      # Operational knowledge
    ├── foundation/              # Concepts, tools, architecture
    ├── deploy/                  # Container setup, initial config
    ├── operations/              # BIOS, iDRAC, RAID, firmware, inventory, Ansible
    ├── diagnose/                # Hardware, connectivity, storage troubleshooting
    └── reference/               # Known issues, compatibility, decision guides
```

## Operator Project Structure

When using this stack to manage your servers, your project should look like:

```
my-server-fleet/
├── .env                         # iDRAC credentials (gitignored)
├── workspace/
│   ├── configs/                 # SCP exports per server
│   ├── firmware/                # Downloaded Dell Update Packages
│   ├── playbooks/               # Ansible playbooks
│   └── inventory/               # Hardware inventory exports
├── profiles/                    # BIOS profiles
└── container/                   # Dockerfile + docker-compose
```

## License

MIT
