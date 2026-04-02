# RAID Management

## Identify the RAID Controller

Before running any RAID commands, determine which controller type is installed. Using the wrong tool produces confusing errors.

```bash
# Via racadm (remote)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory RAID

# Via perccli64 (local — inside privileged container)
perccli64 /call show

# Via mvcli (local — for Marvell/S150 controllers)
mvcli info -o hba
```

### Controller Decision Tree

- **PERC H330/H730/H740/H745/H755/H965** --> use `perccli64`
- **PERC S140/S150 (Marvell software RAID)** --> use `mvcli`
- **HBA330/HBA355i (IT mode / passthrough)** --> no RAID CLI needed, drives appear as individual disks
- **BOSS-S1/BOSS-S2 (boot-optimized M.2)** --> use `mvcli` for BOSS-S1, `perccli64` for BOSS-N1

> **iDRAC10:** Same controller detection approach. 17G servers may use PERC 12 series controllers — `perccli64` remains the correct tool.

---

## perccli64: PERC Controller Operations

### View Controller and Drive Status

```bash
# Controller summary
perccli64 /c0 show

# All virtual drives
perccli64 /c0/vall show

# All physical drives
perccli64 /c0/eall/sall show

# Detailed physical drive info (serial, firmware, SMART)
perccli64 /c0/eall/sall show all
```

### RAID Level Selection

| RAID Level | Min Drives | Usable Capacity | Fault Tolerance | Best For |
|---|---|---|---|---|
| RAID 0 | 1 | 100% | None | Scratch/temp, max throughput |
| RAID 1 | 2 | 50% | 1 drive | Boot drives, OS mirrors |
| RAID 5 | 3 | (N-1)/N | 1 drive | General workloads, balanced |
| RAID 6 | 4 | (N-2)/N | 2 drives | Large arrays, high availability |
| RAID 10 | 4 | 50% | 1 per mirror | Databases, random I/O heavy |
| RAID 50 | 6 | Varies | 1 per span | Large arrays needing performance |
| RAID 60 | 8 | Varies | 2 per span | Maximum protection, large capacity |

### Create a Virtual Drive

> **WARNING: VERIFY YOU ARE TARGETING THE CORRECT CONTROLLER AND DRIVES.** Creating a virtual drive on the wrong physical drives can cause data loss.

```bash
# RAID 1 with 2 drives (enclosure 32, slots 0-1)
perccli64 /c0 add vd r1 drives=32:0-1

# RAID 5 with 4 drives
perccli64 /c0 add vd r5 drives=32:0-3

# RAID 6 with 6 drives
perccli64 /c0 add vd r6 drives=32:0-5

# RAID 10 with 4 drives
perccli64 /c0 add vd r10 drives=32:0-3

# RAID 1 with write-back cache and read-ahead
perccli64 /c0 add vd r1 drives=32:0-1 wb ra
```

### Delete a Virtual Drive

> **WARNING: DESTRUCTIVE — ALL DATA ON THIS VIRTUAL DRIVE WILL BE PERMANENTLY LOST.** Export any needed data before proceeding. This action cannot be undone.

```bash
# Delete virtual drive 0 on controller 0
perccli64 /c0/v0 del

# Force delete (if VD is in use or has a boot flag)
perccli64 /c0/v0 del force
```

### Hot Spare Management

```bash
# Assign a global hot spare
perccli64 /c0/eall/s7 add hotsparedrive

# Assign a dedicated hot spare for virtual drive 0
perccli64 /c0/eall/s7 add hotsparedrive dgs=0

# Remove a hot spare
perccli64 /c0/eall/s7 delete hotsparedrive
```

### Monitor Rebuild Progress

```bash
# Check rebuild status
perccli64 /c0/eall/sall show rebuild

# Continuous monitoring (run every 30 seconds)
watch -n 30 perccli64 /c0/eall/sall show rebuild
```

Typical rebuild times:
- 1 TB drive: 2-4 hours
- 4 TB drive: 8-16 hours
- 10 TB drive: 24-48 hours

Rebuild time increases significantly under I/O load. Consider reducing workload during rebuilds.

### Foreign Drive Handling

When drives from another server are inserted, they show as "Foreign":

```bash
# View foreign drives
perccli64 /c0/fall show

# Import foreign config (preserves existing data/RAID)
perccli64 /c0/fall import

# Clear foreign config (makes drives available as new, DATA LOST on those drives)
perccli64 /c0/fall del
```

### Controller Battery / Capacitor

```bash
# Check battery backup unit (BBU) or capacitor status
perccli64 /c0/cv show all

# Expected output includes: State = Optimal, Temperature within range
```

---

## mvcli: Marvell / S150 / BOSS-S1 Operations

### View Status

```bash
# Show all adapters
mvcli info -o hba

# Show virtual drives
mvcli info -o vd

# Show physical drives
mvcli info -o pd
```

### Create a BOSS Mirror (RAID 1)

```bash
# Create RAID 1 mirror with drives 0 and 1
mvcli create -o vd -r 1 -d 0,1 -n BootMirror
```

### BOSS Mirror Rebuild

If a BOSS M.2 drive fails:

```bash
# Check rebuild status
mvcli info -o vd

# Rebuild starts automatically when a replacement drive is inserted
# Monitor progress with:
mvcli info -o vd -s
```

---

## RAID via racadm SCP (Remote)

For remote RAID operations without local controller access, use SCP:

```bash
# Export current RAID config
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f raid-config.xml -c RAID

# View RAID status remotely
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS raid get pdisks -o
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS raid get vdisks -o
```
