# iDRAC Configuration Management

> **iDRAC10:** SCP export/import works the same way. iDRAC10 adds Redfish-based alternatives for most SCP operations. For new automation, consider using Redfish directly.

## Server Configuration Profile (SCP) -- Config-as-Code

SCP is the primary mechanism for treating Dell server configuration as code. It captures every configurable setting across all components into a single XML or JSON file.

### Full SCP Export

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f full-scp.xml
```

### Full SCP Import

> **WARNING: DESTRUCTIVE** -- Importing a full SCP can change ALL server settings including BIOS, RAID, NIC, and iDRAC configuration. Always review the SCP file contents before importing. Test on a non-production server first.

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set -t xml -f full-scp.xml
```

### Component-Filtered Export

Use `-c` to export only specific components:

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f idrac-config.xml -c iDRAC
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f bios-config.xml -c BIOS
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f nic-config.xml -c NIC
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f raid-config.xml -c RAID
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f fc-config.xml -c FC
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f lc-config.xml -c LifecycleController
```

### Component-Filtered Import

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set -t xml -f idrac-config.xml -c iDRAC
```

### JSON Format

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t json -f full-scp.json
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set -t json -f full-scp.json
```

### SCP GitOps Workflow

1. Export the current SCP from the reference server:
   ```bash
   racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f scp-baseline.xml
   ```
2. Commit `scp-baseline.xml` to a Git repository.
3. Make changes to the XML file in a feature branch.
4. Review the diff in a pull request.
5. After merge, import the updated SCP to target servers:
   ```bash
   racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set -t xml -f scp-baseline.xml
   ```
6. Export again from the target to confirm convergence:
   ```bash
   racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f scp-verify.xml
   diff scp-baseline.xml scp-verify.xml
   ```

## iDRAC Network Settings

### View current network configuration

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get iDRAC.NIC
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get iDRAC.IPv4
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get iDRAC.IPv6
```

### Set static IP

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.DHCPEnable Disabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.Address 192.168.1.101
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.Netmask 255.255.255.0
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.Gateway 192.168.1.1
```

### Set DNS servers

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.DNS1 8.8.8.8
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.IPv4.DNS2 8.8.4.4
```

### Configure VLAN tagging

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.NIC.VLanEnable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.NIC.VLanID 100
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.NIC.VLanPriority 0
```

### Set dedicated vs shared NIC mode

```bash
# Dedicated iDRAC NIC (recommended for production)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.NIC.Selection Dedicated

# Shared with LOM1 (on-board NIC)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.NIC.Selection LOM1
```

## User Management

### List all user slots (iDRAC supports slots 2-16)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get iDRAC.Users
```

### View a specific user slot

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get iDRAC.Users.3
```

### Create a new user (slot 3)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.UserName admin2
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.Password S3cur3P@ssw0rd
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.Enable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.Privilege 0x1ff
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.IpmiLanPrivilege Administrator
```

### Privilege levels

| Hex Value | Role | Description |
|-----------|------|-------------|
| `0x1ff` | Administrator | Full access to all features |
| `0x0f3` | Operator | Cannot change user accounts or iDRAC settings |
| `0x001` | Read Only | View-only access |

### Change the default root password

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.2.Password N3wS3cur3P@ss
```

### Disable a user account

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.Users.3.Enable Disabled
```

## Alert and SNMP Configuration

### Enable SNMP alerts

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SNMP.AgentEnable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SNMP.AgentCommunity public
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SNMP.TrapFormat SNMPv2
```

### Configure SNMP trap destination

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SNMP.Alert.1.Enable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SNMP.Alert.1.DestAddr 192.168.1.50
```

### Enable email alerts

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.EmailAlert.1.Enable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.EmailAlert.1.Address ops-alerts@example.com
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SMTP.ServerAddress smtp.example.com
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SMTP.ServerPort 587
```

## Virtual Console and Virtual Media

### Enable virtual console

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.VirtualConsole.PluginType HTML5
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.VirtualConsole.Enabled Enabled
```

### Attach virtual media ISO

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS remoteimage -c -u http://192.168.1.10/images/ubuntu-22.04.iso
```

### Detach virtual media

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS remoteimage -d
```

### Check virtual media status

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS remoteimage -s
```

## Power Management

### Power actions

```bash
# Power on the server
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction poweron

# Graceful shutdown (ACPI signal to OS)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction graceshutdown

# Hard power off (immediate, no OS signal)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction poweroff

# Power cycle (hard off then on)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction powercycle

# Hard reset (warm reboot)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction hardreset
```

> **WARNING:** `poweroff` and `powercycle` are non-graceful. Use `graceshutdown` when the OS is running to avoid filesystem corruption.

### Check power status

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS serveraction powerstatus
```

### Check power consumption

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get System.Power
```

## Remote Syslog Configuration

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SysLog.SysLogEnable Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SysLog.Server1 192.168.1.60
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set iDRAC.SysLog.Port1 514
```

## SSL Certificate Management

### View current certificate

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS sslcertview -t 1
```

### Upload a custom SSL certificate

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS sslcertupload -t 1 -f /path/to/server.crt
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS sslkeyupload -t 1 -f /path/to/server.key
```

### Generate a new CSR

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS sslcsrgen -g -f idrac.csr
```

### Reset iDRAC after certificate change

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS racreset
```

## License Management

### View installed licenses

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS license view
```

### Import a license

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS license import -f /path/to/license.xml
```

### Delete a license

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS license delete -e <entitlement_id>
```

## Auto-Update Configuration

### Enable auto-update from Dell repository

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.AutoUpdate Enabled
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.CatalogHttpAddress downloads.dell.com
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.CatalogHttpPath /catalog/catalog.xml.gz
```

### Schedule auto-update frequency

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.AutoUpdateFrequency Weekly
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.AutoUpdateDay Sunday
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS set LifecycleController.LCAttributes.AutoUpdateTime 02:00
```

## Lifecycle Controller Log

### View recent LC log entries

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS lclog view
```

### View LC log with severity filter

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS lclog view -s critical
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS lclog view -s warning
```

### Export LC log

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS lclog export -f lclog-export.xml
```

## iDRAC Reset

### Soft reset (iDRAC services restart, no host impact)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS racreset soft
```

### Hard reset (full iDRAC reboot, no host impact)

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS racreset hard
```

> **Note:** After `racreset`, iDRAC will be unreachable for 2-5 minutes while it reboots. Wait and retry connection before proceeding with further commands.
