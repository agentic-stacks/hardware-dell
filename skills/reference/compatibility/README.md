# Compatibility Matrices

Quick-reference tables for which tools and versions work with which hardware.

## PowerEdge Generation × iDRAC Firmware

| Generation | iDRAC Version | Firmware Range | Processor Families |
|---|---|---|---|
| 14G | iDRAC9 | 3.00.00.00 – 4.40.00.00 | Xeon Scalable Gen 1/2 |
| 15G | iDRAC9 | 5.00.00.00 – 6.10.80.00 | Xeon Scalable Gen 3, EPYC 7003 |
| 16G | iDRAC9 | 7.00.00.00+ | Xeon Scalable Gen 4/5, EPYC 9004 |
| 17G | iDRAC10 | 1.00.00.00+ | Xeon 6, EPYC next-gen |

> **iDRAC10 (early documentation):** Version ranges will expand as Dell releases firmware updates.

## iDRAC Tools (racadm) × iDRAC Version

| iDRAC Tools Version | iDRAC9 | iDRAC10 | Notes |
|---|---|---|---|
| 10.x | Yes | No | Legacy, end of support |
| 11.x | Yes | Partial | Current default in container |
| 12.x (if available) | Yes | Yes | Check Dell downloads for 17G support |

## PERC CLI (perccli64) × Controller

| perccli64 Version | PERC H330/H730/H740 | PERC H745/H755 | PERC H965 (16G+) | PERC 12 (17G) |
|---|---|---|---|---|
| 7.1x | Yes | Yes | No | No |
| 7.2x | Yes | Yes | Yes | Partial |
| 8.x (if available) | Yes | Yes | Yes | Yes |

## Marvell CLI (mvcli) × Controller

| mvcli Version | S140 | S150 | BOSS-S1 |
|---|---|---|---|
| 4.x | Yes | Yes | Yes |
| 5.x | Yes | Yes | Yes |

## Ansible OpenManage × iDRAC

| OpenManage Version | Ansible Core | iDRAC9 | iDRAC10 | Key Changes |
|---|---|---|---|---|
| 7.x | 2.13+ | Yes | No | WSMAN-based modules |
| 8.x | 2.14+ | Yes | No | Added Redfish modules, some WSMAN deprecated |
| 9.x | 2.14-2.17 | Yes | Partial | Redfish-first, expanded module coverage |
| 10.x (if available) | 2.16+ | Yes | Yes | Full iDRAC10 support expected |

## Required Ports

| Port | Protocol | Service | Required For |
|---|---|---|---|
| 443 | TCP | HTTPS | racadm remote, Redfish API, web UI |
| 623 | UDP | IPMI | ipmitool remote, fallback management |
| 22 | TCP | SSH | racadm over SSH (if enabled) |
| 5900 | TCP | VNC | Virtual console |

## Minimum Feature Requirements

| Feature | Minimum iDRAC Version | Notes |
|---|---|---|
| Redfish API | iDRAC9 2.00.00.00+ | Basic Redfish support |
| Redfish Telemetry | iDRAC9 4.00.00.00+ | Streaming telemetry |
| HTML5 Virtual Console | iDRAC9 3.00.00.00+ | Replaces Java plugin |
| SCP JSON Format | iDRAC9 3.00.00.00+ | XML always supported |
| Lifecycle Controller REST | iDRAC9 2.00.00.00+ | LC job management via Redfish |
| Group Manager | iDRAC9 3.30.30.30+ | Multi-server discovery |
