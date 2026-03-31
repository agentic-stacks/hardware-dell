# Diagnose: Hardware Failure Diagnosis

Systematic procedures for diagnosing Dell PowerEdge hardware failures. Work through the relevant symptom section top-to-bottom. Do not skip steps.

> **iDRAC10 (17G):** Hardware diagnostic commands (`racadm lclog`, `hwinventory`, `getsysinfo`) work the same on iDRAC10. LCD error codes may include new codes for 17G-specific components — check Dell's 17G documentation for codes not listed here.

---

## Symptom: Server Won't Power On

### Decision Tree

1. Check the AC power source
   - If the wall outlet or PDU port is dead --> test with a known-good device, check breaker
   - If AC is confirmed good --> continue
2. Check PSU LEDs on the back of the chassis
   - If no LEDs are lit on any PSU --> suspect AC wiring or PDU issue, try a different power cable
   - If one PSU LED is green and another is off --> suspect failed PSU, reseat or replace the dark PSU
   - If PSU LEDs are blinking amber --> PSU fault detected, check `racadm hwinventory PSU` once iDRAC is reachable
   - If PSU LEDs are solid green --> power input is good, continue
3. Press the power button on the front panel
   - If nothing happens --> check that the power button is not disabled in iDRAC (`racadm get System.Power.PowerButtonMode`)
   - If the system begins POST --> monitor for errors during POST
4. Check iDRAC power log (if iDRAC is reachable on standby power)
   ```bash
   racadm lclog view -s last -c 20 | grep -i power
   ```
   - If log shows "Power supply lost AC input" --> confirm PDU/cable
   - If log shows "Power usage exceeded threshold" --> check power cap settings: `racadm get System.Power`
5. If none of the above resolve it --> suspect motherboard failure, open Dell support case

---

## Symptom: Amber Blinking on Chassis

### Decision Tree

1. Decode the LED blink pattern
   - Solid amber = system detected a fault but is operational
   - Blinking amber = system detected a critical fault
   - Blinking amber/green alternating = system is identifying (someone ran a locate command)
2. Check the LCD panel on the front of the chassis (if equipped)
   - Record the exact message code (e.g., "E1000", "W1228")
   - Cross-reference with the LCD Status Messages table below
3. Query iDRAC for system health
   ```bash
   racadm getsysinfo | grep -A5 "System Information"
   ```
4. Pull recent events
   ```bash
   racadm lclog view -s last -c 50
   ```
5. Check IPMI sensor data repository for any sensors in critical state
   ```bash
   ipmitool sdr list | grep -E "cr|nr"
   ```
   - "cr" = critical threshold exceeded
   - "nr" = non-recoverable
6. If the amber LED appeared after a hardware change --> reseat the changed component (DIMM, drive, PCIe card)
7. If no recent changes --> match the fault in the SEL to the correct sub-section below

---

## Symptom: Memory Errors

### Decision Tree

1. Identify the failing DIMM slot
   ```bash
   racadm hwinventory Memory | grep -B2 -A10 "Error"
   ```
2. Check ECC error counts
   ```bash
   ipmitool sel list | grep -i memory
   ```
   - Correctable ECC errors (CE) below 10 in 24 hours --> monitor, no immediate action
   - Correctable ECC errors (CE) above 100 in 24 hours --> schedule DIMM replacement
   - Uncorrectable ECC error (UE) --> DIMM has failed, replace immediately
3. Identify the exact DIMM location
   ```bash
   racadm hwinventory Memory | grep -E "DIMM\.(Slot|Status|Size|Speed|Manufacturer|PartNum|SerialNum)"
   ```
4. Check if the DIMM has been disabled by the BIOS
   ```bash
   racadm get BIOS.MemSettings
   ```
   - If MemOpMode is "OptimizerMode" and a DIMM is missing from inventory --> BIOS may have disabled a failing DIMM
5. Run embedded diagnostics if the server can be taken offline
   ```bash
   racadm diagnostics run -m memory
   ```
6. If replacing a DIMM --> match the exact part number and speed, follow Dell population rules for the platform (check the hardware owner's manual for the specific PowerEdge model)

**WARNING: Replacing DIMMs requires powering off the server. Schedule a maintenance window.**

---

## Symptom: CPU Thermal Throttling

### Decision Tree

1. Check current CPU temperatures
   ```bash
   ipmitool sdr list | grep -i temp
   ```
   - Inlet temperature above 35C --> check datacenter cooling, check for hot aisle containment breach
   - CPU temperature above 85C --> throttling is likely active
2. Check fan status
   ```bash
   ipmitool sdr list | grep -i fan
   racadm getfanreqinfo
   ```
   - If any fan shows 0 RPM --> fan has failed, replace fan module
   - If all fans are running but at maximum RPM --> airflow obstruction or failed thermal paste
3. Check for airflow obstructions
   - Verify all blanks are installed in empty drive bays and PCIe slots
   - Verify cable routing is not blocking airflow
   - Verify the air shroud / air baffle is properly seated
4. Check power/thermal profile
   ```bash
   racadm get BIOS.SysProfileSettings.SysProfile
   ```
   - If set to "PerfOptimized" --> consider switching to "PerfPerWattOptimizedDapc" for better thermal management
5. If temperatures remain critical with good airflow and working fans --> suspect thermal paste degradation or heatsink issue, open Dell support case

---

## Symptom: Fan Failures

### Decision Tree

1. Identify the failed fan
   ```bash
   racadm getfanreqinfo
   ipmitool sdr list | grep -i fan
   ```
2. Check if the failure is a single fan or multiple
   - Single fan failure --> replace the fan module (hot-swappable on most PowerEdge models)
   - Multiple simultaneous fan failures --> suspect backplane or motherboard fan controller issue
3. Reseat the fan module before replacing
   - Power off is NOT required for hot-swap fan modules on 14G and newer
   - After reseating, wait 30 seconds and recheck: `ipmitool sdr list | grep -i fan`
4. If the fan is replaced and still shows failure --> check the fan connector on the system board, open Dell support case

**WARNING: Operating without sufficient fans will cause thermal throttling and may trigger automatic shutdown. Replace failed fans immediately.**

---

## Symptom: PSU Degraded

### Decision Tree

1. Check PSU inventory and status
   ```bash
   racadm hwinventory PSU
   ```
2. Check redundancy status
   ```bash
   racadm get System.Power.Redundancy
   ```
   - "Full" = both PSUs operational
   - "Lost" = one PSU has failed, server running on single PSU
3. Check the PSU LED on the back of the chassis
   - Green = normal
   - Blinking amber = PSU fault
   - Off = no AC input or PSU failure
4. If PSU shows degraded but LED is green --> check PSU firmware, attempt `racadm racreset` to clear stale status
5. If PSU has genuinely failed
   - Confirm the server can run on the remaining PSU (check power draw vs single PSU capacity)
   - Order replacement PSU matching the exact wattage rating
   - PSU is hot-swappable on all rack-mount PowerEdge servers

**WARNING: If redundancy is lost, a failure of the remaining PSU will cause an unplanned outage. Expedite replacement.**

---

## Dell LCD Status Messages (Common Codes)

| Code | Severity | Message | Meaning | Action |
|---|---|---|---|---|
| E1000 | Critical | Failsafe voltage error | Voltage regulator failure | Power off immediately, open support case |
| E1114 | Critical | Ambient Temp exceeds allowed range | Inlet temperature too high | Check datacenter cooling |
| E1116 | Critical | Memory disabled, temp above allowed range | DIMM overheated | Check fans, check airflow |
| E1210 | Critical | Motherboard battery failure | CMOS battery dead | Replace CMOS battery at next maintenance window |
| E1211 | Warning | RAID controller battery failure | RAID BBU/capacitor failed | Replace RAID battery/capacitor |
| E122E | Critical | On-board configuration error | Config mismatch | Reseat components, clear NVRAM if needed |
| E1310 | Critical | Fan missing | Fan module removed or unseated | Reseat or replace fan module |
| E1410 | Critical | System Fatal Error detected | CPU machine check exception | Check SEL for details, may need board replacement |
| E1614 | Critical | Power supply lost AC input | AC feed interrupted | Check PDU, check power cable |
| E2010 | Critical | Memory not detected | No DIMMs found | Reseat DIMMs, check population rules |
| E2012 | Warning | Memory configuration error | DIMM population rule violated | Consult owner's manual for correct DIMM placement |
| W1228 | Warning | RAID controller degraded | Virtual disk degraded | Check storage skill for drive replacement |
| I1910 | Info | CPU thermal trip | CPU hit thermal limit | Check fans, check airflow, check ambient temp |
| I1912 | Info | SEL full | System event log is full | Clear SEL: `racadm lclog clear` |

---

## System Event Log Analysis

### Pull the log
```bash
racadm lclog view -s last -c 100
```

### Patterns to look for

| Pattern | Indicates | Action |
|---|---|---|
| Repeated "correctable memory error" on same DIMM | DIMM degrading | Schedule replacement |
| "Uncorrectable memory error" | DIMM failure | Replace immediately |
| "Predictive failure" on physical disk | Drive SMART threshold exceeded | Replace drive proactively |
| "Power supply lost AC input" followed by "Power supply AC input restored" | AC power flapping | Check PDU, check cable seating |
| "Temperature threshold exceeded" repeated | Cooling issue | Check fans, check datacenter HVAC |
| "RAID controller battery charge below threshold" | BBU degrading | Replace at next maintenance |
| "PCI parity error" | PCIe card or slot failure | Reseat card, test in different slot |
| "OS watchdog timer expired" | OS hang / kernel panic | Check OS logs, not a hardware issue unless recurring |
| "Lifecycle Controller not ready" | LC in recovery state | See known-issues for workaround |

### Export the full log for Dell support
```bash
racadm lclog export -f /tmp/lclog_export.xml
racadm techsupreport collect -t SysInfo,TTYLog
```

---

## When to Open a Dell Support Case

Open a case if:
- Any "E1xxx" critical LCD code that is not resolved by reseating components
- Uncorrectable memory errors
- Multiple simultaneous component failures
- RAID controller not detected
- POST does not complete
- Motherboard or CPU replacement is needed

### Information to gather before calling

```bash
# Service Tag (7-character alphanumeric)
racadm getsysinfo | grep "Service Tag"

# Express Service Code (numeric, derived from service tag)
racadm getsysinfo | grep "Express Svc Code"

# iDRAC firmware version
racadm getversion

# Full system event log
racadm lclog export -f /tmp/lclog.xml

# Hardware inventory
racadm hwinventory export -f /tmp/hwinventory.xml

# Tech support report (comprehensive)
racadm techsupreport collect -t SysInfo,TTYLog,OSAppAll
```

Dell ProSupport phone: 1-800-456-3355 (US). Have the service tag ready.
