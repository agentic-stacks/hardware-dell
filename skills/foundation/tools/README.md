# Tools: Dell PowerEdge Management Tool Landscape

> **iDRAC10 note:** All tools in this stack work with iDRAC10 (17G) servers. For iDRAC10, Dell recommends Redfish API as the primary interface. racadm remains fully functional. perccli64 works with PERC 12 controllers on 17G.

## Tool Selection Decision Tree

```
What is the task?
|
+-- Remote server management (iDRAC reachable)?
|   |
|   +-- Need Dell-specific features (SCP, job queue, firmware update)?
|   |   --> Use racadm (remote) or Redfish API
|   |
|   +-- Need only basic power/sensor/SEL operations?
|   |   --> Use ipmitool (lightweight, no Dell tools required)
|   |
|   +-- Need to manage RAID on PERC controller?
|   |   --> Use racadm (remote) for virtual disk creation, or Redfish Dell RAID extensions
|   |
|   +-- Fleet-wide automation (10+ servers)?
|       --> Use Ansible dellemc.openmanage collection
|
+-- Local server management (running on the PowerEdge host)?
|   |
|   +-- Need Dell-specific configuration?
|   |   --> Use racadm (local)
|   |
|   +-- Need hardware inventory (PCI, memory, CPU)?
|   |   --> Use dmidecode, lshw, lspci
|   |
|   +-- Need PERC RAID management with full control?
|   |   --> Use perccli64
|   |
|   +-- Need Marvell RAID controller management?
|       --> Use mvcli
|
+-- Bulk firmware updates on a running Linux host?
    --> Use DSU (Dell System Update)
```

---

## racadm

racadm (Remote Access Controller Admin) is Dell's primary CLI for iDRAC management. It operates in three distinct modes.

### Modes

| Mode | Invocation | Runs On | Network Required | Use When |
|---|---|---|---|---|
| **Local** | `racadm <command>` | Host OS (requires IPMI driver) | No | Configuring the local server's iDRAC from the host OS |
| **Remote** | `racadm -r <IP> -u <USER> -p <PASS> <command>` | Any machine | Yes (HTTPS to iDRAC) | Managing remote servers over the network |
| **Firmware racadm** | Available in Lifecycle Controller environment | Pre-OS (F10 boot) | No | Recovery scenarios when iDRAC web/remote is inaccessible |

### Command Syntax

```
racadm [connection_options] <subcommand> [arguments]
```

Connection options for remote mode:
```
-r <IDRAC_IP>       iDRAC IP address or hostname
-u <USERNAME>       iDRAC username
-p <PASSWORD>       iDRAC password
-S                  Verify SSL certificate (omit to skip verification)
```

### Essential Subcommands

| Subcommand | Purpose | Example |
|---|---|---|
| `get` | Read a configuration attribute | `racadm get BIOS.BiosBootSettings.BootMode` |
| `set` | Write a configuration attribute | `racadm set BIOS.BiosBootSettings.BootMode Uefi` |
| `getconfig` | Read legacy group config (deprecated, use `get`) | `racadm getconfig -g cfgServerInfo` |
| `setconfig` | Write legacy group config (deprecated, use `set`) | `racadm setconfig -g cfgServerInfo -o cfgServerBootOnce 1` |
| `jobqueue` | Manage configuration/update jobs | `racadm jobqueue create BIOS.Setup.1-1` |
| `jobqueue view` | List all jobs and their status | `racadm jobqueue view` |
| `jobqueue delete -i JID_CLEARALL` | Clear all jobs from the queue | `racadm jobqueue delete -i JID_CLEARALL` |
| `serveraction` | Power control | `racadm serveraction poweron` |
| `swinventory` | List installed firmware versions | `racadm swinventory` |
| `update` | Apply a firmware update (DUP) | `racadm update -f BIOS.BIN -l /path/` |
| `license` | View/import/export licenses | `racadm license view` |
| `getniccfg` | View iDRAC NIC configuration | `racadm getniccfg` |
| `getsysinfo` | Get system overview (model, service tag, iDRAC info) | `racadm getsysinfo` |
| `hwinventory` | Hardware inventory (memory, CPU, NIC, storage) | `racadm hwinventory` |
| `getsel` | View System Event Log | `racadm getsel` |
| `clrsel` | Clear System Event Log | `racadm clrsel` |
| `getraclog` | View iDRAC/Lifecycle Controller log | `racadm getraclog` |
| `systemconfig` | Export/import Server Configuration Profile (SCP) | `racadm systemconfig export -f scp.json` |
| `storage` | RAID virtual disk and physical disk management | `racadm storage createvd:RAID.Slot.1-1 ...` |
| `diagnostics` | Run remote diagnostics | `racadm diagnostics run -m express` |
| `techsupreport` | Generate a tech support report (TSR) | `racadm techsupreport collect` |

### Server Power Actions

```bash
racadm -r <IP> -u <USER> -p <PASS> serveraction poweron
racadm -r <IP> -u <USER> -p <PASS> serveraction poweroff       # Hard power off (immediate)
racadm -r <IP> -u <USER> -p <PASS> serveraction graceshutdown  # Graceful OS shutdown
racadm -r <IP> -u <USER> -p <PASS> serveraction hardreset      # Hard reset
racadm -r <IP> -u <USER> -p <PASS> serveraction powercycle     # Power cycle
```

### Configuration Change Workflow

Many racadm `set` operations stage changes that require a job to be created and a reboot to apply:

```bash
# 1. Stage the change
racadm -r <IP> -u <USER> -p <PASS> set BIOS.BiosBootSettings.BootMode Uefi

# 2. Create a job to apply the change
racadm -r <IP> -u <USER> -p <PASS> jobqueue create BIOS.Setup.1-1
# Output: JID_XXXXXXXXXXXX

# 3. Reboot the server to execute the job
racadm -r <IP> -u <USER> -p <PASS> serveraction powercycle

# 4. Monitor job status
racadm -r <IP> -u <USER> -p <PASS> jobqueue view -i JID_XXXXXXXXXXXX
# Wait for Status=Completed
```

### Batch Configuration via Server Configuration Profile (SCP)

```bash
# Export full system configuration to JSON
racadm -r <IP> -u <USER> -p <PASS> get -t json -f scp_export.json

# Import configuration (applies all settings, creates jobs automatically)
racadm -r <IP> -u <USER> -p <PASS> set -t json -f scp_import.json

# Export via systemconfig subcommand
racadm -r <IP> -u <USER> -p <PASS> systemconfig export -f scp.xml
racadm -r <IP> -u <USER> -p <PASS> systemconfig import -f scp.xml
```

---

## ipmitool

ipmitool implements the Intelligent Platform Management Interface (IPMI) protocol. It works with any BMC, not just iDRAC. Use it when you need lightweight, vendor-agnostic operations or when Dell-specific tools are not available.

### When to Use ipmitool vs racadm

| Task | ipmitool | racadm |
|---|---|---|
| Power on/off/cycle | Yes | Yes |
| Read sensor values | Yes | Yes (but Redfish is better) |
| View System Event Log | Yes | Yes |
| Set next boot device | Yes | Yes |
| Firmware update | No | Yes |
| BIOS configuration | No | Yes |
| RAID management | No | Yes |
| Server Configuration Profile | No | Yes |
| Job queue management | No | Yes |

### Common Commands

```bash
# Check power status
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> power status

# Power on
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> power on

# Power off (hard)
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> power off

# Graceful shutdown
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> power soft

# Read all sensor values
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> sdr list

# View System Event Log
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> sel list

# Set next boot to PXE (one-time)
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> chassis bootdev pxe options=efiboot

# Serial Over LAN console
ipmitool -I lanplus -H <IDRAC_IP> -U <USER> -P <PASS> sol activate
```

### Interface Types

| Interface | Flag | Use When |
|---|---|---|
| `lanplus` | `-I lanplus` | Remote access over network (IPMI v2.0, encrypted) |
| `open` | `-I open` | Local access via `/dev/ipmi0` (requires OpenIPMI driver) |
| `lan` | `-I lan` | Legacy IPMI v1.5 (avoid; unencrypted) |

Always use `lanplus` for remote access.

---

## perccli64

perccli64 (PERC CLI) is Dell's command-line tool for managing PERC (PowerEdge RAID Controller) hardware RAID controllers. It replaces the older `megacli` tool.

### When to Use

- Creating, deleting, or modifying RAID virtual disks on PERC controllers
- Checking physical disk status, SMART data, patrol read status
- Managing hot spares, drive rebuilds, consistency checks
- Requires execution on the host OS (local tool, runs against `/dev/megaraid_sas_ioctl_node`)

### Key Commands

```bash
# Show all controllers
perccli64 show

# Show detailed controller info (controller 0)
perccli64 /c0 show all

# List all virtual disks on controller 0
perccli64 /c0/vall show

# List all physical disks on controller 0
perccli64 /c0/eall/sall show

# Show physical disk details (enclosure 32, slot 0)
perccli64 /c0/e32/s0 show all

# Create RAID 1 virtual disk from two disks
perccli64 /c0 add vd r1 drives=32:0,32:1

# Create RAID 5 virtual disk
perccli64 /c0 add vd r5 drives=32:0,32:1,32:2

# Create RAID 10 virtual disk
perccli64 /c0 add vd r10 drives=32:0,32:1,32:2,32:3

# Delete virtual disk 0 on controller 0
perccli64 /c0/v0 del

# Set physical disk as hot spare (global)
perccli64 /c0/e32/s4 add hotsparedrive

# Set physical disk as dedicated hot spare for disk group 0
perccli64 /c0/e32/s4 add hotsparedrive dgs=0

# Start consistency check on virtual disk 0
perccli64 /c0/v0 start cc

# Show rebuild progress
perccli64 /c0/eall/sall show rebuild
```

### Addressing Scheme

```
/c<controller_number>/e<enclosure_id>/s<slot_number>   -- Physical disk
/c<controller_number>/v<virtual_disk_number>            -- Virtual disk
/c<controller_number>                                   -- Controller
```

---

## mvcli

mvcli is the CLI for Marvell (formerly PMC-Sierra) RAID controllers found in some Dell PowerEdge configurations, particularly for software-defined storage or boot RAID.

### When to Use

- Managing RAID on Marvell-based controllers (Dell BOSS-S1, BOSS-S2 cards)
- BOSS (Boot Optimized Server Storage) cards use Marvell controllers to provide mirrored M.2 boot drives
- Requires execution on the host OS

### Key Commands

```bash
# Show all info
mvcli info -o hba
mvcli info -o vd
mvcli info -o pd

# Create RAID 1 mirror for boot drives
mvcli create -o vd -r1 -d 0,1 -n BootMirror

# Delete a virtual disk
mvcli delete -o vd -n BootMirror

# Check rebuild status
mvcli info -o vd
```

---

## Ansible dellemc.openmanage Collection

The `dellemc.openmanage` Ansible collection provides idempotent modules for managing Dell PowerEdge servers at scale. Use this for fleet-wide automation.

### Installation

```bash
ansible-galaxy collection install dellemc.openmanage
```

### Core Modules

| Module | Purpose |
|---|---|
| `idrac_bios` | Configure BIOS attributes and boot order |
| `idrac_firmware` | Upload and install firmware updates |
| `idrac_server_config_profile` | Export/import full system configuration |
| `idrac_reset` | Reset (reboot) the iDRAC |
| `idrac_lifecycle_controller_status_info` | Check Lifecycle Controller readiness |
| `idrac_system_info` | Retrieve full system inventory |
| `idrac_user` | Manage iDRAC user accounts |
| `idrac_network` | Configure iDRAC network settings |
| `idrac_storage_volume` | Create/delete RAID virtual disks |
| `idrac_virtual_media` | Mount/unmount virtual media |
| `idrac_os_deployment` | Deploy OS via Lifecycle Controller |
| `redfish_info` | Generic Redfish information gathering |
| `redfish_command` | Generic Redfish command execution |
| `ome_device_info` | Gather info from OpenManage Enterprise |

### Example Playbook: Configure BIOS and Update Firmware

```yaml
---
- name: Configure Dell PowerEdge servers
  hosts: idrac_hosts
  gather_facts: false
  vars:
    idrac_user: "{{ vault_idrac_user }}"
    idrac_password: "{{ vault_idrac_password }}"

  tasks:
    - name: Set boot mode to UEFI
      dellemc.openmanage.idrac_bios:
        idrac_ip: "{{ inventory_hostname }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: false
        attributes:
          BootMode: "Uefi"
          SysProfile: "PerfOptimized"

    - name: Update iDRAC firmware from HTTP share
      dellemc.openmanage.idrac_firmware:
        idrac_ip: "{{ inventory_hostname }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: false
        share_name: "http://firmware-repo.internal/dell/"
        reboot: true
        job_wait: true
        job_wait_timeout: 900

    - name: Export Server Configuration Profile
      dellemc.openmanage.idrac_server_config_profile:
        idrac_ip: "{{ inventory_hostname }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: false
        share_name: "/workspace/scp-exports/"
        scp_file: "{{ inventory_hostname }}_scp.json"
        export_format: "JSON"
        command: "export"
```

### Inventory File Pattern

```ini
[idrac_hosts]
server01-idrac ansible_host=10.0.10.101
server02-idrac ansible_host=10.0.10.102
server03-idrac ansible_host=10.0.10.103

[idrac_hosts:vars]
ansible_connection=local
ansible_python_interpreter=/usr/bin/python3
```

---

## Local Hardware Discovery Tools

These tools run on the host OS to enumerate hardware. They do not require iDRAC credentials.

### dmidecode

Reads SMBIOS/DMI data from the system firmware. Requires root.

```bash
# Full DMI dump
dmidecode

# System product name (model)
dmidecode -s system-product-name
# Output: PowerEdge R750

# Service tag (serial number)
dmidecode -s system-serial-number
# Output: ABC1234

# Memory summary
dmidecode -t memory | grep -E "Size:|Locator:|Speed:|Manufacturer:"

# CPU information
dmidecode -t processor | grep -E "Version:|Core Count:|Thread Count:|Current Speed:"

# BIOS version
dmidecode -s bios-version
```

### lshw

Lists detailed hardware configuration. Requires root for full output.

```bash
# Full hardware listing (JSON output for parsing)
lshw -json

# Short summary
lshw -short

# Network devices only
lshw -class network

# Storage devices only
lshw -class storage
lshw -class disk

# Memory only
lshw -class memory
```

### lspci

Lists PCI devices. Useful for identifying NICs, RAID controllers, GPUs.

```bash
# List all PCI devices
lspci

# Verbose output for RAID controllers
lspci -v -d ::0104

# Show NIC details
lspci -v -d ::0200

# Show GPU/accelerator details
lspci -v -d ::0302

# Kernel driver in use
lspci -k
```

---

## Dell OpenManage Server Administrator (OMSA)

OMSA is Dell's legacy host-based management agent. It provides a web UI and CLI (`omreport`, `omconfig`) for local server management.

### Status

OMSA is **largely replaced by iDRAC** for modern deployments (15G+). Dell has discontinued OMSA for 16G servers.

### When You Might Still Encounter It

- Legacy 14G environments with established OMSA workflows
- Integration with older monitoring systems expecting OMSA SNMP data
- Environments where iDRAC network access is restricted but host OS network is available

### Key Commands (Reference Only)

```bash
# System overview
omreport system summary

# Storage (RAID) status
omreport storage controller
omreport storage vdisk

# Chassis health
omreport chassis

# Temperature readings
omreport chassis temps
```

For new deployments, use racadm, Redfish, or the Ansible collection instead of OMSA.

---

## Container-Based Approach

Running Dell management tools from a container solves several problems:

| Problem | Container Solution |
|---|---|
| Tool requires specific OS version (RHEL 8, etc.) | Container image provides the required OS |
| Tool installation pollutes host system | Tools stay isolated in the container |
| Version conflicts between tools | Pin exact versions in the Dockerfile |
| Reproducibility across admin workstations | Same container image everywhere |
| Tool availability on non-Dell hosts | Remote-mode tools work from any container host |

See `architecture/README.md` for the complete container architecture specification.
