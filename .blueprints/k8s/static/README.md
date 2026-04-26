# Kubernetes GitOps Repository

This repository contains the FluxCD configuration for the Kubernetes cluster.

## Structure

```
├── apps/                    # Application deployments
│   └── base/               # Base app definitions (shared across envs)
├── infrastructure/          # Infrastructure components
│   ├── controllers/        # HelmReleases for infra (Cilium, MetalLB, etc.)
│   └── configs/            # Post-install configs (IP pools, ingress, etc.)
├── clusters/               # Per-environment cluster definitions
│   └── <env>/              # Environment-specific (dev, staging, production)
│       ├── flux-system/    # FluxCD bootstrap
│       └── infrastructure.yaml
└── .sops.yaml              # SOPS encryption configuration
```

## Environments

Clusters are organized by environment matching the `NIX_ENV` variable:

- `dev` - Development/testing
- `staging` - Pre-production
- `production` - Production workloads

## Infrastructure Components

| Component    | Purpose                    |
| ------------ | -------------------------- |
| Cilium       | CNI networking with eBPF   |
| MetalLB      | Bare-metal load balancer   |
| Traefik      | Ingress controller         |
| cert-manager | TLS certificate automation |
| SOPS         | Secret encryption with age |

## Usage

FluxCD automatically reconciles this repository. Manual sync:

```bash
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-controllers
```

## Secrets

Secrets are encrypted with SOPS using age keys. To encrypt:

```bash
sops --encrypt --in-place secret.yaml
```

To decrypt (requires age private key):

```bash
sops --decrypt secret.yaml
```
