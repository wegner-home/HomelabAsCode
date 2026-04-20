{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.iac.ci-runner;
in
{
  options.iac.ci-runner = {
    enable = mkEnableOption "GitLab Runner for CI/CD";

    gitlabUrl = mkOption {
      type = types.str;
      default = "https://git.lan.wegner.cool";
      description = "GitLab instance URL";
    };

    registrationTokenFile = mkOption {
      type = types.path;
      default = config.sops.secrets.gitlab-runner-token.path or "/run/secrets/gitlab-runner-token";
      description = "Path to file containing GitLab Runner registration token";
    };

    executor = mkOption {
      type = types.enum [
        "docker"
        "shell"
        "docker+machine"
        "kubernetes"
      ];
      default = "shell";
      description = "GitLab Runner executor type. Shell is the default — jobs run directly on the host. Use 'docker' for container isolation (requires explicit dockerVolumes config).";
    };

    concurrent = mkOption {
      type = types.int;
      default = 2;
      description = "Maximum number of concurrent jobs";
    };

    cloneUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Overwrite the URL for the GitLab instance. Useful if the Runner sits behind a proxy";
    };

    tlsCaFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the certificates to verify the peer when using HTTPS";
    };

    tlsVerify = mkOption {
      type = types.bool;
      default = true;
      description = "Enable validation of TLS certificates";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [
        "nixos"
      ];
      description = "Runner tags for job routing";
    };

    dockerImage = mkOption {
      type = types.str;
      default = "docker:latest";
      description = "Default Docker image for jobs (when executor is docker)";
    };

    dockerPrivileged = mkOption {
      type = types.bool;
      default = false;
      description = "Run Docker containers in privileged mode";
    };

    dockerVolumes = mkOption {
      type = types.listOf types.str;
      default = [
        "/cache"
        "/nix:/nix:ro"
      ];
      description = lib.mdDoc ''
        Docker volumes to mount in CI job containers.

        The default only includes `/cache` and a read-only Nix store mount.
        For runners that need to deploy Docker Compose stacks to the host,
        add `/var/run/docker.sock:/var/run/docker.sock` and the compose
        project directory. This grants the CI container full control of
        the host Docker daemon — only enable on dedicated deploy runners.

        Example for a Docker deploy runner:
        ```nix
        dockerVolumes = [
          "/cache"
          "/nix:/nix:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/opt/docker-compose:/opt/docker-compose"
        ];
        ```
      '';
    };

    cachePath = mkOption {
      type = types.str;
      default = "/var/lib/gitlab-runner/cache";
      description = "Path for runner cache";
    };
  };

  config = mkIf cfg.enable {
    # Trust the GitLab self-signed CA cert system-wide so that
    # gitlab-runner verify, register, and run all work without TLS errors.
    security.pki.certificateFiles = mkIf (cfg.tlsCaFile != null) [ cfg.tlsCaFile ];

    # Enable Docker if using docker executor
    virtualisation.docker = mkIf (cfg.executor == "docker" || cfg.executor == "docker+machine") {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # GitLab Runner service
    services.gitlab-runner = {
      enable = true;

      # Runner settings
      settings = {
        concurrent = cfg.concurrent;
        check_interval = 10;

        # Session server for interactive debugging
        session_server = {
          listen_address = "[::]:8093";
          advertise_address = "${config.networking.hostName}:8093";
        };
      };

      # Runner configuration
      services = {
        "${config.networking.hostName}" = {
          registrationConfigFile = cfg.registrationTokenFile;

          # Executor-specific settings
          executor = cfg.executor;
          cloneUrl = cfg.cloneUrl;

          # TLS: No --tls-ca-file needed here. When tlsCaFile is set,
          # security.pki.certificateFiles bakes the cert into the system CA
          # bundle, which gitlab-runner (Go) trusts automatically.

          # Docker executor configuration
          dockerImage = mkIf (cfg.executor == "docker" || cfg.executor == "docker+machine") cfg.dockerImage;
          dockerPrivileged = mkIf
            (
              cfg.executor == "docker" || cfg.executor == "docker+machine"
            )
            cfg.dockerPrivileged;
          dockerVolumes = mkIf
            (
              cfg.executor == "docker" || cfg.executor == "docker+machine"
            )
            cfg.dockerVolumes;

          # Shell executor configuration
          buildsDir = mkIf (cfg.executor == "shell") "/var/lib/gitlab-runner/builds";

          # Cache configuration
          environmentVariables = {
            CACHE_PATH = cfg.cachePath;
          }
          // (lib.optionalAttrs (!cfg.tlsVerify) {
            "CI_SERVER_TLS_SKIP_VERIFY" = "true";
            "GIT_SSL_NO_VERIFY" = "true";
          });

          # Tags and other server-side settings are configured via Ansible (gitlab_runner)
          # when creating the authentication token. They must NOT be passed to register command.

          # tagList = cfg.tags; (Managed by GitLab)
          # description = "..."; (Managed by GitLab)
          # runUntagged = false; (Managed by GitLab)
        };
      };
    };

    # Create cache directory
    systemd.tmpfiles.rules = [
      "d ${cfg.cachePath} 0750 gitlab-runner iac -"
    ];

    # GitLab runner user — uses the shared iac group (from ansible group_vars: global_group)
    users.users.gitlab-runner = {
      isSystemUser = true;
      group = "iac";
      extraGroups = mkIf (cfg.executor == "docker" || cfg.executor == "docker+machine") [ "docker" ];
    };
    users.groups.iac = { };

    # Firewall (for session server)
    networking.firewall.allowedTCPPorts = [ 8093 ];

    # Helper scripts
    environment.systemPackages = with pkgs; [
      gitlab-runner

      (writeScriptBin "gitlab-runner-status" ''
        #!${bash}/bin/bash
        set -euo pipefail

        echo "GitLab Runner Status"
        echo "===================="
        echo ""

        # Service status
        echo "Service Status:"
        systemctl status gitlab-runner.service --no-pager || true
        echo ""

        # Verify registration
        echo "Registration Check:"
        gitlab-runner verify 2>&1 || echo "Runner not yet registered or verification failed"
        echo ""

        # Show runner info
        echo "Runner Configuration:"
        echo "  URL: ${cfg.gitlabUrl}"
        echo "  Executor: ${cfg.executor}"
        echo "  Concurrent Jobs: ${toString cfg.concurrent}"
        echo "  Tags: ${concatStringsSep ", " cfg.tags}"
        echo "  Docker Image: ${cfg.dockerImage}"
        echo ""

        # Recent jobs
        echo "Recent Activity:"
        journalctl -u gitlab-runner.service -n 10 --no-pager | grep -E "job|runner" || echo "No recent activity"
      '')

      (writeScriptBin "gitlab-runner-register" ''
        #!${bash}/bin/bash
        set -euo pipefail

        echo "GitLab Runner Registration"
        echo "=========================="
        echo ""
        echo "This will register the runner with GitLab."
        echo "Make sure you have the registration token ready."
        echo ""

        if [ ! -f "${cfg.registrationTokenFile}" ]; then
          echo "Error: Registration token file not found: ${cfg.registrationTokenFile}"
          echo "Please create this file with the GitLab registration token."
          exit 1
        fi

        TOKEN=$(cat "${cfg.registrationTokenFile}")

        ${optionalString (!cfg.tlsVerify) ''
          export CI_SERVER_TLS_SKIP_VERIFY=true
          export GIT_SSL_NO_VERIFY=true
        ''}

        gitlab-runner register \
          --non-interactive \
          --url "${cfg.gitlabUrl}" \
          --registration-token "$TOKEN" \
          --executor "${cfg.executor}" \
          --docker-image "${cfg.dockerImage}" \
          --docker-privileged="${if cfg.dockerPrivileged then "true" else "false"}" \
          --docker-volumes "${concatStringsSep "," cfg.dockerVolumes}"
          # --tag-list "${concatStringsSep "," cfg.tags}" \
          # --description "${config.networking.hostName} - NixOS Runner" \
          # --run-untagged="false" \
          # --locked="false" \
          # --access-level="not_protected"

        echo ""
        echo "Registration complete! Verify with: gitlab-runner verify"
      '')

      (writeScriptBin "gitlab-runner-logs" ''
        #!${bash}/bin/bash
        journalctl -u gitlab-runner.service -f
      '')
    ];

    # Documentation
    environment.etc."motd.d/30-gitlab-runner".text = ''

      GitLab Runner Configuration:
        URL: ${cfg.gitlabUrl}
        Executor: ${cfg.executor}
        Tags: ${concatStringsSep ", " cfg.tags}

      Commands:
        gitlab-runner-status    - Show runner status
        gitlab-runner verify    - Verify registration
        gitlab-runner-logs      - Follow runner logs

      Logs:
        journalctl -u gitlab-runner.service
    '';

    # System service configuration
    systemd.services.gitlab-runner.serviceConfig = {
      # Restart on failure
      Restart = "always";
      RestartSec = "10s";

      # Resource limits
      LimitNOFILE = 65536;
      LimitNPROC = 4096;
    };
  };
}
