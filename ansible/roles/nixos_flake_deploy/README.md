# nixos_flake_deploy Role

## Overview

Unified NixOS flake deployment role supporting **multiple flakes per host**. This role provides a standardized way to deploy flake-based NixOS systems across all {{ project_name }} VMs with optional SSH CA and SOPS/age secrets management.

## Features

- **Multi-flake deployment** - Deploy multiple flakes to a single host
- Deploy from remote flake repository (Git) or local templates
- Idempotent operations with generation tracking
- Supports host-specific flake outputs
- Template-based configuration generation

> **Note:** SSH CA and SOPS/age secrets management are now handled by separate roles:
>
> - `ssh_ca` - SSH Certificate Authority setup
> - `sops_age` - SOPS/age secrets management

## Requirements

- NixOS target system
- `nix` command available with flakes enabled
- Git access if deploying from remote repository
- SSH access to target host

## Role Variables

### Host Flakes Configuration

```yaml
# List of flakes to deploy (can be strings or dicts)
host_flakes:
  - 'admin' # Simple string format
  - 'docker'
  - name: 'gitlab' # Dict format with options
    repo: 'github:user/gitlab-flake'
  - name: 'monitoring'
    deploy_from_repo: false
```

### Required Variables

```yaml
# Flake repository URL (for remote deployment)
nixos_flake_repo: 'github:user/{{ project_name }}-nix'
# OR set globally:
global_nixos_flake_repo: 'github:user/{{ project_name }}-nix'

# Flake host output name (single-flake mode only)
nixos_flake_host: '{{ inventory_hostname }}'
```

### Optional Variables

```yaml
# Deploy from remote repo (true) or local templates (false)
nixos_flake_deploy_from_repo: true

# Local deployment directory (when using templates)
nixos_flake_deploy_dir: '/etc/nixos'

# Force rebuild even if no config changes detected
nixos_flake_force_rebuild: false

# Additional nixos-rebuild arguments
nixos_flake_rebuild_args: '--show-trace'

# Enable SSH CA (typically only on admin/jumphost)
host_ssh_ca_enable: true

# Enable SOPS/age secrets
host_sops_enable: true

# Host role for configuration
host_role: 'admin' # admin, gitlab, docker, app, generic

# Additional packages
host_packages: [ansible, terraform, kubectl]

# Additional firewall ports
host_firewall_tcp_ports: [80, 443]

# Enable services
host_enable_docker: true
host_enable_tailscale: false
host_enable_node_exporter: true
```

## Usage Examples

### Multi-Flake Deployment

```yaml
# inventory/staging/host_vars/myhost.yml
host_flakes:
  - 'base'
  - 'docker'
  - 'monitoring'

host_role: 'docker'
host_enable_docker: true
```

```yaml
# playbook.yml
- name: Deploy NixOS VM
  hosts: myhost
  roles:
    - nixos_flake_deploy
```

### Admin/Jumphost

```yaml
# inventory/staging/host_vars/admin.yml
host_flakes: ['admin']
host_role: 'admin'
host_packages:
  - ansible
  - terraform
  - kubectl
  - age
  - sops
# Enable SSH CA and SOPS in playbook using separate roles:
# - ssh_ca (with host_ssh_ca_enable: true)
# - sops_age (with host_sops_enable: true)
```

### GitLab Server

```yaml
# inventory/staging/host_vars/gitlab.yml
host_flakes:
  - name: 'gitlab'
    repo: 'github:myuser/gitlab-nixos-flake'

host_role: 'gitlab'
host_firewall_tcp_ports: [80, 443, 22]
host_enable_docker: true
```

### Docker Host

```yaml
# inventory/staging/host_vars/docker01.yml
host_flakes: ['docker-host']
host_role: 'docker'
host_enable_docker: true
host_packages:
  - lazydocker
  - ctop
```

### Legacy Single-Flake Mode

For backwards compatibility, if `host_flakes` is empty, the role uses single-flake mode:

```yaml
nixos_flake_repo: 'github:myuser/{{ project_name }}-nix'
nixos_flake_host: 'myhost'
```

## Tags

- `preflight` - Pre-deployment validation
- `flake` - Flake deployment operations
- `deployment` - All deployment tasks
- `validation` - Post-deployment validation

## Related Roles

| Role                 | Purpose                                                   |
| -------------------- | --------------------------------------------------------- |
| `ssh_ca`             | SSH Certificate Authority setup (CA key, signing scripts) |
| `sops_age`           | SOPS/age secrets management (key generation, config)      |
| `bootstrap_ssh_cert` | Sign host certificates during VM provisioning             |

## Migration from bootstrap_nix_vm

If migrating from the old `bootstrap_nix_vm` role:

1. Replace role reference: `bootstrap_nix_vm` → `nixos_flake_deploy`
2. Rename variable: `host_flake_host` → use `host_flakes` list
3. Other variables remain compatible (`host_role`, `host_packages`, etc.)

## Files Structure

```
nixos_flake_deploy/
├── defaults/main.yml      # All configurable variables
├── tasks/
│   ├── main.yml           # Main entry point
│   ├── preflight.yml      # Pre-deployment checks
│   ├── deploy_flake.yml   # Per-flake deployment logic
│   ├── deploy_remote.yml  # Remote flake deployment
│   ├── deploy_local.yml   # Local template deployment
│   └── validate.yml       # Post-deployment validation
├── templates/
│   ├── flake.nix.j2
│   └── configuration.nix.j2
└── handlers/main.yml
```
