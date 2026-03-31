# Ansible OpenManage — Fleet Management

The `dellemc.openmanage` Ansible collection provides modules for managing Dell servers at scale. Use Ansible when operating on multiple servers or automating repeatable operations.

## When to Use Ansible vs racadm

| Scenario | Tool |
|---|---|
| Single server, one-off command | racadm |
| Multiple servers, same operation | Ansible |
| Config-as-code (export/import SCP) | Either — Ansible for fleet, racadm for single |
| Automated/scheduled operations | Ansible |
| Interactive troubleshooting | racadm |

## Inventory Setup

Create an inventory file for your server fleet:

```yaml
# workspace/playbooks/inventory.yaml
all:
  hosts:
    server01:
      idrac_ip: 192.168.1.10
    server02:
      idrac_ip: 192.168.1.11
    server03:
      idrac_ip: 192.168.1.12
  vars:
    idrac_user: root
    idrac_password: "{{ vault_idrac_password }}"
    validate_certs: false
```

### Credential Management with Ansible Vault

```bash
# Create a vault file for passwords
ansible-vault create workspace/playbooks/vault.yaml
# Enter: vault_idrac_password: your-password-here

# Run playbooks with vault
ansible-playbook -i workspace/playbooks/inventory.yaml workspace/playbooks/playbook.yaml --ask-vault-pass
```

## Key Modules

### Export SCP (Fleet-Wide)

```yaml
# workspace/playbooks/export-scp.yaml
---
- name: Export Server Configuration Profile
  hosts: all
  gather_facts: false
  tasks:
    - name: Export SCP to local file
      dellemc.openmanage.idrac_server_config_profile:
        idrac_ip: "{{ idrac_ip }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: "{{ validate_certs }}"
        share_name: /workspace/configs
        scp_file: "{{ inventory_hostname }}-scp.xml"
        export_format: XML
        export_use: Default
        job_wait: true
```

### Get System Inventory

```yaml
# workspace/playbooks/get-inventory.yaml
---
- name: Collect system inventory
  hosts: all
  gather_facts: false
  tasks:
    - name: Get system inventory
      dellemc.openmanage.idrac_system_info:
        idrac_ip: "{{ idrac_ip }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: "{{ validate_certs }}"
      register: system_info

    - name: Save inventory to file
      ansible.builtin.copy:
        content: "{{ system_info | to_nice_json }}"
        dest: "/workspace/inventory/{{ inventory_hostname }}-info.json"
```

### Update Firmware (Fleet-Wide)

```yaml
# workspace/playbooks/update-firmware.yaml
---
- name: Update firmware via DUP
  hosts: all
  gather_facts: false
  serial: 1  # One server at a time (rolling update)
  tasks:
    - name: Update iDRAC firmware
      dellemc.openmanage.idrac_firmware:
        idrac_ip: "{{ idrac_ip }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: "{{ validate_certs }}"
        share_name: /workspace/firmware
        catalog_file_name: Catalog.xml
        reboot: true
        job_wait: true
        job_wait_timeout: 900
```

### Configure BIOS Settings

```yaml
# workspace/playbooks/set-bios.yaml
---
- name: Apply BIOS settings
  hosts: all
  gather_facts: false
  tasks:
    - name: Set virtualization BIOS profile
      dellemc.openmanage.idrac_bios:
        idrac_ip: "{{ idrac_ip }}"
        idrac_user: "{{ idrac_user }}"
        idrac_password: "{{ idrac_password }}"
        validate_certs: "{{ validate_certs }}"
        attributes:
          ProcVirtualization: Enabled
          ProcX2Apic: Enabled
          SriovGlobalEnable: Enabled
          SysProfile: PerfOptimized
        job_wait: true
```

## Running Playbooks

```bash
# Inside the dell-tools container
cd /workspace/playbooks

# Run against all servers
ansible-playbook -i inventory.yaml export-scp.yaml --ask-vault-pass

# Run against a specific server
ansible-playbook -i inventory.yaml export-scp.yaml --limit server01 --ask-vault-pass

# Dry run (check mode)
ansible-playbook -i inventory.yaml set-bios.yaml --check --ask-vault-pass
```

## OpenManage 8.x vs 9.x Differences

See `skills/reference/openmanage-migration.md` for a detailed migration guide.

Key changes:
- **9.x** adds Redfish-based alternatives for most WSMAN-dependent modules
- **9.x** deprecates several older modules — check the migration doc for replacements
- Module parameter names are mostly stable, but some have new optional parameters in 9.x
