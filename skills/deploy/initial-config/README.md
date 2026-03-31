# Initial Configuration

## Purpose

Perform first-time iDRAC and server configuration: set network parameters, change default credentials, configure NTP/DNS, enable Redfish, set up SNMP alerts, and export a baseline Server Configuration Profile (SCP).

> **iDRAC10:** All initial configuration commands in this guide work with iDRAC10 (17G). The Redfish endpoints are the same. racadm syntax is unchanged.

## Prerequisites

| Requirement | How to Verify |
|---|---|
| Dell tools container running | `docker ps --filter name=dell-tools` shows a running container |
| Network path to iDRAC (or local access) | `docker exec dell-tools ping -c 3 192.168.1.100` |
| iDRAC default credentials | root / calvin (or your known credentials) |

## Step 1: Discover the iDRAC IP Address

### From the Physical Host (Local Access)

If you are on the Dell server itself or have the dell-tools container running in privileged mode:

```bash
docker exec dell-tools racadm getniccfg
```

Look for the `IP Address`, `Subnet Mask`, and `Default Gateway` lines in the output. If DHCP is enabled, the IP shown is the DHCP-assigned address.

### From DHCP Leases or Network Scan

If you do not have local access, check your DHCP server's lease table for the iDRAC MAC address (printed on the server's service tag pull-out label) or scan the management VLAN:

```bash
nmap -sn 192.168.1.0/24
```

## Step 2: Set iDRAC Static IP

Skip this step if the iDRAC already has the correct static IP.

### From the Physical Host (Local racadm)

```bash
docker exec dell-tools racadm setniccfg -s 192.168.1.100 255.255.255.0 192.168.1.1
```

Arguments: `<IP> <SubnetMask> <Gateway>`

### From Remote racadm (if iDRAC has a temporary DHCP address)

```bash
docker exec dell-tools racadm -r 192.168.1.50 -u root -p calvin setniccfg -s 192.168.1.100 255.255.255.0 192.168.1.1
```

Replace `192.168.1.50` with the current DHCP-assigned IP.

After changing the IP, wait 30 seconds for the iDRAC to apply the new network configuration before proceeding.

## Step 3: Verify Remote Connectivity

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p calvin getversion
```

Expected: firmware version information for iDRAC, BIOS, and lifecycle controller. If this command succeeds, remote management is functional.

### If Connection Fails

| Symptom | Likely Cause | Fix |
|---|---|---|
| Connection timed out | Wrong IP or firewall | Verify IP from Step 1; open TCP 443 to iDRAC |
| SSL certificate error | Self-signed cert | Add `--nocertwarn` flag to racadm commands |
| Authentication failed | Wrong credentials | Verify credentials; try default root/calvin |

## Step 4: Change the Default iDRAC Password

> **CRITICAL: DEFAULT CREDENTIALS ARE A SECURITY RISK.**
>
> Dell servers ship with the default iDRAC credentials root / calvin. These are publicly known. An attacker with network access to the iDRAC port can gain full hardware control, including remote console, power cycling, BIOS modification, and virtual media mounting.
>
> **Change the default password immediately before connecting the iDRAC to any production or shared network.**

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p calvin set iDRAC.Users.2.Password NewSecurePassword123!
```

Notes:
- User index `2` is the default root account on Dell iDRACs.
- Choose a password that meets your organization's complexity requirements (minimum 8 characters, mixed case, numbers, special characters).
- Record the new password in your secrets manager immediately.

Verify the new password works:

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p 'NewSecurePassword123!' getversion
```

**From this point forward, all commands use the new credentials.** The examples below use `-u root -p PASS` as shorthand. Replace `PASS` with your actual password.

## Step 5: Set Server Hostname

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.Info.Name servername
```

Replace `servername` with the intended hostname (e.g., `prod-db-01`, `web-front-03`).

## Step 6: Configure NTP

### Enable NTP

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.NTPConfigGroup.NTPEnable Enabled
```

### Set NTP Servers

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.NTPConfigGroup.NTP1 0.pool.ntp.org
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.NTPConfigGroup.NTP2 1.pool.ntp.org
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.NTPConfigGroup.NTP3 2.pool.ntp.org
```

Replace with your organization's NTP servers if you operate internal time sources.

### Set Timezone

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.Time.Timezone UTC
```

### Verify NTP Configuration

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get iDRAC.NTPConfigGroup
```

## Step 7: Configure DNS

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.IPv4.DNS1 8.8.8.8
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.IPv4.DNS2 8.8.4.4
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.NIC.DNSDomainName example.com
```

Replace DNS servers and domain name with your site values.

### Verify DNS Configuration

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get iDRAC.IPv4.DNS1
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get iDRAC.IPv4.DNS2
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get iDRAC.NIC.DNSDomainName
```

## Step 8: Enable Redfish API

Redfish provides the modern REST API for programmatic server management. Many Ansible modules and automation scripts require it.

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.Webserver.Enable Enabled
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.Redfish.Enable Enabled
```

### Verify Redfish is Accessible

```bash
docker exec dell-tools curl -sk -u root:PASS https://192.168.1.100/redfish/v1/ | python3 -m json.tool
```

Expected: JSON response containing `@odata.id`, `RedfishVersion`, and `Systems` link.

## Step 9: Set Up SNMP Alerts

### Enable SNMP

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.SNMP.AgentEnable Enabled
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.SNMP.AgentCommunity public
```

### Configure SNMP Trap Destination

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.SNMP.Alert.1.Enable Enabled
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.SNMP.Alert.1.DestAddr 192.168.1.200
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS set iDRAC.SNMP.Alert.1.SNMPv3UserID 1
```

Replace `192.168.1.200` with your SNMP trap receiver / monitoring server IP.

### Verify SNMP Configuration

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get iDRAC.SNMP
```

## Step 10: Export Baseline Server Configuration Profile (SCP)

The SCP captures the complete server configuration (BIOS, iDRAC, RAID, NIC settings) as an XML file. Export this immediately after initial configuration to establish a known-good baseline.

> **WARNING: The SCP file contains sensitive configuration data including network settings and user references. Store it securely and do not commit it to public repositories.**

```bash
docker exec dell-tools racadm -r 192.168.1.100 -u root -p PASS get -t xml -f /workspace/configs/baseline-scp.xml
```

### Verify the Export

```bash
docker exec dell-tools ls -la /workspace/configs/baseline-scp.xml
docker exec dell-tools head -20 /workspace/configs/baseline-scp.xml
```

Expected: a valid XML file starting with `<SystemConfiguration>`.

### Store the Baseline

The exported SCP is available on the host at `workspace/configs/baseline-scp.xml` (the workspace directory is bind-mounted into the container).

```bash
ls -la workspace/configs/baseline-scp.xml
```

Keep this file as the reference baseline. Future configuration drift can be detected by exporting a new SCP and comparing it to this baseline.

## Completion Checklist

| Step | Verification Command | Expected Result |
|---|---|---|
| Static IP set | `racadm -r 192.168.1.100 -u root -p PASS getniccfg` | Correct IP, mask, gateway |
| Password changed | `racadm -r 192.168.1.100 -u root -p PASS getversion` | Succeeds with new password |
| Hostname set | `racadm -r ... get iDRAC.Info.Name` | Shows configured hostname |
| NTP enabled | `racadm -r ... get iDRAC.NTPConfigGroup` | NTPEnable=Enabled, servers set |
| DNS configured | `racadm -r ... get iDRAC.IPv4.DNS1` | Shows configured DNS server |
| Redfish enabled | `curl -sk https://192.168.1.100/redfish/v1/` | Returns JSON |
| SNMP alerts set | `racadm -r ... get iDRAC.SNMP` | AgentEnable=Enabled, trap dest set |
| Baseline SCP saved | `ls workspace/configs/baseline-scp.xml` | File exists, non-empty |

All verification commands above should be prefixed with `docker exec dell-tools` when running from outside the container.

## Next Steps

Initial configuration is complete. Proceed to the next phase of the agentic stack (e.g., RAID configuration, firmware updates, OS deployment).
