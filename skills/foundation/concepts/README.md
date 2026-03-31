# Concepts: Dell PowerEdge Architecture

## PowerEdge Server Generations

Dell designates server generations with a trailing "G" number. Each generation corresponds to a specific Intel Xeon or AMD EPYC processor family and an iDRAC firmware major version.

| Generation | iDRAC Version | Processor Families | Example Models | Release Timeframe |
|---|---|---|---|---|
| 14G | iDRAC9 (3.x-4.x) | Xeon Scalable Gen 1/2 (Skylake/Cascade Lake) | R640, R740, R740xd, R940, T640 | 2017-2019 |
| 15G | iDRAC9 (5.x-6.x) | Xeon Scalable Gen 3 (Ice Lake), EPYC 7003 (Milan) | R650, R750, R750xa, R6525, C6525 | 2021-2022 |
| 16G | iDRAC9 (7.x+) | Xeon Scalable Gen 4/5 (Sapphire Rapids/Emerald Rapids), EPYC 9004 (Genoa) | R660, R760, R760xa, R6625, HS5610 | 2023-present |
| 17G | iDRAC10 (1.x+) | Xeon 6 (Granite Rapids/Sierra Forest), EPYC next-gen | R770, R670, T370, R7725 | 2025+ |

### Naming Convention

Parse a PowerEdge model name as follows:

```
R 7 6 0 xa
| | | |  |
| | | |  +-- Suffix: xa = accelerator-optimized, xd = extended depth/storage, xs = extended storage
| | | +----- Generation digit: 0 = 14G, 5 = 15G (also "50" suffix), 6 = 16G (also "60" suffix)
| | +------- Performance tier: 1-2 = entry, 3-4 = value, 5-6 = mainstream, 7-8 = performance, 9 = high-end
| +--------- Socket count: 6 = 2-socket, 4 = single-socket, 9 = 4-socket
+----------- Form factor: R = rack, T = tower, C = multi-node/cloud, XE = extreme scale, HS = hyperscale
```

Examples:
- **R640**: Rack, 2-socket, mainstream performance, 14G
- **R750xa**: Rack, 2-socket, performance, 15G, accelerator-optimized
- **R660**: Rack, 2-socket, mainstream performance, 16G
- **T150**: Tower, single-socket, entry, 15G (note: T-series uses different socket-digit mapping for single-socket towers)
- **C6625**: Cloud/multi-node, 2-socket, mainstream, 16G, AMD variant (indicated by trailing 5 in some models)

### Identifying Generation from a System

```bash
# Via racadm (remote)
racadm -r <IDRAC_IP> -u <USER> -p <PASS> get System.ServerOS.ServerGeneration

# Via dmidecode (local, requires root)
dmidecode -s system-product-name
# Output example: "PowerEdge R750"

# Via Redfish
curl -sk -u <USER>:<PASS> https://<IDRAC_IP>/redfish/v1/Systems/System.Embedded.1 | jq '.Model'
```

## iDRAC (Integrated Dell Remote Access Controller)

iDRAC is Dell's baseboard management controller (BMC) implementation. It is a dedicated processor with its own operating system, network interface, and persistent storage embedded on the server motherboard. iDRAC operates independently of the host OS --- the server does not need to be powered on or have an OS installed for iDRAC to function.

> **iDRAC10 (17G):** iDRAC10 is a ground-up redesign with Redfish as the primary API. racadm commands remain supported for backwards compatibility, but Dell recommends Redfish for new automation. The web UI is fully redesigned. Key differences: TLS 1.3 default, enhanced telemetry streaming, hardware root of trust improvements.

### Core Capabilities

| Capability | Description |
|---|---|
| **Remote Power Control** | Power on, power off, graceful shutdown, reset, power cycle |
| **Console Redirect** | HTML5 virtual console (keyboard/video/mouse) over HTTPS |
| **Virtual Media** | Mount ISO images or disk images remotely as if physically attached |
| **Hardware Monitoring** | Temperatures, fan speeds, voltages, power consumption, intrusion detection |
| **Firmware Management** | Update iDRAC, BIOS, CPLD, NIC, RAID controller, drive, and PSU firmware |
| **Configuration Management** | Server Configuration Profile (SCP) export/import for full system config |
| **Alerting** | SNMP traps, email alerts, syslog forwarding, Redfish event subscriptions |
| **Lifecycle Controller** | Persistent storage for firmware updates, hardware diagnostics, OS deployment |

### Lifecycle Controller (LC)

The Lifecycle Controller is a subsystem within iDRAC that persists across OS reinstalls and firmware updates. It provides:

- **Remote firmware update** without booting to an OS
- **Hardware diagnostics** independent of the OS
- **OS deployment** via driver packs and unattended install templates
- **Configuration replay** via Server Configuration Profiles

Access the Lifecycle Controller GUI by pressing F10 during POST, or interact with it programmatically through racadm or Redfish.

### Virtual Console

Virtual Console provides remote keyboard/video/mouse access to the server.

- **HTML5 console**: Access via web browser, no plugin required (iDRAC9)
- **Requires**: iDRAC Enterprise or Datacenter license
- **Launch**: Navigate to iDRAC web UI > Dashboard > Virtual Console, or use racadm to generate a session URL
- **Use cases**: BIOS configuration, OS installation, troubleshooting boot failures

### Virtual Media

Virtual Media allows mounting remote ISO or IMG files to the server as if they were physically attached optical or USB drives.

- **RFS (Remote File Share)**: Mount an ISO from a CIFS/NFS share
- **HTML5 viewer**: Attach a local file from the admin workstation through the browser
- **Requires**: iDRAC Enterprise or Datacenter license

```bash
# Mount ISO via racadm
racadm -r <IDRAC_IP> -u <USER> -p <PASS> remoteimage -c -l //fileserver/share/os.iso -u shareuser -p sharepass
```

## BMC vs iDRAC Relationship

A BMC (Baseboard Management Controller) is the generic industry term for an embedded management processor on a server motherboard. iDRAC is Dell's specific BMC implementation.

| Aspect | Generic BMC | Dell iDRAC |
|---|---|---|
| Standard Protocol | IPMI | IPMI + Redfish + racadm + WS-Man |
| Firmware Update Scope | BMC only | Entire server firmware stack |
| Configuration Management | Limited | Full Server Configuration Profile |
| Diagnostics | Basic SEL | Lifecycle Controller diagnostics |
| Virtual Console | SOL (serial) | HTML5 KVM + SOL |

Key point: iDRAC responds to standard IPMI commands (via ipmitool) but offers far richer functionality through its proprietary interfaces (racadm, Redfish with Dell OEM extensions).

## Out-of-Band vs In-Band Management

| Property | Out-of-Band (OOB) | In-Band |
|---|---|---|
| Network Path | Dedicated iDRAC NIC or shared LOM | Host OS network interface |
| Requires Host OS | No | Yes |
| Tools | racadm (remote), ipmitool, Redfish, web UI | racadm (local), dmidecode, lshw, lspci, OMSA |
| Power State | Works when server is off (standby power) | Requires server powered on with OS running |
| Use When | Server is unresponsive, OS not installed, remote BIOS changes, firmware updates | Collecting local inventory, running diagnostics with OS context |

Decision rule: **Prefer out-of-band management for all remote operations.** Use in-band only when the task specifically requires host OS context (e.g., mapping PCI devices to OS network interface names).

## BIOS vs UEFI on Dell Systems

All PowerEdge servers from 14G onward ship with UEFI firmware. Dell's "BIOS" settings in racadm and Redfish refer to the system setup configuration, not legacy BIOS mode.

| Setting | Meaning |
|---|---|
| `BootMode=Uefi` | UEFI boot mode (default, recommended) |
| `BootMode=Bios` | Legacy BIOS boot mode (deprecated, avoid for new deployments) |

```bash
# Check current boot mode
racadm -r <IDRAC_IP> -u <USER> -p <PASS> get BIOS.BiosBootSettings.BootMode

# Set UEFI boot mode (creates a scheduled job; takes effect on next reboot)
racadm -r <IDRAC_IP> -u <USER> -p <PASS> set BIOS.BiosBootSettings.BootMode Uefi
racadm -r <IDRAC_IP> -u <USER> -p <PASS> jobqueue create BIOS.Setup.1-1
```

Note: Changing `BootMode` requires a reboot. The change is staged as a job in the job queue and applied during the next server restart.

## Server Component Firmware Hierarchy

A PowerEdge server contains multiple independently updatable firmware components. Update order matters --- always update iDRAC first, then BIOS, then remaining components.

| Component | Update Mechanism | Reboot Required | Typical Update Time |
|---|---|---|---|
| **iDRAC Firmware** | DUP via racadm, Redfish, or Lifecycle Controller | iDRAC resets (not host) | 5-10 minutes |
| **BIOS/UEFI** | DUP staged to job queue, applied on reboot | Yes (host reboot) | 5-15 minutes |
| **CPLD** | DUP via Lifecycle Controller | Yes (full AC power cycle) | 2-5 minutes |
| **NIC Firmware** | DUP via racadm or Redfish | Varies (some require reboot) | 2-5 minutes per NIC |
| **RAID Controller Firmware** | DUP via racadm or Redfish | Yes (host reboot) | 5-10 minutes |
| **Drive Firmware** | DUP via racadm or Redfish | Varies (SAS: usually no; NVMe: reboot) | 1-3 minutes per drive |
| **PSU Firmware** | DUP via Lifecycle Controller | No | 5-10 minutes per PSU |

### Recommended Update Order

1. iDRAC firmware
2. BIOS/UEFI
3. CPLD (if applicable --- requires full AC power cycle, schedule carefully)
4. NIC firmware
5. RAID controller firmware
6. Drive firmware
7. PSU firmware

### Checking Installed Firmware Versions

```bash
# All firmware inventory via racadm
racadm -r <IDRAC_IP> -u <USER> -p <PASS> swinventory

# All firmware inventory via Redfish
curl -sk -u <USER>:<PASS> https://<IDRAC_IP>/redfish/v1/UpdateService/FirmwareInventory | jq '.Members[]'

# Specific component via Redfish
curl -sk -u <USER>:<PASS> https://<IDRAC_IP>/redfish/v1/UpdateService/FirmwareInventory/Installed-0-<FQDD> | jq '{Name, Version}'
```

## Dell Update Packages (DUP) and Dell System Update (DSU)

### Dell Update Packages (DUP)

A DUP is a self-contained firmware update binary. Each DUP targets a specific component and can be applied through multiple methods.

| DUP Format | Extension | Apply Method |
|---|---|---|
| Linux DUP | `.BIN` | Execute on host OS, or upload to iDRAC via racadm/Redfish |
| Windows DUP | `.EXE` | Execute on host OS (Windows only) |

```bash
# Apply a Linux DUP via racadm remote
racadm -r <IDRAC_IP> -u <USER> -p <PASS> update -f <DUP_FILE.BIN> -t HTTPS -e <IP_OF_HTTP_SERVER>

# Apply via Redfish Simple Update
curl -sk -u <USER>:<PASS> -X POST \
  https://<IDRAC_IP>/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate \
  -H 'Content-Type: application/json' \
  -d '{"ImageURI": "http://<HTTP_SERVER>/<DUP_FILE.BIN>"}'
```

### Dell System Update (DSU)

DSU is a command-line utility that compares installed firmware versions against a catalog (Dell repository) and applies all necessary updates in the correct order.

```bash
# Install DSU on RHEL/CentOS
yum install -y dell-system-update

# Preview available updates (dry run)
dsu --preview

# Apply all applicable updates non-interactively
dsu --non-interactive

# Apply updates from a local repository
dsu --source-type=Repository --source-location=/path/to/repo --non-interactive
```

DSU handles dependency ordering automatically. Prefer DSU for bulk firmware updates on hosts with a running Linux OS.

## iDRAC License Tiers

| Feature | Basic | Express | Enterprise | Datacenter |
|---|---|---|---|---|
| Web UI | Yes | Yes | Yes | Yes |
| Redfish API | Yes | Yes | Yes | Yes |
| racadm (remote) | Yes | Yes | Yes | Yes |
| IPMI/SOL | Yes | Yes | Yes | Yes |
| Virtual Console | No | No | Yes | Yes |
| Virtual Media | No | No | Yes | Yes |
| Server Configuration Profile | No | Partial | Yes | Yes |
| Telemetry Streaming | No | No | No | Yes |
| Group Manager | No | No | No | Yes |
| Thermal Management | No | No | No | Yes |

Check the installed license:

```bash
racadm -r <IDRAC_IP> -u <USER> -p <PASS> license view
```

Important: Most automation tasks (racadm remote, Redfish API, firmware updates) work with Basic or Express. Virtual Console and Virtual Media require Enterprise or higher.

## Redfish API on Dell Systems

Redfish is an industry-standard RESTful API (DMTF standard) for server management. Dell implements the Redfish standard plus Dell-specific OEM extensions under `/redfish/v1/Dell/`.

### Base Endpoints

| Endpoint | Purpose |
|---|---|
| `/redfish/v1/` | Service root, API version, links to top-level resources |
| `/redfish/v1/Systems/System.Embedded.1` | System overview: model, serial, power state, health |
| `/redfish/v1/Chassis/System.Embedded.1` | Physical chassis: thermal, power, sensors |
| `/redfish/v1/Managers/iDRAC.Embedded.1` | iDRAC manager: firmware version, network config, logs |
| `/redfish/v1/UpdateService` | Firmware update operations and inventory |
| `/redfish/v1/AccountService` | User account management |
| `/redfish/v1/EventService` | Event subscriptions (alerts, telemetry) |

### Dell OEM Extensions

| Endpoint | Purpose |
|---|---|
| `/redfish/v1/Dell/Managers/iDRAC.Embedded.1/DellLCService` | Lifecycle Controller operations |
| `/redfish/v1/Dell/Systems/System.Embedded.1/DellRaidService` | RAID operations (create/delete virtual disks) |
| `/redfish/v1/Managers/iDRAC.Embedded.1/Oem/Dell/DellJobService` | Job queue management |

### Common Operations

```bash
# Get system power state
curl -sk -u <USER>:<PASS> https://<IDRAC_IP>/redfish/v1/Systems/System.Embedded.1 | jq '.PowerState'

# Power on the server
curl -sk -u <USER>:<PASS> -X POST \
  https://<IDRAC_IP>/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "On"}'

# Graceful shutdown
curl -sk -u <USER>:<PASS> -X POST \
  https://<IDRAC_IP>/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulShutdown"}'

# Export Server Configuration Profile (full system config)
curl -sk -u <USER>:<PASS> -X POST \
  https://<IDRAC_IP>/redfish/v1/Managers/iDRAC.Embedded.1/Actions/Oem/EID_674_Manager.ExportSystemConfiguration \
  -H 'Content-Type: application/json' \
  -d '{"ExportFormat": "JSON", "ShareParameters": {"Target": "ALL"}}'
```

### Authentication

Redfish on iDRAC uses HTTP Basic Authentication over HTTPS. All requests must use HTTPS (port 443). The default self-signed certificate will trigger TLS warnings --- use `-k` (curl) or `verify=False` (Python requests) in automation, or install a trusted certificate on the iDRAC.

### Session-Based Authentication

For multiple requests, create a session to avoid re-authenticating:

```bash
# Create session
SESSION=$(curl -sk -X POST https://<IDRAC_IP>/redfish/v1/Sessions \
  -H 'Content-Type: application/json' \
  -d '{"UserName": "<USER>", "Password": "<PASS>"}' \
  -D - 2>/dev/null | grep -i X-Auth-Token | awk '{print $2}' | tr -d '\r')

# Use session token
curl -sk -H "X-Auth-Token: $SESSION" https://<IDRAC_IP>/redfish/v1/Systems/System.Embedded.1 | jq '.Model'

# Delete session when done
curl -sk -H "X-Auth-Token: $SESSION" -X DELETE https://<IDRAC_IP>/redfish/v1/Sessions/<session-id>
```
