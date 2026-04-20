# HomelabAsCode

Opinionated decleartive, fully indempotent Lab Environment.
Build with the objective of taking no shortcuts.

## Workflow Overview

### Architectural Decisions

1. Ansible is the single Source of Truth for deploying the Site
2. All Secrets are encrypted & managed by SOPS/Age
3. All Authentication is certificate/key based. A user with the correct Age Key does not need a password.
4. All Resources are managed by Terraform
5. Everything is indempotent and the Site can be deployed & updated with a single `make all` command.
6. Every Workload deployed is managed in git & deployed by CI/CD. The Default Configuration deploys & configures a local Gitlab Instance to manage

- Talos K8s Clusters
- Docker
- Nixos Flakes

### _Ansible_ Stage 0 - Bootstrap localhost

Quick goal: prepare the control node (localhost) so it can manage the full lab safely and repeatably.

- Creates/maintains local bootstrap state (directories, local users, baseline config)
- Installs and configures SSH user/cert prerequisites for key-based access
- Initializes SOPS/Age key material for encrypted secret workflows

Roles used:

- `bootstrap_localhost`
- `ssh_user`
- `sops_age`

### _Ansible_ Stage 1 - Bootstrap Proxmox

Quick goal: make Proxmox nodes cluster-ready, API-ready, and template-ready.

- Configures Proxmox repositories and host bootstrap settings
- Builds/validates Proxmox cluster state across `proxmox_nodes`
- Creates cluster-wide API users/tokens (Ansible + Terraform), then persists secrets via SOPS
- Ensures VM template(s) are present for later Terraform provisioning

Roles used:

- `proxmox_repos`
- `bootstrap_proxmox`
- `proxmox_cluster`
- `proxmox_template`
- `sops_write` (included during API token persistence)

### _Ansible_ Stage 2 - Generate Templates

Quick goal: render all inventory-driven artifacts needed before infra apply.

- Generates Terraform variable files from Ansible inventory
- Generates definitions/artifacts for NixOS, Talos, and GitOps repos (through inventory-driven rendering)
- Prepares the handoff into Terraform Stage 3

Roles used:

- `inventory_builder`

### _Terraform_ stage 3 - Create Ressources

(VM's and OPNSense Ressources)

### _Ansible_ Stage 4 - Bootstrap GitLab VM

Quick goal: bring up GitLab on NixOS first, then make it the source for downstream repo-driven deployments.

- Performs NixOS VM pre-bootstrap, then deploys GitLab host flake(s)
- Configures GitLab resources post-deploy (groups/projects/users/runners based on config)
- Establishes GitLab as central platform required by later stages

Roles used:

- `sops_age`
- `nixos_flake_deploy`
- `gitlab_configure`

### _Ansible_ Stage 5 - Bootstrap Talos Kubernetes + FluxCD

Quick goal: create or reconcile the Talos cluster and verify Kubernetes/GitOps readiness.

- Runs preflight checks for required tooling and cluster config inputs
- Generates/applies Talos machine configs and cluster secrets
- Bootstraps control plane/etcd in `bootstrap` mode, or reconciles in `upgrade` mode
- Verifies cluster health and FluxCD integration

Roles used:

- `talos_bootstrap`

### _Ansible_ Stage 6 - Deploy NixOS Service VMs

Quick goal: deploy and validate non-GitLab NixOS workloads (admin/docker/common service VMs).

- Bootstraps host connectivity for Ansible on fresh NixOS systems
- Applies host flakes and optional GitLab Runner configuration
- Verifies expected services (for example node-exporter, optional restic, optional runner)

Roles used:

- `nixos_flake_deploy`
- `gitlab_runner` (conditional)

### _Ansible_ Stage 7 - Post-Deployment Cleanup

Quick goal: finalize local housekeeping and print deployment summary.

- Runs localhost cleanup tasks after deployment
- Syncs/cleans local operational state (known_hosts/inventory housekeeping)
- Prints a compact deployment summary by host group

Roles used:

- `bootstrap_cleanup`

### Default Workflow

## Prerequisites

### Control node (where you run `make`)

- Linux host (NixOS recommended; container-based execution is supported)
- `git` and `make`
- `ansible-core` and `ansible-galaxy`
- `terraform`
- `sops`
- `age` (including `age-keygen`)
- `openssh`

For Talos/Kubernetes stages (Stage 5), also install:

- `talosctl`
- `kubectl`
- `flux` CLI
- `helm` (required when Talos CNI mode is `none`)

Install required Ansible collections:

```bash
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

### Infrastructure prerequisites

- Proxmox hypervisor/node(s) reachable from the control node
- OPNsense DHCP/DNS available for Terraform-managed reservations and records
- Network connectivity and DNS routing for all planned VMs hostnames/IPs

### Access prerequisites

- SOPS/Age key available for encrypted secrets (`secrets/sops/keys.txt` or `AGE_SECRET_KEY`)

## Quick Start

### 1) Clone and enter the repository

```bash
git clone <your-repo-url>
cd HomelabAsCode
```

### 2) Configure inventory and host variables

- Update `ansible/inventory/hosts.yml` for your environment.
- Review and adjust group variables in `ansible/inventory/group_vars/`.
- Add or update per-host files in `ansible/inventory/host_vars/`.

If `host_vars` is empty, initialize template files with:

```bash
make init
```

### 3) Configure secrets (SOPS/Age)

- Ensure your Age key is available in `secrets/sops/keys.txt` (or set `AGE_SECRET_KEY`).
- Edit `secrets/secrets.yaml` with your environment-specific values.
- Encrypt secrets with SOPS as needed.

### 4) Run full deployment

```bash
make all
```

This runs stages 0 through 7 in order.

### 5) Run stages manually (recommended for first bring-up)

```bash
make stage-0
make stage-1
make stage-2
make stage-3
make stage-4
make stage-5
make stage-6
make stage-7
```

### 6) Operational notes

- Stage 3 runs Terraform plan/apply for infrastructure creation.
- Stage 4 must be completed before stages 5 and 6 in the default workflow.
- Re-running the same stage is expected to be idempotent.

## AI Disclaimer

All Ansible and Terraform Files are written by me. AI Auto Completion was enabled and used (claude opus 4.6 & chatgpt 5.1).
AI was used for writing j2 Templates from existing config files (e.g. nixos flake templates, terraform templates, ansible host var templates ...)
All Changes by AI have been reviewd before merging and all Errors are my own.
AI was also used to write this README and other documentation.
