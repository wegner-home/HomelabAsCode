# Secrets Directory

This directory contains SOPS-encrypted secrets for the infrastructure.

## Setup

1. **Generate age key** (if not already done in Stage 0):

   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Get public key**:

   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

3. **Update `.sops.yaml`** with your age public key(s):

   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: age1your_public_key_here
   ```

4. **Encrypt secrets file**:
   ```bash
   cd /path/to/nix_flakes_repo
   sops --encrypt --in-place secrets/secrets.yaml
   ```

## Usage

### Edit Encrypted Secrets

```bash
sops secrets/secrets.yaml
```

### View Encrypted Secrets (without editing)

```bash
sops --decrypt secrets/secrets.yaml
```

### Add New Secret

```bash
sops secrets/secrets.yaml
# Add your key-value pair in the editor
# Save and exit - file will be re-encrypted
```

### Rotate Keys

```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/new-keys.txt

# Get new public key
age-keygen -y ~/.config/sops/age/new-keys.txt

# Update .sops.yaml with both old and new keys
# Re-encrypt all secrets with new keys
sops --rotate --in-place secrets/secrets.yaml

# After confirming decryption works with new key, remove old key from .sops.yaml
# and rotate again
```

## Secret Structure

The `secrets.yaml` file should contain all secrets needed:

- **Restic**: `restic-password`, `restic-env` (S3 credentials)
- **GitLab**: Database passwords, root password, secret keys
- **GitLab Runner**: Registration token
- **SSH**: Private keys, CA keys (if managed via SOPS)
- **APIs**: Proxmox, OPNsense tokens
- **Databases**: PostgreSQL, MySQL passwords
- **Monitoring**: Grafana, Prometheus credentials

## Integration with NixOS

Secrets are accessed in NixOS configurations via sops-nix:

```nix
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      restic-password = {
        owner = "root";
        mode = "0400";
      };
      gitlab-runner-token = {
        owner = "gitlab-runner";
        mode = "0400";
      };
    };
  };

  # Use secrets in configuration
  services.restic.backups.daily = {
    passwordFile = config.sops.secrets.restic-password.path;
  };
}
```

## Security Best Practices

1. **Never commit unencrypted secrets** to git
2. **Use separate age keys** per environment (dev/staging/production)
3. **Rotate secrets regularly** (quarterly minimum)
4. **Backup age keys** securely (encrypted external drive, password manager)
5. **Limit key distribution** - only give keys to systems that need them
6. **Use different secrets** for dev vs production
7. **Audit secret access** - check who has age keys

## Troubleshooting

### Error: "no age key found"

Make sure age key exists:

```bash
ls -l ~/.config/sops/age/keys.txt
# or on NixOS hosts:
ls -l /var/lib/sops-nix/key.txt
```

### Error: "failed to get data key"

Your age key doesn't match the keys in `.sops.yaml`. Verify:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
# Should match a key in .sops.yaml
```

### Secrets not decrypting on NixOS host

1. Ensure age key file exists on host: `/var/lib/sops-nix/key.txt`
2. Check file permissions: `chmod 600 /var/lib/sops-nix/key.txt`
3. Verify the key matches one in `.sops.yaml`
4. Check sops-nix configuration in host's `configuration.nix`

## References

- [SOPS Documentation](https://github.com/mozilla/sops)
- [age Encryption](https://github.com/FiloSottile/age)
- [sops-nix](https://github.com/Mic92/sops-nix)
