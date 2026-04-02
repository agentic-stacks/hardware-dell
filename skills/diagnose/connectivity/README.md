# Diagnose: iDRAC and Network Connectivity

Systematic procedures for diagnosing iDRAC reachability and network issues. Work through the relevant symptom section top-to-bottom. Do not skip steps.

---

## Symptom: iDRAC Unreachable

### Decision Tree

1. Verify the iDRAC IP address is correct
   - Confirm the expected IP: check `.env`, asset records, or the server's front LCD panel
   - If the IP is unknown --> physically access the server, press the LCD `i` button to display the iDRAC IP

2. Ping the iDRAC IP from the management network
   ```bash
   ping -c 3 $IDRAC_HOST
   ```
   - If ping succeeds --> iDRAC is on the network, skip to step 5 (port check)
   - If ping fails --> continue to step 3

3. Check Layer 2 connectivity
   ```bash
   # Check ARP table for the iDRAC MAC
   arp -n | grep $IDRAC_HOST

   # If no ARP entry, the iDRAC is not on the same L2 segment or is down
   ```
   - If no ARP entry --> check physical cabling, switch port, VLAN assignment
   - If ARP entry exists but ping fails --> possible firewall or IP conflict

4. Check iDRAC NIC mode and network settings
   - **Dedicated port**: iDRAC has its own physical NIC (labeled "iDRAC" on the back panel). Verify the cable is plugged into this port, not a LOM port.
   - **Shared LOM**: iDRAC shares a LOM NIC with the host OS. Verify the LOM is connected and the switch port allows the iDRAC VLAN.
   - **Failover**: iDRAC uses dedicated port with failover to LOM.

   If you have physical or out-of-band access:
   ```bash
   racadm get iDRAC.NIC.Selection
   # Dedicated = 1, LOM1 = 2, LOM2 = 3, LOM3 = 4, LOM4 = 5
   ```

5. Verify required ports are open
   ```bash
   # HTTPS (web UI and racadm remote)
   nc -zv $IDRAC_HOST 443

   # IPMI over LAN
   nc -zv $IDRAC_HOST 623

   # SSH (if enabled)
   nc -zv $IDRAC_HOST 22

   # Virtual console (VNC)
   nc -zv $IDRAC_HOST 5900
   ```
   - If port 443 is closed --> check firewall rules between management network and iDRAC network
   - If port 443 is open but racadm fails --> check TLS version or certificate issues

6. Test IPMI as a fallback
   ```bash
   ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS chassis status
   ```
   - If IPMI works but HTTPS doesn't --> iDRAC web service may be hung, try `racadm racreset` via IPMI:
     ```bash
     ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS mc reset cold
     ```

7. If nothing works remotely
   - Physically access the server
   - Use the front panel LCD to verify IP settings
   - Connect a laptop to the dedicated iDRAC port directly with a crossover or patch cable
   - Use the default IP `192.168.0.120` if iDRAC was reset to defaults

---

## Symptom: racadm Connection Errors

### "ERROR: Unable to connect to RAC"

- Verify IP, username, and password
- Check HTTPS port 443 is reachable: `nc -zv $IDRAC_HOST 443`
- Try adding `-S` flag for certificate issues: `racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS -S getsysinfo`

### "Certificate verification failed"

```bash
# Skip certificate verification (acceptable for lab/management networks)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS --nocertwarn getsysinfo
```

### "Connection timed out"

- iDRAC may be resetting or updating firmware
- Wait 5 minutes and retry
- Check if iDRAC is in recovery mode (front panel LCD shows recovery message)

---

## Symptom: NIC Link Down

### Check via racadm

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory NIC
```

### Check via LLDP (Inside Privileged Container)

```bash
# Start LLDP daemon
systemctl start lldpd

# View LLDP neighbors (shows switch name, port, VLAN)
lldpcli show neighbors
```

If no LLDP neighbors appear:
- Cable is disconnected or faulty
- Switch port is disabled
- Switch does not have LLDP enabled

---

## Required Ports Reference

| Port | Protocol | Service | Direction |
|---|---|---|---|
| 443 | TCP | HTTPS (web UI, Redfish, racadm remote) | Mgmt → iDRAC |
| 623 | UDP | IPMI over LAN | Mgmt → iDRAC |
| 22 | TCP | SSH (if enabled) | Mgmt → iDRAC |
| 5900 | TCP | VNC (virtual console) | Mgmt → iDRAC |
| 80 | TCP | HTTP (redirects to 443) | Mgmt → iDRAC |
| 69 | UDP | TFTP (firmware upload, legacy) | Mgmt → iDRAC |
| 25/587 | TCP | SMTP (email alerts) | iDRAC → Mail server |
| 162 | UDP | SNMP traps | iDRAC → Trap receiver |
| 514 | UDP/TCP | Syslog | iDRAC → Syslog server |
