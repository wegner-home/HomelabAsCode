# HomelabAsCode

Opinionated decleartive, fully indempotent Lab Environment.
Build with the objective of taking no shortcuts.

- All Configs are managed by Ansible & NixOS Flakes.
- All Ressources are managed by Terraform.
- All Secrets are managed by SOPS/Age

Everything should be deployable by a single `make all`.

## Prerequesites

- NixOS locaholst (or docker container)
  - Terraform
  - Ansible
  - SOPS
  - Age
  - openssh
- Proxmox Hypervisor
- OPNSense DHCP/DNS

## Features

WIP

## Steps

- _Ansible_ stage 0 - prepare localhost
- _Ansible_ stage 1 - prepare proxmox & generate needed API Keys (e.g. OPNSense)
- _Ansible_ stage 2 - render all Templates (Terraform vars and needed Repos like NixOS Flakes, k8s, docker)
- _Terraform_ stage 3 - Create Ressources (VM's and OPNSense Ressources)
- _Ansible_ stage 4 - prepare local Gitlab Instance on NixOS
- _Ansible_ stage 5 - prepare k8s cluster + FluxCD
- _Ansible_ stage 6 - deploy NixOS Flakes for generic hosts like docker or admin hosts
- _Ansible_ stage 7 - cleanup

## Quick Start

WIP (clone, adjust ansible group & host vars, make all)
