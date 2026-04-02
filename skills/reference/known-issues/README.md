# Known Issues

Check this reference before performing firmware updates, upgrades, or when encountering unexpected behavior. Issues are organized by iDRAC firmware version.

## How to Use

1. Identify your current iDRAC firmware version: `racadm getversion`
2. Check the section below for your version range
3. Review known issues before proceeding with updates or changes

---

## iDRAC9 Firmware Issues

### iDRAC9 3.x-4.x (14G)

#### SCP Import Fails with "Invalid XML" on Large Files

**Symptom:** SCP import via `racadm set -t xml -f` fails with "Invalid XML" error on SCP files larger than ~2MB.
**Cause:** Early iDRAC9 firmware had a buffer size limitation for SCP processing.
**Workaround:** Split the SCP into component-filtered imports:
```bash
racadm set -t xml -f scp.xml -c BIOS
racadm set -t xml -f scp.xml -c iDRAC
racadm set -t xml -f scp.xml -c NIC
```
**Affected versions:** iDRAC9 3.00.00.00 through 3.36.36.36
**Status:** Fixed in iDRAC9 4.00.00.00

#### racadm Hangs After Firmware Update

**Symptom:** `racadm` commands hang or return timeout after iDRAC firmware update.
**Cause:** iDRAC web services need restart after certain firmware transitions.
**Workaround:** Wait 5 minutes, then reset iDRAC:
```bash
ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS mc reset cold
```
**Affected versions:** iDRAC9 3.x transitioning to 4.x
**Status:** Expected behavior during major version transitions

### iDRAC9 5.x-6.x (15G)

#### Lifecycle Controller Jobs Stuck in "Scheduled" State

**Symptom:** Jobs created via `racadm jobqueue create` remain in "Scheduled" state and never execute, even after reboot.
**Cause:** Job queue corruption can occur if the server is hard-reset during job execution.
**Workaround:** Clear the job queue and recreate:
```bash
racadm jobqueue delete --all
racadm jobqueue create BIOS.Setup.1-1 -r pwrcycle
```
**Affected versions:** iDRAC9 5.00.00.00 through 5.10.50.00
**Status:** Improved in iDRAC9 6.00.00.00

#### Virtual Console Black Screen with HTML5

**Symptom:** HTML5 virtual console shows black screen, Java console works.
**Cause:** Browser compatibility issue with iDRAC HTML5 viewer.
**Workaround:** Use Chrome or Firefox. Clear browser cache. Alternatively, use the Java console plugin.
**Affected versions:** iDRAC9 5.x with certain browser versions
**Status:** Improved in iDRAC9 6.00.30.00

### iDRAC9 7.x+ (16G)

#### PERC Firmware Update Requires Two Reboots

**Symptom:** After PERC firmware update, first reboot shows "Update in progress" but firmware version doesn't change. Second reboot applies the update.
**Cause:** PERC firmware staging requires an initial reboot to stage, then a second reboot to apply.
**Workaround:** This is expected behavior — plan for two reboot cycles when updating PERC firmware.
**Affected versions:** iDRAC9 7.x with PERC 11/12 controllers
**Status:** By design

#### SCP Export Includes Empty RAID Components on HBA-Only Servers

**Symptom:** SCP export on servers with HBA (not PERC) controllers includes empty RAID component sections that cause warnings on import.
**Cause:** SCP export includes all component templates regardless of installed hardware.
**Workaround:** Use component-filtered export to exclude RAID: `racadm get -t xml -f scp.xml -c BIOS,iDRAC,NIC`
**Affected versions:** iDRAC9 7.00.00.00+
**Status:** Open

---

## iDRAC10 (17G)

> **iDRAC10 (early documentation):** iDRAC10 is new with PowerEdge 17G servers. Known issues will be populated as the platform matures. Check Dell's release notes for the latest information.

#### racadm Syntax Differences

**Symptom:** Some racadm subcommands have different output formatting in iDRAC10 compared to iDRAC9.
**Cause:** iDRAC10 is built on a new software platform with Redfish as the primary API.
**Workaround:** For scripting, prefer Redfish API over racadm output parsing. racadm commands remain functional but output format may differ.
**Affected versions:** iDRAC10 1.x
**Status:** Expected — Redfish is the recommended API for iDRAC10.

---

## Tool-Specific Issues

### perccli64: "No Controller Found" on S150

**Symptom:** `perccli64 /call show` returns no controllers on servers with S150 software RAID.
**Cause:** S150 is a Marvell-based software RAID controller, not a PERC hardware controller.
**Workaround:** Use `mvcli` instead of `perccli64` for S150 controllers.
**Affected versions:** All perccli64 versions
**Status:** By design — use the correct tool for the controller type.
