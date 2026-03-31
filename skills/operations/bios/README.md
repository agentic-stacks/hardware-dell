# BIOS Configuration Management

> **iDRAC10:** BIOS attribute paths and `racadm set` syntax are the same on iDRAC10. The Redfish BIOS endpoint is: `GET /redfish/v1/Systems/System.Embedded.1/Bios`

## View Current BIOS Settings

### List all BIOS attribute groups

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.
```

### View a specific group

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.SysProfileSettings
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.BiosBootSettings
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.ProcSettings
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.MemSettings
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.IntegratedDevices
```

### View a single attribute

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.SysProfileSettings.SysProfile
```

## Common BIOS Settings Reference

| Category | Attribute Path | Values | Notes |
|----------|---------------|--------|-------|
| Boot Mode | `BIOS.BiosBootSettings.BootMode` | `Uefi`, `Bios` | UEFI required for >2TB boot, Secure Boot |
| Boot Sequence | `BIOS.BiosBootSettings.BootSeq` | Comma-separated device list | See boot order section |
| System Profile | `BIOS.SysProfileSettings.SysProfile` | `PerfOptimized`, `PerfPerWattOptimizedDapc`, `PerfPerWattOptimizedOs`, `DenseCfgOptimized`, `Custom` | Controls power/performance tradeoff |
| Virtualization (VT-x) | `BIOS.ProcSettings.ProcVirtualization` | `Enabled`, `Disabled` | Required for hypervisors |
| VT-d | `BIOS.IntegratedDevices.IoatDmaEngine` | `Enabled`, `Disabled` | Required for device passthrough |
| SR-IOV | `BIOS.IntegratedDevices.SriovGlobalEnable` | `Enabled`, `Disabled` | Required for NIC virtualization |
| Logical Processor | `BIOS.ProcSettings.LogicalProc` | `Enabled`, `Disabled` | Hyperthreading |
| Node Interleave | `BIOS.MemSettings.NodeInterleave` | `Enabled`, `Disabled` | Disable for NUMA-aware workloads |
| Memory Operating Mode | `BIOS.MemSettings.MemOpMode` | `OptimizerMode`, `SpareMode`, `MirrorMode` | SpareMode/MirrorMode reduce capacity |
| C-States | `BIOS.SysProfileSettings.ProcCStates` | `Enabled`, `Disabled` | Disable for latency-sensitive workloads |
| Turbo Mode | `BIOS.SysProfileSettings.ProcTurboMode` | `Enabled`, `Disabled` | Keep enabled for most workloads |
| TPM Security | `BIOS.SysSecurity.TpmSecurity` | `On`, `Off` | Required for BitLocker, measured boot |

## Set BIOS Attributes

### Set a single attribute

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.SysProfile PerfOptimized
```

### Set multiple attributes

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.ProcVirtualization Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.LogicalProc Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.IntegratedDevices.SriovGlobalEnable Enabled
```

### Create a BIOS config job to apply pending changes

BIOS changes are staged -- they require a config job and a reboot to take effect.

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1
```

To apply immediately with automatic reboot:

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

To schedule for a maintenance window:

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s 20260401020000 -e 20260401040000
```

The `-s` and `-e` flags set start and end time in `YYYYMMDDHHmmss` format (UTC).

### Check job status

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue view
```

## BIOS Import/Export via Server Configuration Profile (SCP)

SCP allows config-as-code management of BIOS settings.

### Export BIOS configuration to XML

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f bios-config.xml -c BIOS
```

### Export BIOS configuration to JSON

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t json -f bios-config.json -c BIOS
```

### Import BIOS configuration from XML

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set -t xml -f bios-config.xml -c BIOS
```

The `-c` flag filters the SCP to a specific component. Valid component values:

| Component | Description |
|-----------|-------------|
| `BIOS` | BIOS attributes only |
| `iDRAC` | iDRAC configuration only |
| `NIC` | Network adapter settings |
| `RAID` | RAID controller and virtual disk configuration |
| `FC` | Fibre Channel HBA settings |
| `LifecycleController` | Lifecycle Controller settings |
| `All` | Every component (default if `-c` is omitted) |

## Boot Order Management

### View current boot order

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.BiosBootSettings.BootSeq
```

### View UEFI boot order

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get BIOS.BiosBootSettings.UefiBootSeq
```

### Set boot order (BIOS mode)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.BootSeq HardDisk.List.1-1,NIC.Integrated.1-1-1,Optical.SATAEmbedded.J-1
```

### Set one-time boot device (next boot only)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.OneTimeBootMode OneTimeBootSeq
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.OneTimeBootSeqDev NIC.Integrated.1-1-1
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

## Reset BIOS to Defaults

> **WARNING: DESTRUCTIVE** -- This resets ALL BIOS settings to factory defaults including boot order, system profile, and security settings. Verify current settings with an SCP export before proceeding.

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MiscSettings.BiosDefault Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

## Workload-Specific BIOS Profiles

### Virtualization Host (ESXi, KVM, Hyper-V)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.BootMode Uefi
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.ProcVirtualization Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.LogicalProc Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.IntegratedDevices.SriovGlobalEnable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.SysProfile PerfOptimized
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MemSettings.NodeInterleave Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

### Database Server (SQL Server, Oracle, PostgreSQL)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.BootMode Uefi
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.SysProfile PerfOptimized
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.ProcCStates Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.ProcTurboMode Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MemSettings.NodeInterleave Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.LogicalProc Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

### HPC / Compute Node

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.SysProfile PerfOptimized
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.ProcCStates Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.ProcTurboMode Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.LogicalProc Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MemSettings.NodeInterleave Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MemSettings.MemOpMode OptimizerMode
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```

### Storage Server (NAS, SAN, Ceph, MinIO)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.BiosBootSettings.BootMode Uefi
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.SysProfileSettings.SysProfile PerfPerWattOptimizedDapc
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.ProcSettings.LogicalProc Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.MemSettings.MemOpMode OptimizerMode
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set BIOS.IntegratedDevices.SriovGlobalEnable Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW -e TIME_NA
```
