# GitLab Repository Template Initialization

This document explains how the gitlab_configure role automatically bootstraps and initializes GitLab repositories from template folders.

## Overview

The `gitlab_configure` role includes functionality to automatically create GitLab repositories from template directories. This is useful for:

- Standardizing repository structure across projects
- Quick-starting new projects with boilerplate code
- Automating repository creation in CI/CD pipelines
- Maintaining consistent GitLab configurations

## How It Works

### 1. Template Discovery

The role scans the `templates/repos/` directory for subdirectories. Each subdirectory represents a repository template.

```
templates/repos/
├── nixos-flakes/       → Creates 'nixos-flakes' repository
├── terraform/          → Creates 'terraform' repository
└── ansible-playbooks/  → Creates 'ansible-playbooks' repository
```

### 2. Repository Creation

For each template directory found:

1. **Create GitLab Project**: Uses GitLab API to create a new project in the specified namespace
2. **Check Existing Content**: Skips initialization if repository already has commits
3. **Initialize Local Git**: Creates a local git repository with the template content
4. **Initial Commit**: Commits all template files
5. **Push to GitLab**: Pushes the content to the GitLab repository

### 3. Authentication

The role uses the GitLab API token specified in `gitlab_api_token` variable (typically from Ansible Vault).

## Configuration

### Required Variables

```yaml
# GitLab API token (from vault)
gitlab_api_token: '{{ vault_secrets.gitlab.api_token }}'

# GitLab external URL
gitlab_external_url: 'https://gitlab.{{ global_domain }}'
```

### Optional Variables

```yaml
# Enable/disable repository initialization (default: true)
gitlab_repo_init_enable: true

# Template directory (default: role_path/templates/repos)
gitlab_repo_templates_dir: '{{ role_path }}/templates/repos'

# Default namespace/group for repositories (default: iac)
gitlab_repo_default_namespace: 'iac'

# Repository visibility (default: private)
# Options: private, internal, public
gitlab_repo_default_visibility: 'private'

# Git commit author
gitlab_repo_git_user_name: 'Ansible Automation'
gitlab_repo_git_user_email: 'ansible@{{ global_domain }}'

# SSL verification for GitLab API (default: false)
gitlab_ssl_verify: false
```

## Creating Custom Templates

### Step 1: Create Template Directory

```bash
mkdir -p ansible/roles/gitlab_configure/templates/repos/my-project
```

### Step 2: Add Template Files

Add any files you want in the repository:

```bash
cd ansible/roles/gitlab_configure/templates/repos/my-project

# Create README
cat > README.md << 'EOF'
# My Project

This project was initialized from a template.
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Project-specific ignores
*.tmp
.cache/
EOF

# Add more files as needed
mkdir src
echo "// Main code" > src/main.js
```

### Step 3: Run the Playbook

```bash
cd ansible
ansible-playbook stage_4_gitlab.yml
```

The role will:

- Detect the new `my-project` template
- Create a GitLab repository at `https://gitlab.{{ global_domain }}/iac/my-project`
- Initialize it with your template files

## Using with Stage 6

For Stage 6 to work correctly with the GitLab flake repository initialization:

### 1. Ensure Template Exists

Make sure your NixOS flakes repository template exists:

```bash
ls -la ansible/roles/gitlab_configure/templates/repos/nixos-flakes/
```

### 2. Configure Host Variables

In your host_vars, reference the GitLab repository:

```yaml
# ansible/inventory/staging/host_vars/service-vm.yml
host_flakes:
  - name: 'iac-base'
    url: 'https://gitlab.{{ global_domain }}/iac/nixos-flakes.git'
    ref: 'main'
```

### 3. Run Stage 4 First

```bash
# Stage 4 creates and initializes the GitLab repositories
ansible-playbook stage_4_gitlab.yml
```

### 4. Run Stage 6

```bash
# Stage 6 deploys flakes from GitLab to target VMs
ansible-playbook stage_6.yml
```

## Included Templates

### nixos-flakes

Complete NixOS flake repository with:

- `flake.nix` with SOPS-nix integration
- Example host configurations
- Module and profile structure
- GitLab CI/CD pipeline for validation
- `.gitignore` for NixOS artifacts

**Best For**: NixOS infrastructure configurations

### terraform

Terraform repository template with:

- Proxmox provider configuration
- Variable structure
- Example tfvars file
- GitLab CI/CD for plan/apply workflow
- State management examples

**Best For**: Infrastructure-as-Code using Terraform

### ansible-playbooks

Ansible automation repository with:

- Standard directory structure (roles, playbooks, inventory)
- `ansible.cfg` configuration
- Collection requirements
- Example inventory files
- GitLab CI/CD for syntax checking and linting

**Best For**: Configuration management and automation

## Workflow Integration

### Full Bootstrap Workflow

1. **Stage 0**: Initialize localhost with SOPS/age keys
2. **Stage 1**: Bootstrap Proxmox cluster
3. **Stage 2**: Generate templates (tfvars, flakes, compose, k8s)
4. **Stage 3**: Apply Terraform (manual)
5. **Stage 4**: Deploy GitLab and **initialize repositories from templates** ← Repository init happens here
6. **Stage 5**: Deploy Talos K8s + FluxCD
7. **Stage 6**: Deploy NixOS VMs using flakes from GitLab repositories
8. **Stage 7**: Post-deployment cleanup

### Repository Lifecycle

```
Template Folder → GitLab API → New Repository → Initial Commit → Push → Ready for Use
     ↓                ↓              ↓              ↓            ↓
  Discovery      Create Project   Local Init   Add Files    Push to GitLab
```

## Advanced Usage

### Custom Namespace per Template

Override the namespace in your playbook:

```yaml
- name: Initialize repositories in different namespaces
  include_role:
    name: gitlab_configure
  vars:
    gitlab_repo_default_namespace: 'infrastructure'
```

### Selective Template Initialization

Use tags to control which templates are initialized:

```bash
# Only initialize repositories, skip other GitLab config
ansible-playbook stage_4_gitlab.yml --tags repos

# Skip repository initialization
ansible-playbook stage_4_gitlab.yml --skip-tags repos
```

### Custom Template Directory

Use templates from a different location:

```yaml
gitlab_repo_templates_dir: '/path/to/custom/templates'
```

## Troubleshooting

### Repository Already Exists

**Symptom**: API returns 400 status

**Cause**: Repository already exists in GitLab

**Solution**: The role handles this gracefully and skips re-creation. To reinitialize:

1. Delete the repository in GitLab UI
2. Re-run the playbook

### Authentication Failure

**Symptom**: API returns 401 status

**Cause**: Invalid or missing API token

**Solution**:

```bash
# Verify token in vault
ansible-vault view ansible/vars/ansible_managed_vault.json | grep -A5 gitlab

# Ensure token has API scope in GitLab
```

### Template Not Found

**Symptom**: No repositories created

**Cause**: Templates directory doesn't exist or is empty

**Solution**:

```bash
# Check for templates
ls -la ansible/roles/gitlab_configure/templates/repos/

# Verify role path
ansible-playbook stage_4_gitlab.yml -vv | grep gitlab_repo_templates_dir
```

### Push Failure

**Symptom**: Repository created but empty

**Cause**: Git authentication failure or network issue

**Solution**: The role uses token-based HTTPS authentication automatically. Check:

```bash
# Verify GitLab is accessible
curl -k https://gitlab.{{ global_domain }}/api/v4/version

# Check git configuration
git config --global --list
```

## Security Considerations

1. **API Tokens**: Store in Ansible Vault, never commit plaintext
2. **Repository Visibility**: Default is `private` - adjust per template if needed
3. **Secret Files**: Never include real secrets in templates - use placeholders
4. **SSL Verification**: Enable `gitlab_ssl_verify: true` in production with valid certs

## Performance

- **Parallel Processing**: Templates are processed sequentially to avoid race conditions
- **Skip Existing**: Already-initialized repositories are skipped automatically
- **Temporary Workspace**: Uses `/tmp` for git operations, cleaned up after completion

## Examples

### Example 1: Add a Docker Compose Template

```bash
# Create template directory
mkdir -p ansible/roles/gitlab_configure/templates/repos/docker-compose-services

# Add docker-compose.yml
cat > ansible/roles/gitlab_configure/templates/repos/docker-compose-services/docker-compose.yml << 'EOF'
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
EOF

# Run playbook
ansible-playbook stage_4_gitlab.yml --tags repos
```

### Example 2: Multiple Namespaces

```yaml
# In your playbook
- name: Initialize infrastructure repos
  include_role:
    name: gitlab_configure
    tasks_from: init_repos
  vars:
    gitlab_repo_default_namespace: 'infrastructure'
    gitlab_repo_templates_dir: '/path/to/infrastructure/templates'

- name: Initialize application repos
  include_role:
    name: gitlab_configure
    tasks_from: init_repos
  vars:
    gitlab_repo_default_namespace: 'applications'
    gitlab_repo_templates_dir: '/path/to/application/templates'
```

## References

- GitLab API Documentation: https://docs.gitlab.com/ee/api/
- Ansible URI Module: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html
- GitLab Projects API: https://docs.gitlab.com/ee/api/projects.html
