{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.iac.backup;
in
{
  options.iac.backup = {
    enable = mkEnableOption "Restic backup service";

    repository = mkOption {
      type = types.str;
      example = "s3:s3.amazonaws.com/iac-backups";
      description = "Restic repository URL";
    };

    passwordFile = mkOption {
      type = types.path;
      default = config.sops.secrets.restic-password.path or "/run/secrets/restic-password";
      description = "Path to file containing Restic repository password";
    };

    schedule = mkOption {
      type = types.str;
      default = "daily";
      example = "02:00";
      description = "When to run backup (systemd timer format)";
    };

    paths = mkOption {
      type = types.listOf types.str;
      default = [
        "/etc/nixos"
        "/var/lib"
        "/root/.config"
      ];
      description = "Paths to backup";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "*.log"
        "*.tmp"
        "cache/"
        "tmp/"
        ".cache/"
        "*.sock"
      ];
      description = "Patterns to exclude from backup";
    };

    retention = {
      keepLast = mkOption {
        type = types.int;
        default = 3;
        description = "Number of most recent backups to keep";
      };

      keepDaily = mkOption {
        type = types.int;
        default = 7;
        description = "Number of daily backups to keep";
      };

      keepWeekly = mkOption {
        type = types.int;
        default = 4;
        description = "Number of weekly backups to keep";
      };

      keepMonthly = mkOption {
        type = types.int;
        default = 6;
        description = "Number of monthly backups to keep";
      };

      keepYearly = mkOption {
        type = types.int;
        default = 2;
        description = "Number of yearly backups to keep";
      };
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = config.sops.secrets.restic-env.path or null;
      description = "Environment file for S3 credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)";
    };

    preBackupScript = mkOption {
      type = types.lines;
      default = "";
      description = "Script to run before backup";
    };

    postBackupScript = mkOption {
      type = types.lines;
      default = "";
      description = "Script to run after successful backup";
    };
  };

  config = mkIf cfg.enable {
    # Restic backup service
    services.restic.backups.daily = {
      repository = cfg.repository;
      passwordFile = cfg.passwordFile;

      paths = cfg.paths;

      exclude = cfg.exclude;

      # Prune old backups
      pruneOpts = [
        "--keep-last ${toString cfg.retention.keepLast}"
        "--keep-daily ${toString cfg.retention.keepDaily}"
        "--keep-weekly ${toString cfg.retention.keepWeekly}"
        "--keep-monthly ${toString cfg.retention.keepMonthly}"
        "--keep-yearly ${toString cfg.retention.keepYearly}"
      ];

      # Timing
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };

      # Environment file for S3 credentials
      environmentFile = cfg.environmentFile;

      # Backup scripts
      backupPrepareCommand = mkIf (cfg.preBackupScript != "") cfg.preBackupScript;
      backupCleanupCommand = mkIf (cfg.postBackupScript != "") cfg.postBackupScript;

      # Initialize repository if it doesn't exist
      initialize = true;
    };

    # Additional packages
    environment.systemPackages = with pkgs; [
      restic

      # Backup helper scripts
      (writeScriptBin "restic-backup-now" ''
        #!${bash}/bin/bash
        set -euo pipefail

        echo "Starting manual Restic backup..."
        systemctl start restic-backups-daily.service

        echo ""
        echo "Following logs (Ctrl-C to stop):"
        journalctl -u restic-backups-daily.service -f
      '')

      (writeScriptBin "restic-backup-status" ''
        #!${bash}/bin/bash
        set -euo pipefail

        echo "Restic Backup Status"
        echo "===================="
        echo ""

        # Timer status
        echo "Timer Status:"
        systemctl status restic-backups-daily.timer --no-pager
        echo ""

        # Last backup
        echo "Last Backup:"
        journalctl -u restic-backups-daily.service -n 20 --no-pager | grep -E "snapshot|files|bytes|error" || echo "No recent backup found"
        echo ""

        # Next scheduled backup
        echo "Next Scheduled Backup:"
        systemctl list-timers restic-backups-daily.timer --no-pager
      '')

      (writeScriptBin "restic-snapshots" ''
        #!${bash}/bin/bash
        set -euo pipefail

        export RESTIC_REPOSITORY="${cfg.repository}"
        export RESTIC_PASSWORD_FILE="${cfg.passwordFile}"
        ${optionalString (cfg.environmentFile != null) "source ${cfg.environmentFile}"}

        restic snapshots "$@"
      '')

      (writeScriptBin "restic-restore" ''
        #!${bash}/bin/bash
        set -euo pipefail

        if [ $# -lt 1 ]; then
          echo "Usage: restic-restore <snapshot-id> [target-dir]"
          echo ""
          echo "Available snapshots:"
          restic-snapshots
          exit 1
        fi

        SNAPSHOT="$1"
        TARGET="''${2:-/tmp/restic-restore}"

        export RESTIC_REPOSITORY="${cfg.repository}"
        export RESTIC_PASSWORD_FILE="${cfg.passwordFile}"
        ${optionalString (cfg.environmentFile != null) "source ${cfg.environmentFile}"}

        echo "Restoring snapshot $SNAPSHOT to $TARGET..."
        mkdir -p "$TARGET"
        restic restore "$SNAPSHOT" --target "$TARGET"

        echo "Restore complete: $TARGET"
      '')
    ];

    # Documentation
    environment.etc."motd.d/20-backup".text = ''

      Restic Backup Configuration:
        Repository: ${cfg.repository}
        Schedule: ${cfg.schedule}

      Commands:
        restic-backup-status    - Show backup status
        restic-backup-now       - Run backup immediately
        restic-snapshots        - List backup snapshots
        restic-restore <id>     - Restore from snapshot

      Logs:
        journalctl -u restic-backups-daily.service
    '';

    # System service hardening
    systemd.services.restic-backups-daily.serviceConfig = {
      # Security
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false; # Need to read home directories
      ReadWritePaths = cfg.paths;

      # Nice and IO priority (background task)
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
}
