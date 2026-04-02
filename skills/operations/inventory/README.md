# Hardware Inventory

## Remote Inventory (via racadm)

### Full Hardware Inventory

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory
```

### Component-Specific Inventory

```bash
# Memory (DIMMs)
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory DIMM

# CPUs
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory CPU

# NICs
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory NIC

# RAID controllers and disks
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory RAID

# Power supplies
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory PSU

# Fans
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS hwinventory Fan
```

### Service Tag

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getsvctag
```

### System Info Summary

```bash
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS getsysinfo
```

## Remote Inventory (via Redfish)

```bash
# System overview
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/Systems/System.Embedded.1 | jq '{Model, SKU, SerialNumber, BiosVersion, MemorySummary, ProcessorSummary}'

# All memory DIMMs
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/Systems/System.Embedded.1/Memory | jq '.Members'

# Storage controllers
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/Systems/System.Embedded.1/Storage | jq '.Members'
```

## Local Inventory (Inside Privileged Container)

These commands require the privileged container mode with `/dev` and `/sys` mounted.

### dmidecode — SMBIOS Data

```bash
# Full SMBIOS dump
dmidecode

# System info (manufacturer, model, serial)
dmidecode -t system

# BIOS version
dmidecode -t bios

# Memory DIMMs (size, speed, type, location)
dmidecode -t memory

# CPU info
dmidecode -t processor

# PCI slots
dmidecode -t slot
```

### lshw — Hardware Lister

```bash
# Full hardware tree
lshw

# Short summary
lshw -short

# JSON output (good for parsing)
lshw -json > /workspace/inventory/$(hostname)-hw.json

# Specific classes
lshw -class network
lshw -class storage
lshw -class memory
lshw -class processor
```

### lspci — PCI Devices

```bash
# All PCI devices
lspci

# Verbose with kernel driver info
lspci -v

# Show NIC and storage controllers with details
lspci -nn | grep -E "Ethernet|RAID|SAS|NVMe"
```

### ipmitool — Sensor Data

```bash
# All sensor readings (remote)
ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS sensor list

# Fan speeds
ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS sensor list | grep -i fan

# Temperatures
ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS sensor list | grep -i temp

# Power consumption
ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS sensor list | grep -i watt
```

## Export Inventory for Records

```bash
# JSON export via lshw (inside privileged container)
lshw -json > /workspace/inventory/server01-hw.json

# Redfish JSON export (remote)
curl -sk -u $IDRAC_USER:$IDRAC_PASS \
  https://$IDRAC_HOST/redfish/v1/Systems/System.Embedded.1 \
  | jq '.' > /workspace/inventory/server01-redfish.json

# SCP export as inventory baseline
racadm -r $IDRAC_HOST -u $IDRAC_USER -p $IDRAC_PASS get -t xml -f /workspace/inventory/server01-scp.xml
```

## Compare Inventory Across Servers

To compare two servers (e.g., verifying identical config):

```bash
# Export both
racadm -r 192.168.1.10 -u root -p $PASS getsysinfo > /workspace/inventory/server01-sysinfo.txt
racadm -r 192.168.1.11 -u root -p $PASS getsysinfo > /workspace/inventory/server02-sysinfo.txt

# Diff
diff /workspace/inventory/server01-sysinfo.txt /workspace/inventory/server02-sysinfo.txt
```
