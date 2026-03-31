# Diagnose: Storage and RAID Issues

Systematic procedures for diagnosing Dell PowerEdge storage failures. Work through the relevant symptom section top-to-bottom. Do not skip steps.

---

## Symptom: RAID Array Degraded

### Decision Tree

1. Identify the degraded virtual drive
   ```bash
   perccli64 /c0/vall show
   ```
   Look for virtual drives with state `Dgrd` (Degraded).

2. Find the failed or missing physical drive
   ```bash
   perccli64 /c0/eall/sall show
   ```
   Look for drives with state:
   - `Offln` — drive is offline (failed)
   - `UBad` — unconfigured bad (drive removed or failed)
   - `Missing` — drive was part of array but is not detected

3. Check the drive error log
   ```bash
   perccli64 /c0/eall/sall show all | grep -A5 "Error Count"
   ```

4. If a hot spare is available, rebuild starts automatically
   - Monitor progress: `perccli64 /c0/eall/sall show rebuild`
   - If no hot spare --> replace the failed drive physically, then:
     ```bash
     # The new drive should appear as UGood (Unconfigured Good)
     perccli64 /c0/eall/sall show

     # Manually start rebuild if it doesn't auto-start
     perccli64 /c0/eall/s<SLOT> start rebuild
     ```

5. Check iDRAC lifecycle log for the failure event
   ```bash
   racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS lclog view -s last -c 50 | grep -i "disk\|drive\|raid\|storage"
   ```

---

## Symptom: Drive Predictive Failure

SMART monitoring or patrol reads have flagged a drive as likely to fail.

### Decision Tree

1. Identify the flagged drive
   ```bash
   perccli64 /c0/eall/sall show all | grep -B5 "Predictive"
   ```

2. Check the drive's SMART data
   ```bash
   perccli64 /c0/eall/s<SLOT> show all | grep -A20 "SMART"
   ```

3. Key indicators:
   - **Reallocated Sector Count** > 0 — drive is remapping bad sectors
   - **Current Pending Sector** > 0 — sectors waiting to be remapped
   - **Media Error Count** increasing — physical media degradation

4. Plan for replacement
   - If a hot spare is assigned, you can replace the drive during a maintenance window
   - If no hot spare, assign one first: `perccli64 /c0/eall/s<SPARE_SLOT> add hotsparedrive dgs=<VD_DG>`
   - Then swap the predicted-failure drive — rebuild will start on the hot spare

---

## Symptom: Foreign Drives Detected

Drives from another server or a previous RAID configuration show as "Foreign."

### Decision Tree

1. View foreign configuration
   ```bash
   perccli64 /c0/fall show
   ```

2. Decision:
   - **Import** (preserves the RAID config and data from the source server):
     ```bash
     perccli64 /c0/fall import
     ```
   - **Clear** (erases the foreign config — drives become available as new, DATA ON THOSE DRIVES IS LOST):
     ```bash
     perccli64 /c0/fall del
     ```

3. After import, verify the virtual drive is online:
   ```bash
   perccli64 /c0/vall show
   ```

---

## Symptom: Rebuild Stuck or Slow

### Decision Tree

1. Check rebuild progress
   ```bash
   perccli64 /c0/eall/sall show rebuild
   ```

2. If progress is 0% and not moving:
   - Check for errors: `perccli64 /c0/eall/s<SLOT> show all | grep -i error`
   - The replacement drive may be incompatible (wrong sector size, too small, unsupported model)
   - Verify drive size matches or exceeds the original: `perccli64 /c0/eall/sall show all | grep "Raw Size"`

3. If progress is moving but very slowly:
   - Rebuild rate is affected by I/O load — reduce workload if possible
   - Check rebuild rate: `perccli64 /c0 show rebuildrate`
   - Increase rebuild rate (trades I/O performance for faster rebuild):
     ```bash
     perccli64 /c0 set rebuildrate=60
     ```
     Default is 30%. Range is 0-100%.

4. Check the controller event log for errors during rebuild:
   ```bash
   perccli64 /c0 show events | tail -50
   ```

---

## Symptom: RAID Controller Battery/Capacitor Warning

### Decision Tree

1. Check BBU or capacitor status
   ```bash
   perccli64 /c0/cv show all
   ```

2. Expected healthy state:
   - State: Optimal
   - Temperature: within operating range
   - Design Capacity vs Full Charge Capacity: should be similar

3. If state is "Failed" or "Degraded":
   - Write-back cache is disabled (performance impact) — controller falls back to write-through
   - Replace the BBU/capacitor module
   - After replacement, verify: `perccli64 /c0/cv show all`

---

## Symptom: Server Won't Boot from RAID Virtual Drive

### Decision Tree

1. Verify the virtual drive exists and is online
   ```bash
   perccli64 /c0/vall show
   ```

2. Check boot order in BIOS
   ```bash
   racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.BiosBootSettings.UefiBootSeq
   ```

3. Verify the VD is set as the boot drive
   ```bash
   perccli64 /c0/v0 show all | grep "Boot Drive"
   ```

4. If the VD is not the boot drive:
   ```bash
   perccli64 /c0/v0 set bootdrive=on
   ```

5. If the VD is online but the OS won't load:
   - Check if the VD was initialized (wiped): `perccli64 /c0/v0 show init`
   - Check for filesystem corruption — boot from recovery media

---

## BOSS Card Issues

### BOSS Mirror Degraded

```bash
# Check BOSS status via mvcli
mvcli info -o vd

# If one M.2 is missing or failed, the mirror runs degraded
# Replace the failed M.2 — rebuild starts automatically
mvcli info -o vd -s  # Monitor rebuild progress
```

### BOSS Drive Not Detected

- Reseat the BOSS card (requires powering off)
- Check that both M.2 modules are firmly seated in the BOSS carrier
- If one M.2 is consistently not detected, it may have failed — replace it
