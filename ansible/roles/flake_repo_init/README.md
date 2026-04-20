# flake_repo_init Role

Initializes the NixOS flake repository with git, SOPS/age encryption, and validation.

## Purpose

This role provides automated setup of the NixOS flake repository, replacing the manual `init.sh` script for consistency with Ansible-managed infrastructure.

## What It Does

1. **Prerequisites Check**: Validates git, nix, age, and sops are installed
2. **Git Initialization**: Initializes git repo, creates initial commit
3. **SOPS Setup**: Generates age encryption keys, updates `.sops.yaml`
4. **Flake Validation**: Checks flake configuration validity
5. **Guidance**: Provides next steps for deployment

## Usage

### Standalone Playbook

```bash
cd ansible
ansible-playbook bootstrap_nix_flake_repo.yml
```

### Integrated with Stage 0

The role can be included in `stage_0.yml` for complete localhost bootstrap:

```yaml
- name: Initialize NixOS flake repository
  ansible.builtin.include_role:
    name: flake_repo_init
  tags: ['flake', 'init']
```

### With Custom Parameters

```bash
ansible-playbook bootstrap_nix_flake_repo.yml \
  -e "nix_flake_repo_github_url=git@github.com:username/iac-nix-configs.git"
```

## Variables

### Required Variables (with defaults)

```yaml
# Path to flake repository
nix_flake_repo_path: '{{ global_iac_root }}/files/nix_flakes'

# Age key configuration
nix_flake_repo_age_key_dir: '{{ ansible_env.HOME }}/.config/sops/age'
nix_flake_repo_age_key_file: '{{ nix_flake_repo_age_key_dir }}/keys.txt'

# Git settings
nix_flake_repo_git_init: true
nix_flake_repo_git_commit_message: 'Initial commit: NixOS configurations'

# Validation
nix_flake_repo_validate: true
```

### Optional Variables

```yaml
# GitHub repository URL (optional)
nix_flake_repo_github_url: 'git@github.com:username/iac-nix-configs.git'

# Create GitHub repo via gh CLI (optional)
nix_flake_repo_github_create: false
```

## Requirements

- `git` command available
- `nix` with flakes enabled
- `age` for encryption (optional but recommended)
- `sops` for secrets management (optional but recommended)

## Example Playbook

```yaml
---
- name: Bootstrap NixOS Flake Repository
  hosts: localhost
  connection: local
  gather_facts: true

  vars:
    nix_flake_repo_github_url: 'git@github.com:myuser/iac-nix-configs.git'

  roles:
    - role: flake_repo_init
      tags: ['flake']
```

## Tags

- `prerequisites` - Run only prerequisites check
- `git` - Run only git initialization
- `sops` - Run only SOPS/age setup
- `secrets` - Alias for sops
- `validate` - Run only flake validation

## Post-Role Actions

After running this role, you should:

1. **Edit secrets**:

   ```bash
   sops files/nix_flakes/secrets/secrets.yaml
   ```

2. **Push to GitHub**:

   ```bash
   cd files/nix_flakes
   git push -u origin main
   ```

3. **Update Ansible inventory** with flake URL

4. **Deploy via Stage 6**:
   ```bash
   ansible-playbook stage_6.yml
   ```

## Integration with Other Roles

This role works alongside:

- `bootstrap_localhost` - Localhost setup
- `sops_age` - If age keys need to be distributed to VMs
- `nixos_flake_deploy` - Deploys configurations from this repo

## Directory Structure

```
files/nix_flakes/
├── .git/                   # Initialized by this role
├── .sops.yaml             # Updated with age public key
├── flake.nix
├── hosts/
├── modules/
├── profiles/
└── secrets/
    └── secrets.yaml       # Ready for sops editing
```

## Troubleshooting

### Age key generation fails

**Solution**: Install age:

```bash
nix-env -iA nixpkgs.age
```

### Flake validation fails

**Solution**: Check detailed errors:

```bash
cd files/nix_flakes
nix flake check --show-trace
```

### .sops.yaml not updated

**Solution**: Check if placeholders exist:

```bash
grep "age1abc" files/nix_flakes/.sops.yaml
```

If not found, manually update `.sops.yaml` with your age public key.
