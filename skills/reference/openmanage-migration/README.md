# OpenManage Ansible Collection: 8.x to 9.x Migration

## Overview

The `dellemc.openmanage` collection 9.x introduces Redfish-first modules and deprecates several WSMAN-dependent modules. This guide covers what changes when upgrading from 8.x to 9.x.

## Module Changes

### Deprecated in 9.x (Use Alternatives)

| Deprecated Module | Replacement | Notes |
|---|---|---|
| `dellemc.openmanage.ome_device_info` | `dellemc.openmanage.ome_devices_info` | Pluralized name, expanded output |
| `dellemc.openmanage.idrac_firmware_info` | `dellemc.openmanage.idrac_firmware` with `state: present` | Consolidated into single module |

### New in 9.x

| Module | Purpose |
|---|---|
| `dellemc.openmanage.idrac_session` | Manage iDRAC sessions (Redfish-based) |
| `dellemc.openmanage.idrac_diagnostics` | Run remote diagnostics |
| `dellemc.openmanage.idrac_license` | Manage iDRAC licenses via Redfish |

### Parameter Changes

Some modules have new optional parameters in 9.x:

```yaml
# 8.x — basic SCP export
dellemc.openmanage.idrac_server_config_profile:
  idrac_ip: "{{ idrac_ip }}"
  share_name: /workspace/configs
  scp_file: server.xml
  export_format: XML

# 9.x — same, but with new optional params
dellemc.openmanage.idrac_server_config_profile:
  idrac_ip: "{{ idrac_ip }}"
  share_name: /workspace/configs
  scp_file: server.xml
  export_format: XML
  export_use: Default        # New in 9.x: Default, Clone, Replace
  include_in_export: default # New in 9.x: default, readonly, passwordhashvalues
```

## Python Dependencies

9.x may require additional Python packages. After upgrading the collection:

```bash
pip install -r ~/.ansible/collections/ansible_collections/dellemc/openmanage/requirements.txt
```

## Upgrade Path

```bash
# Inside the container
ansible-galaxy collection install dellemc.openmanage --upgrade

# Or pin a specific version
ansible-galaxy collection install dellemc.openmanage:==9.9.0

# Verify installed version
ansible-galaxy collection list | grep openmanage
```

## Testing After Upgrade

Run existing playbooks with `--check` mode first:

```bash
ansible-playbook -i inventory.yaml playbook.yaml --check --diff
```

This shows what would change without making modifications.
