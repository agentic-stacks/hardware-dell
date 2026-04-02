# Foundation Skills: Dell PowerEdge Hardware Management

## Purpose

Establish baseline knowledge for managing Dell PowerEdge servers programmatically. Complete this phase before attempting firmware updates, RAID configuration, or fleet-wide automation.

## Sub-Skills

| Sub-Skill | Path | What It Covers |
|---|---|---|
| Concepts | `concepts/` | PowerEdge generations, iDRAC architecture, firmware hierarchy, licensing, Redfish API |
| Tools | `tools/` | racadm, ipmitool, perccli64, Ansible OpenManage, local discovery utilities |
| Architecture | `architecture/` | Container-based tooling, privileged vs remote modes, compose profiles, security |

## Routing

Use this decision tree to determine which sub-skill to consult:

1. **Need to understand what a component is or how Dell systems are organized?** Read `concepts/README.md`.
2. **Need to choose a CLI tool or understand command syntax?** Read `tools/README.md`.
3. **Need to set up the containerized environment or understand runtime configuration?** Read `architecture/README.md`.

## Prerequisites

- Familiarity with Linux system administration
- Docker and docker-compose installed on the management host
- Network access to target iDRAC interfaces (port 443 for HTTPS/Redfish, port 623 for IPMI)
- iDRAC credentials for target servers

## Completion Criteria

After completing the foundation phase, the agent should be able to:

- Identify a PowerEdge server model and generation from its name
- Explain the role of iDRAC and its relationship to the BMC
- Select the correct CLI tool for a given management task
- Launch the Dell tools container in the appropriate mode (privileged or remote)
- Authenticate to an iDRAC and retrieve basic system inventory via racadm or Redfish
