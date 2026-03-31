# Firmware Management

## Check Current Firmware Versions

```bash
# Remote — all installed firmware via racadm
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS swinventory

# Remote — iDRAC firmware version only
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getversion

# Remote — via Redfish
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/UpdateService/FirmwareInventory | jq '.Members'
```

## Update Order

> **CRITICAL:** Always update firmware in this order. Updating out of order can cause compatibility issues or failed updates.

1. **iDRAC firmware** — update first, reboot iDRAC (`racadm racreset`)
2. **BIOS** — update second, requires host reboot
3. **Components** — NIC, PERC, BOSS, PSU, CPLD — update last

## Dell Update Package (DUP) Install

DUPs are single-component firmware packages downloaded from Dell support.

### Download a DUP

Download the appropriate `.EXE` (Linux DUP) from [Dell Support](https://www.dell.com/support) for your server's service tag, or from the [Dell Repository](https://www.dell.com/support/kbdoc/en-us/000130826/update-dell-emc-poweredge-servers-using-dell-update-package-dup).

Place the DUP file in `workspace/firmware/`.

### Install via racadm

```bash
# Upload and install a DUP (iDRAC firmware example)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS update -f /workspace/firmware/iDRAC-with-Lifecycle-Controller_Firmware_xxxxx.EXE

# Check job status
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue view
```

### Install via Redfish (HTTP Push)

```bash
# Push a DUP via Redfish multipart HTTP push
# First, get the HttpPushUri
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/UpdateService | jq '.HttpPushUri'

# Upload the DUP to the push URI
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/workspace/firmware/BIOS_xxxxx.EXE \
  https://$IDRAC_HOST/redfish/v1/UpdateService/FirmwareInventory
```

> **Note:** The Redfish firmware upload method varies by iDRAC firmware version. For simplicity, `racadm update -f` is the most reliable cross-version approach. Use Redfish when building API-driven automation.

## Dell System Update (DSU)

DSU automates multi-component firmware updates using the Dell catalog.

> **iDRAC10:** DSU continues to work with 17G servers. The catalog includes iDRAC10 firmware packages.

```bash
# Install DSU inside the container (if not already present)
# Download the latest DSU from Dell's support site for your server model
# URL changes per release — search "Dell System Update Linux" at dell.com/support
wget --header="$DELL_UA" -O /tmp/dsu.tar.gz <DSU_DOWNLOAD_URL>
cd /tmp && tar xzf dsu.tar.gz && bash install.sh

# Run DSU — preview mode (shows what would be updated, no changes)
dsu --preview

# Run DSU — apply all applicable updates
dsu --non-interactive

# Run DSU — update specific component category
dsu --component-type=BIOS
dsu --component-type=iDRAC
```

## Job Queue Management

Firmware updates create jobs in the iDRAC job queue. Some require a host reboot to apply.

```bash
# View all jobs
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue view

# View a specific job
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue view -i JID_xxxxxxxxxxxx

# Delete a specific job
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue delete -i JID_xxxxxxxxxxxx

# Delete ALL jobs (use with caution)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue delete --all

# Create a reboot job to apply pending updates
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle
```

### Job States

| State | Meaning |
|---|---|
| Scheduled | Job is queued, waiting for reboot |
| Running | Job is executing (during POST or iDRAC reset) |
| Completed | Job finished successfully |
| Failed | Job failed — check lclog for details |
| Downloaded | Firmware staged to iDRAC, not yet applied |

## Firmware Rollback

iDRAC stores the previous firmware version for most components and can roll back.

```bash
# List available rollback versions
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS swinventory | grep -A3 "Rollback"

# Rollback iDRAC firmware to previous version
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS rollback iDRAC.Embedded.1-1

# Rollback BIOS
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS rollback BIOS.Setup.1-1
```

After rollback, check the job queue and reboot if required.

## Staging vs Immediate Apply

- **iDRAC firmware:** applies immediately after upload, then requires `racadm racreset` (no host reboot needed)
- **BIOS firmware:** stages to iDRAC, applies on next host reboot
- **Component firmware (NIC, PERC, etc.):** some apply immediately, some require host reboot — check the job queue state

## Pre-Update Checklist

1. Export current SCP as backup: `racadm get -t xml -f pre-update-scp.xml`
2. Check `skills/reference/known-issues/` for version-specific problems
3. Verify current versions: `racadm swinventory`
4. Ensure no active jobs: `racadm jobqueue view`
5. Plan for reboot window if BIOS or component updates are included
6. Update iDRAC first, wait for it to come back online, then proceed
