# Diagnose: Troubleshooting Overview

Route the user's reported symptom to the correct diagnostic sub-skill. Ask clarifying questions only if the symptom category is ambiguous.

## Symptom Routing Table

| Symptom Category | Route To | Example Symptoms |
|---|---|---|
| Server won't power on, LED codes, memory errors, CPU throttling, fan failures, PSU issues | [hardware/](hardware/) | "Amber light blinking on front panel", "ECC errors in logs" |
| Cannot reach iDRAC, web UI down, racadm remote failures, NIC link down, VLAN issues | [connectivity/](connectivity/) | "Can't ping iDRAC", "Virtual console won't connect" |
| Drive failures, RAID degraded, foreign drives, no boot device, slow rebuild | [storage/](storage/) | "Drive showing Foreign", "VD0 is degraded" |

## Triage Decision Tree

1. Is the server physically unresponsive (no power, no LEDs, no iDRAC)?
   - Yes --> Go to [hardware/](hardware/) and start with "Server won't power on"
   - No --> continue
2. Is the server powered on but unreachable over the network?
   - Yes --> Go to [connectivity/](connectivity/) and start with "Can't reach iDRAC"
   - No --> continue
3. Is the server reachable but reporting storage alerts or boot failures?
   - Yes --> Go to [storage/](storage/)
   - No --> continue
4. Is the server reachable and reporting hardware alerts (memory, CPU, fan, PSU)?
   - Yes --> Go to [hardware/](hardware/) and match the specific symptom
   - No --> Gather more information: run `racadm getsysinfo` and `racadm lclog view -s last -c 20` to identify the fault domain

## First Steps for Any Diagnosis

Before diving into a specific sub-skill, collect baseline information:

```bash
# Get system identity and overall health
racadm getsysinfo

# Check recent system event log entries
racadm lclog view -s last -c 30

# Get hardware inventory summary
racadm hwinventory summary

# Check iDRAC alerts
racadm eventfilters get
```

If the server is not reachable via racadm, attempt IPMI:

```bash
ipmitool -I lanplus -H 10.0.0.100 -U root -P calvin chassis status
ipmitool -I lanplus -H 10.0.0.100 -U root -P calvin sel list | tail -20
```

## Escalation Criteria

Open a Dell support case if any of the following are true:
- Multiple component failures simultaneously (potential motherboard issue)
- LCD panel shows error code starting with "E1" or "E2" (critical hardware failure)
- System Event Log shows uncorrectable machine check exceptions
- RAID controller is not detected by the operating system or iDRAC
- Server is under warranty and a physical part replacement is required

Gather this information before contacting Dell support:
- Service Tag: `racadm getsysinfo | grep "Service Tag"`
- Express Service Code: convert service tag at https://www.dell.com/support
- System Event Log export: `racadm lclog export -f /tmp/lclog.xml`
- Hardware inventory: `racadm hwinventory export -f /tmp/hwinventory.xml`
- iDRAC firmware version: `racadm getversion`
