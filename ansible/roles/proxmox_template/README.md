# proxmox_template

Unified Ansible role for creating Proxmox VM templates from various image sources.

## Description

This role consolidates the functionality of `nixos_proxmox_template` and `ubuntu_proxmox_template` into a single, flexible role that supports:

- **URL source**: Download cloud images (Ubuntu, Debian, etc.) directly to Proxmox
- **File source**: Transfer local pre-built images (NixOS, custom images) to Proxmox
- **NixOS build**: Build NixOS images using nixos-generator on localhost

## Requirements

- Ansible 2.9+
- Proxmox VE 7.0+
- For NixOS builds: Nix installed on localhost
- SSH access to Proxmox nodes

## Role Variables

### Source Configuration

| Variable                        | Default      | Description                                   |
| ------------------------------- | ------------ | --------------------------------------------- |
| `proxmox_template_source_type`  | `url`        | Image source: `url`, `file`, or `nixos_build` |
| `proxmox_template_image_url`    | Ubuntu Noble | URL to cloud image (for `url` type)           |
| `proxmox_template_image_file`   | `""`         | Local path to image file (for `file` type)    |
| `proxmox_template_image_format` | `img`        | Image format (qcow2, raw, img, vma)           |

### Template VM Settings

| Variable                     | Default                  | Description                        |
| ---------------------------- | ------------------------ | ---------------------------------- |
| `proxmox_template_vm_id`     | `9000`                   | VM ID for the template             |
| `proxmox_template_name`      | `cloud-init-template`    | Template name                      |
| `proxmox_template_node`      | `{{ ansible_hostname }}` | Target Proxmox node                |
| `proxmox_template_cores`     | `2`                      | CPU cores                          |
| `proxmox_template_memory`    | `2048`                   | Memory in MB                       |
| `proxmox_template_disk_size` | `32`                     | Disk size in GB (0 to skip resize) |
| `proxmox_template_storage`   | `local-lvm`              | Storage for VM disk                |

### NixOS Build Options (when `source_type: nixos_build`)

| Variable                                | Default                        | Description            |
| --------------------------------------- | ------------------------------ | ---------------------- |
| `proxmox_template_nixos_version`        | `25.11`                        | NixOS version to build |
| `proxmox_template_nixos_build_dir`      | `/tmp/nixos-template-build`    | Build directory        |
| `proxmox_template_nixos_extra_packages` | `[curl, vim, git, htop, tmux]` | Additional packages    |

## Usage Examples

### Ubuntu Cloud Image (Default)

```yaml
- hosts: proxmox
  roles:
    - role: proxmox_template
      vars:
        proxmox_template_source_type: 'url'
        proxmox_template_image_url: 'https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
        proxmox_template_vm_id: 9000
        proxmox_template_name: 'ubuntu-noble-template'
```

### Debian Cloud Image

```yaml
- hosts: proxmox
  roles:
    - role: proxmox_template
      vars:
        proxmox_template_source_type: 'url'
        proxmox_template_image_url: 'https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2'
        proxmox_template_image_format: 'qcow2'
        proxmox_template_vm_id: 9001
        proxmox_template_name: 'debian-12-template'
```

### Local NixOS Image File

```yaml
- hosts: proxmox
  roles:
    - role: proxmox_template
      vars:
        proxmox_template_source_type: 'file'
        proxmox_template_image_file: '/path/to/nixos-image.qcow2'
        proxmox_template_image_format: 'qcow2'
        proxmox_template_vm_id: 9002
        proxmox_template_name: 'nixos-template'
```

### Build NixOS Image from Scratch

```yaml
- hosts: proxmox
  roles:
    - role: proxmox_template
      vars:
        proxmox_template_source_type: 'nixos_build'
        proxmox_template_nixos_version: '25.11'
        proxmox_template_vm_id: 9003
        proxmox_template_name: 'nixos-25.11-template'
        proxmox_template_nixos_extra_packages:
          - vim
          - git
          - htop
```

### Multiple Templates on Same Node

```yaml
- hosts: proxmox
  tasks:
    - name: Create Ubuntu template
      ansible.builtin.include_role:
        name: proxmox_template
      vars:
        proxmox_template_source_type: 'url'
        proxmox_template_image_url: 'https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img'
        proxmox_template_vm_id: 9000
        proxmox_template_name: 'ubuntu-noble-tpl'

    - name: Create Debian template
      ansible.builtin.include_role:
        name: proxmox_template
      vars:
        proxmox_template_source_type: 'url'
        proxmox_template_image_url: 'https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2'
        proxmox_template_vm_id: 9001
        proxmox_template_name: 'debian-12-tpl'
```

## Tags

| Tag        | Description                                       |
| ---------- | ------------------------------------------------- |
| `validate` | Validate configuration                            |
| `build`    | Build NixOS image (only for `nixos_build` source) |
| `download` | Download image from URL                           |
| `transfer` | Transfer local image to Proxmox                   |
| `snippets` | Deploy cloud-init snippets                        |
| `create`   | Create VM from image                              |
| `template` | Convert VM to template                            |
| `cleanup`  | Clean up temporary files                          |

## Workflow

1. **Validation**: Checks source configuration is valid
2. **Image Acquisition**: Downloads or transfers image to Proxmox node
3. **Snippets** (optional): Deploys cloud-init user-data snippet
4. **VM Creation**: Creates VM and imports disk
5. **Template Conversion**: Converts VM to template
6. **Cleanup**: Removes temporary files

## Migration from Previous Roles

### From `nixos_proxmox_template`

```yaml
# Old
- role: nixos_proxmox_template
  vars:
    nixos_template_vm_id: 9000
    nixos_template_version: '25.11'

# New
- role: proxmox_template
  vars:
    proxmox_template_source_type: 'nixos_build'
    proxmox_template_vm_id: 9000
    proxmox_template_nixos_version: '25.11'
```

### From `ubuntu_proxmox_template`

```yaml
# Old
- role: ubuntu_proxmox_template
  vars:
    ubuntu_cloud_init_template_nix_vm_id: 9999
    ubuntu_cloud_init_template_nix_cloud_img_url: 'https://...'

# New
- role: proxmox_template
  vars:
    proxmox_template_source_type: 'url'
    proxmox_template_vm_id: 9999
    proxmox_template_image_url: 'https://...'
```

## License

MIT

