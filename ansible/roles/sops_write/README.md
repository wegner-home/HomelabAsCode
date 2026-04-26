# sops_write

Persists runtime-generated secrets to a SOPS/age-encrypted YAML file.

## Purpose

When Ansible roles generate secrets at runtime (API tokens, passwords, etc.),
those secrets need to survive across playbook runs. This role provides the
**write path** — it reads an existing SOPS file, merges in new secrets, and
re-encrypts the result with age.

On subsequent runs, persisted secrets are loaded via direct
`community.sops.sops` lookups into the `vault_secrets` variable.

## Requirements

- `community.sops` collection (>= 1.6.0)
- Age private key on the Ansible controller (default:
  `/var/local/{{ project_name }}/sops/age/keys.txt`)
- `.sops.yaml` at the repo root with matching `creation_rules`

## Role Variables

| Variable                    | Default                               | Description                              |
| --------------------------- | ------------------------------------- | ---------------------------------------- |
| `sops_write_file`           | `{{ global_sops_runtime_file }}`      | Path to the SOPS file to write           |
| `sops_write_age_keyfile`    | `{{ sops_age_keyfile }}`              | Path to age private key on controller    |
| `sops_write_age_recipients` | `['{{ global_sops_admin_age_key }}']` | Age public key(s) to encrypt for         |
| `sops_write_force`          | `false`                               | Force re-encrypt even if content matches |

All defaults chain to inventory variables set in
`inventory/<env>/group_vars/all/secrets.yml` and `system.yml`.

## Required Input

The caller must set `new_secrets` as a **fact** (not a role var) before
including this role:

```yaml
- name: Set secrets to persist
  ansible.builtin.set_fact:
    new_secrets:
      my_service:
        api_token: '{{ generated_token }}'
        created_at: '{{ ansible_date_time.iso8601 }}'
```

`new_secrets` must be a non-empty dict. The role will fail with an assertion
error if it's undefined, not a mapping, or empty.

## Usage

```yaml
# 1. Generate your secret
- name: Create API token
  ansible.builtin.uri:
    url: 'https://api.example.com/tokens'
    method: POST
  register: token_result

# 2. Build new_secrets dict
- name: Set secrets to persist
  ansible.builtin.set_fact:
    new_secrets:
      example:
        api_token: '{{ token_result.json.token }}'

# 3. Call the role
- name: Persist secrets to SOPS
  ansible.builtin.include_role:
    name: sops_write
  when: new_secrets is defined and new_secrets | length > 0
```

## How It Works

```
1. Assert    — validate new_secrets is defined + age keyfile exists
2. Read      — load existing SOPS file (or empty dict if file is new)
3. Merge     — combine(existing, new_secrets, recursive=True)
4. Encrypt   — community.sops.sops_encrypt with age recipients
5. Cleanup   — null internal merge variables from fact cache
```

### Merge Strategy

Uses `combine(recursive=True)` — existing keys are preserved, new keys are
added. Nested dicts are merged recursively. To force-overwrite the entire file,
set `sops_write_force: true`.

### Idempotency

`community.sops.sops_encrypt` with `force: false` (default) only re-encrypts
when the decrypted content has actually changed. If `new_secrets` contains the
same values already in the file, no write occurs.

### Security

- All tasks that handle decrypted data use `no_log: true`
- Internal variables (`_sops_write_existing`, `_sops_write_merged`) are nulled
  after the write to prevent secrets from lingering in Ansible's fact cache
- `expressions: ignore` on `load_vars` prevents accidental Jinja2 evaluation
  of stored secret values that might contain `{{ }}`

## Dependencies

None. This role is listed as a dependency in:

- `bootstrap_proxmox`
- `gitlab_configure`
- `gitlab_api_bootstrap`

## License

MIT
