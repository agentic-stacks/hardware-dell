# Dell Hardware Operations Skills

## Purpose

Day-to-day management operations for Dell PowerEdge servers via iDRAC, racadm, and local tools.

## Prerequisites

Set these environment variables before running any commands:

```bash
export IDRAC_HOST=192.168.1.100
export IDRAC_USER=root
export IDRAC_PASS=calvin
```

All `racadm` commands in sub-skills use the remote invocation pattern:

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS <command>
```

## Sub-Skills

| Sub-Skill | Path | Scope |
|-----------|------|-------|
| BIOS | [bios/](bios/) | BIOS attribute management, boot order, system profiles, SCP export/import |
| iDRAC | [idrac/](idrac/) | iDRAC configuration, SCP config-as-code, user/network/power/alerts management |
| RAID | [raid/](raid/) | RAID controller management via perccli64, mvcli, and racadm SCP |
| Firmware | [firmware/](firmware/) | Firmware updates, rollbacks, job queue, update ordering |
| Inventory | [inventory/](inventory/) | Hardware discovery, system info, component inventory, asset export |
| OpenManage | [openmanage/](openmanage/) | Dell OpenManage Ansible collection modules and playbooks |

## Decision Tree: Which Sub-Skill to Use

```
What do you need to do?
|
+-- View or change BIOS settings (boot mode, virtualization, performance profile)
|   -> bios/
|
+-- Configure iDRAC itself (network, users, alerts, power actions, SCP)
|   -> idrac/
|
+-- Manage storage (create/delete RAID arrays, replace drives, hot spares)
|   -> raid/
|
+-- Update or rollback firmware (BIOS, iDRAC, NIC, RAID controller)
|   -> firmware/
|
+-- Discover hardware, pull inventory, get service tag
|   -> inventory/
|
+-- Automate across a fleet with Ansible
|   -> openmanage/
```

## Common Workflows

### Initial Server Setup (ordered)

1. **Inventory** -- discover hardware, record service tag
2. **iDRAC** -- configure network, users, alerts
3. **Firmware** -- update all firmware to latest
4. **BIOS** -- set system profile for workload
5. **RAID** -- configure storage layout

### Ongoing Maintenance

1. **Firmware** -- check for and apply updates
2. **Inventory** -- verify hardware health
3. **OpenManage** -- automate fleet-wide changes
