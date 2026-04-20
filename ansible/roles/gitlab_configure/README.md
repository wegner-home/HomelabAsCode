# GitLab NixOS Role

Ansible role to deploy and configure GitLab CE/EE on NixOS with container registry, runners, and API bootstrap.

## Features

- **GitLab CE/EE**: Full GitLab installation on NixOS
- **Container Registry**: Docker container registry integration
- **GitLab Runners**: Automated CI/CD runner configuration
- **API Bootstrap**: Automated creation of groups, projects, and users via GitLab API
- **Repository Template Initialization**: Automatically create and initialize GitLab repositories from template folders
- **SSL/TLS Support**: Self-signed or custom certificates
- **Backup Management**: Automated backup scheduling with retention
- **SOPS/Age Integration**: Secure secret management
- **Monitoring**: Prometheus exporters for observability

## Requirements

- Target system running NixOS with flakes enabled
- Minimum 4GB RAM and 20GB disk space
- SSH access to target host
- Ansible 2.10+

## Role Variables

See [defaults/main.yml](defaults/main.yml) for all available variables.

### Key Variables

```yaml
# GitLab configuration
gitlab_external_url: 'https://gitlab.{{ global_domain }}'
gitlab_edition: 'ce'
gitlab_root_password: 'changeme123!'

# Container registry
gitlab_enable_registry: true
gitlab_registry_port: 5050

# GitLab Runner
gitlab_runner_enable: true
gitlab_runner_count: 2

# API bootstrap
gitlab_api_bootstrap_enable: true
gitlab_groups:
  - name: 'iac'
    path: 'iac'
    visibility: 'private'

# Repository template initialization
gitlab_repo_init_enable: true
gitlab_repo_templates_dir: '{{ role_path }}/templates/repos'
gitlab_repo_default_namespace: 'iac'
gitlab_repo_default_visibility: 'private'
```

## Dependencies

None

## Example Playbook

```yaml
- name: Deploy GitLab Server
  hosts: gitlab_vms
  roles:
    - gitlab_configure
  vars:
    gitlab_root_password: '{{ vault_secrets.gitlab.root_password }}'
```

## Post-Deployment

1. Access GitLab at configured external URL
2. Login with root user and configured password
3. Create personal access token for API operations
4. Register GitLab Runners if not automated

### Repository Template Initialization

The role automatically creates and initializes GitLab repositories from templates located in `templates/repos/`. Each subdirectory in this folder becomes a separate GitLab repository.

#### How It Works

1. **Template Discovery**: The role scans `templates/repos/` for subdirectories
2. **Repository Creation**: Creates a GitLab project for each template folder
3. **Content Initialization**: Copies template files and creates initial commit
4. **Push to GitLab**: Pushes the initialized content to the repository

#### Adding Custom Repository Templates

1. Create a new directory under `templates/repos/`:

   ```bash
   mkdir -p roles/gitlab_configure/templates/repos/my-new-repo
   ```

2. Add your template files:

   ```bash
   cd roles/gitlab_configure/templates/repos/my-new-repo
   touch README.md .gitignore
   ```

3. Run the playbook - the repository will be automatically created and initialized

#### Included Templates

- **nixos-flakes**: NixOS flake configuration repository with SOPS integration
- **terraform**: Terraform infrastructure-as-code with Proxmox provider
- **ansible-playbooks**: Ansible automation playbooks with CI/CD

#### Configuration Variables

```yaml
# Enable/disable repository initialization
gitlab_repo_init_enable: true

# Directory containing repository templates
gitlab_repo_templates_dir: '{{ role_path }}/templates/repos'

# Default GitLab namespace for repositories
gitlab_repo_default_namespace: 'iac'

# Default visibility (private, internal, public)
gitlab_repo_default_visibility: 'private'

# Git user for initial commits
gitlab_repo_git_user_name: 'Ansible Automation'
gitlab_repo_git_user_email: 'ansible@{{ global_domain }}'
```

#### Skipping Repository Initialization

To disable automatic repository initialization:

```yaml
gitlab_repo_init_enable: false
```

Or use tags to skip:

```bash
ansible-playbook stage_4_gitlab.yml --skip-tags repos
```

### Manual Runner Registration

```bash
gitlab-runner register \
  --url https://gitlab.{{ global_domain }} \
  --registration-token <TOKEN> \
  --executor docker \
  --docker-image alpine:latest \
  --tag-list docker,iac,nix
```

## License

MIT

