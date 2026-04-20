# talos_bootstrap

Ansible role to bootstrap a Talos Kubernetes cluster from inventory variables.

## Capabilities

- **Pre-flight validation** — asserts `talosctl`, `kubectl`, `flux` CLI tools
- **Node IP discovery** — computes node IPs from `global_talos_cluster` inventory vars
- **Config generation** — `talosctl gen secrets` + `gen config` with stack-specific patches
- **Machine config apply** — applies configs to control plane and worker nodes (idempotent)
- **Cluster bootstrap** — bootstraps the cluster via first control plane node
- **Kubernetes verification** — verifies nodes, system pods, core workloads
- **FluxCD verification** — verifies controllers, git sources, kustomizations
- **SOPS encryption** — optionally encrypts secrets bundle

## Bootstrap Modes

| Mode          | Behavior                                                         |
| ------------- | ---------------------------------------------------------------- |
| `bootstrap`   | Full flow: secrets → config → apply → bootstrap → verify         |
| `upgrade`     | Re-apply machine configs + health check (cluster already exists) |
| `verify-only` | Skip to K8s + FluxCD verification only                           |

## Target Stack (via config patches)

- **Cilium** — CNI (replaces default Flannel, disables kube-proxy)
- **kube-vip** — control plane VIP for HA API endpoint
- **MetalLB** — L2 LoadBalancer for services
- **Longhorn** — distributed storage
- **cert-manager** — TLS certificate management
- **Prometheus/Grafana** — monitoring (kubelet serving certs)
- **Traefik** — ingress (deployed via FluxCD, no Talos patch needed)

## Variables

All variables are derived from `global_talos_cluster` inventory vars.
See `defaults/main.yml` for the full list with defaults.

## Usage

```yaml
- hosts: localhost
  roles:
    - role: talos_bootstrap
      tags: [talos, bootstrap]
```

## Single-Node Cluster

Set in your config source:

```yaml
talos:
  controlplane_count: 1
  worker_count: 0
  allow_scheduling_on_controlplane: true
```
