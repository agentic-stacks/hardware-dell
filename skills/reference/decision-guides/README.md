# Decision Guides

## racadm vs Ansible

| Factor | racadm | Ansible (dellemc.openmanage) |
|---|---|---|
| **Best for** | Single server, ad-hoc commands | Fleet operations, repeatable automation |
| **Learning curve** | Low — CLI with `--help` | Medium — requires playbook knowledge |
| **Config-as-code** | SCP export/import + git | SCP module + inventory + vault |
| **Idempotent** | No — runs every time | Yes — modules check current state |
| **Credential handling** | Environment variables | Ansible vault (encrypted) |
| **Parallelism** | Manual (one server at a time) | Built-in (forks, serial) |
| **Error handling** | Exit codes, manual checking | Handlers, rescue blocks, reporting |
| **Audit trail** | Shell history | Playbook runs, callback plugins |

### Recommendation

- **1-3 servers:** racadm directly. Ansible overhead isn't worth it.
- **4+ servers:** Ansible. The initial setup pays for itself quickly.
- **Mixed:** Use racadm for troubleshooting and one-off commands. Use Ansible for planned changes across the fleet.

## Local (Privileged) vs Remote Container Mode

| Factor | Privileged (dell-tools) | Remote (dell-tools-remote) |
|---|---|---|
| **Use when** | Managing the local server | Managing remote servers |
| **Tools available** | All (racadm local, perccli64, mvcli, dmidecode, lshw) | Network tools only (racadm remote, ipmitool lanplus, Ansible, curl) |
| **Security** | Full host access — use only on target server | Sandboxed — safe for workstations |
| **Device access** | /dev, /sys mounted read-only | None |
| **Network** | Host network stack | Container networking |

### Recommendation

- **Management workstation or jump host:** Always use remote mode.
- **On the server itself (bare metal management):** Use privileged mode.
- **CI/CD pipeline:** Use remote mode — no need for host access.

## RAID Level Selection

| RAID Level | Drives | Usable Space | Read Perf | Write Perf | Fault Tolerance | Best For |
|---|---|---|---|---|---|---|
| RAID 0 | 1+ | 100% | Excellent | Excellent | None | Scratch, temp, non-critical |
| RAID 1 | 2 | 50% | Good | Good | 1 drive | Boot/OS, small critical |
| RAID 5 | 3+ | (N-1)/N | Good | Moderate | 1 drive | General purpose, balanced |
| RAID 6 | 4+ | (N-2)/N | Good | Slower | 2 drives | Large arrays, high reliability |
| RAID 10 | 4+ (even) | 50% | Excellent | Good | 1 per mirror | Databases, random I/O |
| RAID 50 | 6+ | Varies | Very good | Good | 1 per span | Large capacity + performance |
| RAID 60 | 8+ | Varies | Good | Moderate | 2 per span | Maximum protection |

### Recommendation by Workload

- **Virtualization (ESXi/Proxmox):** RAID 5 or RAID 6 for VM storage, RAID 1 for boot
- **Database (PostgreSQL/MySQL):** RAID 10 for data, RAID 1 for boot/logs
- **Object storage (Ceph/MinIO):** No RAID (JBOD/HBA mode) — Ceph handles replication
- **File server / NAS:** RAID 6 for capacity with dual-drive protection
- **Boot only (BOSS card):** RAID 1 mirror on M.2

## Firmware Update Strategy

| Strategy | How | When |
|---|---|---|
| **Rolling** | Update one server at a time, verify, proceed | HA clusters where one node can be down |
| **Maintenance window** | Update all servers in a batch during downtime | Non-HA environments or major upgrades |
| **Staged** | Upload firmware but delay apply until planned reboot | Servers that rarely reboot |
| **Automated (DSU)** | Dell System Update pulls from Dell catalog | Lab/dev environments, non-critical |

### Recommendation

- **Production HA cluster:** Rolling — one node at a time with health verification between each.
- **Production standalone:** Maintenance window — schedule downtime.
- **Lab/development:** DSU automated — fastest path to current firmware.
- **All environments:** Always update iDRAC first, verify connectivity, then BIOS, then components.
