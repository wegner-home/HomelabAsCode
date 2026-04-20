# ssh_ca Role

## Overview

SSH Certificate Authority role for NixOS. Sets up and manages an SSH CA for certificate-based authentication across all hosts.

## Features

- Generate SSH CA key pair (ed25519)
- Create user certificate signing script
- Create host certificate signing script
- Automatic backup on key regeneration

## Requirements

- NixOS target system (or any Linux with openssh)
- Root access for CA key storage
- SSH access to target host

## Role Variables

### Enable/Disable

```yaml
# Enable SSH CA on this host (typically only admin/jumphost)
host_ssh_ca_enable: true
```

### CA Configuration

```yaml
# Directory to store CA keys and scripts
ssh_ca_dir: '/var/lib/{{ project_name }}/ssh_ca'

# CA key settings
ssh_ca_key_name: '{{ project_name }}_ca'
ssh_ca_key_type: 'ed25519'

# Certificate validity periods
ssh_ca_user_cert_validity: '+52w' # 1 year
ssh_ca_host_cert_validity: '+104w' # 2 years
```

## Usage

### In Playbook

```yaml
- name: Setup SSH CA on admin host
  hosts: admin
  roles:
    - role: ssh_ca
      vars:
        host_ssh_ca_enable: true
```

### In host_vars

```yaml
# inventory/staging/host_vars/admin.yml
host_ssh_ca_enable: true
```

### Signing Certificates

After the role runs, use the generated scripts:

```bash
# Sign a user certificate
/var/lib/{{ project_name }}/ssh_ca/sign-user-cert.sh ~/.ssh/id_ed25519.pub username

# Sign a host certificate
/var/lib/{{ project_name }}/ssh_ca/sign-host-cert.sh /etc/ssh/ssh_host_ed25519_key.pub hostname
```

## Outputs

After running the role:

- `{{ ssh_ca_dir }}/{{ ssh_ca_key_name }}` - CA private key
- `{{ ssh_ca_dir }}/{{ ssh_ca_key_name }}.pub` - CA public key
- `{{ ssh_ca_dir }}/sign-user-cert.sh` - User certificate signing script
- `{{ ssh_ca_dir }}/sign-host-cert.sh` - Host certificate signing script
- `{{ ssh_ca_dir }}/CA_README.txt` - Usage documentation

## Integration

### Client Hosts

Add to `/etc/ssh/sshd_config`:

```
TrustedUserCAKeys /etc/ssh/ca-keys/{{ project_name }}_ca.pub
```

### User Machines

Add to `~/.ssh/known_hosts`:

```
@cert-authority *.{{ global_domain }} <CA_PUBLIC_KEY>
```

## See Also

- `bootstrap_ssh_cert` - For signing host certificates during VM provisioning
- `nixos_flake_deploy` - For NixOS flake deployment (separate concern)
