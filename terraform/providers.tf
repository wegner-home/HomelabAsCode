terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    opnsense = {
      source = "browningluke/opnsense"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

data "sops_file" "provider_secrets" {
  count       = var.sops_secrets_file != null ? 1 : 0
  source_file = var.sops_secrets_file
}

data "sops_file" "runtime_secrets" {
  count       = var.sops_runtime_file != null ? 1 : 0
  source_file = var.sops_runtime_file
}

locals {
  _provider_secrets_raw = try(data.sops_file.provider_secrets[0].raw, null)
  _runtime_secrets_raw  = try(data.sops_file.runtime_secrets[0].raw, null)

  _provider_doc = try(yamldecode(local._provider_secrets_raw), {})
  _runtime_doc  = try(yamldecode(local._runtime_secrets_raw), {})

  _vault_secrets = try(local._provider_doc.vault_secrets, {})

  _runtime_proxmox = try(local._runtime_doc.proxmox, {})
  _vault_proxmox   = try(local._vault_secrets.proxmox, {})

  _use_runtime_proxmox_node = contains(keys(local._runtime_proxmox), var.proxmox_auth_node)

  _default_proxmox_node = (
    local._use_runtime_proxmox_node
    ? local._runtime_proxmox[var.proxmox_auth_node]
    : try(local._vault_proxmox[var.proxmox_auth_node], {})
  )

  _opnsense_secrets = try(local._vault_secrets.opnsense, {})

  _pm_api_token_id_from_sops = (
    local._use_runtime_proxmox_node
    ? try(local._default_proxmox_node.terraform_token_id, null)
    : try(local._default_proxmox_node.terraform_token_id[0], null)
  )

  _pm_api_secret_from_sops = (
    local._use_runtime_proxmox_node
    ? try(local._default_proxmox_node.terraform_token_secret, null)
    : try(local._default_proxmox_node.terraform_token_secret[0], null)
  )

  pm_api_token_id_resolved = (
    var.pm_api_token_id != null && trimspace(var.pm_api_token_id) != ""
    ? var.pm_api_token_id
    : local._pm_api_token_id_from_sops
  )

  pm_api_secret_resolved = (
    var.pm_api_secret != null && trimspace(var.pm_api_secret) != ""
    ? var.pm_api_secret
    : local._pm_api_secret_from_sops
  )

  opnsense_api_key_resolved = (
    var.opnsense_api_key != null && trimspace(var.opnsense_api_key) != ""
    ? var.opnsense_api_key
    : try(local._opnsense_secrets.api_key, null)
  )

  opnsense_api_secret_resolved = (
    var.opnsense_api_secret != null && trimspace(var.opnsense_api_secret) != ""
    ? var.opnsense_api_secret
    : try(local._opnsense_secrets.api_secret, null)
  )
}

provider "proxmox" {
  pm_api_url          = var.pm_api_uri
  pm_api_token_id     = local.pm_api_token_id_resolved
  pm_api_token_secret = local.pm_api_secret_resolved
  pm_tls_insecure     = true # allow self-signed certificates
}

provider "opnsense" {
  uri            = var.opnsense_uri
  api_key        = local.opnsense_api_key_resolved
  api_secret     = local.opnsense_api_secret_resolved
  allow_insecure = "true"
}
