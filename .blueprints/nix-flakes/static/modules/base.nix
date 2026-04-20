{ config
, lib
, pkgs
, ...
}:

with lib;

{
  options.iac.base = {
    enable = mkEnableOption "base iac configuration" // {
      default = true;
    };

    timeZone = mkOption {
      type = types.str;
      default = "Europe/Berlin";
      description = "System timezone";
    };

    sshCaPublicKeyPath = mkOption {
      type = types.str;
      default = "/etc/ssh/ca/iac_ca.pub";
      description = "Path to the SSH Certificate Authority public key for TrustedUserCAKeys";
    };
  };

  config = mkIf config.iac.base.enable {
    # Timezone (mkDefault so per-host configuration.nix can override)
    time.timeZone = mkDefault config.iac.base.timeZone;

    # Locale settings
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_TIME = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
    };

    # Console settings
    console = {
      keyMap = "us";
      font = "Lat2-Terminus16";
    };

    # Essential system packages
    environment.systemPackages = with pkgs; [
      # System tools
      vim
      nano
      wget
      curl
      git
      htop
      tmux
      python3 # Required for Ansible module execution

      # Network tools
      tcpdump
      nmap
      dnsutils

      # Archive tools
      unzip
      gzip
      xz

      # File management
      tree
      rsync
      fd
      ripgrep

      # Security
      gnupg
      age
      sops
    ];

    # QEMU Guest Agent (Proxmox integration)
    services.qemuGuest.enable = true;

    # SSH configuration
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
      };

      # SSH Certificate Authority trust
      extraConfig = ''
        TrustedUserCAKeys ${config.iac.base.sshCaPublicKeyPath}
      '';
    };

    # Automatic garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };

    # Nix settings
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;

      # Substituters for faster builds
      substituters = [
        "https://cache.nixos.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # Enable systemd-resolved for DNS
    services.resolved = {
      enable = true;
      dnssec = "allow-downgrade";
      fallbackDns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
    };

    # NTP for time synchronization
    services.timesyncd = {
      enable = true;
      servers = [
        "0.nixos.pool.ntp.org"
        "1.nixos.pool.ntp.org"
        "2.nixos.pool.ntp.org"
        "3.nixos.pool.ntp.org"
      ];
    };

    # Journald configuration
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFileSize=50M
      MaxRetentionSec=7day
    '';

    # Security hardening
    security = {
      # Sudo configuration
      sudo = {
        enable = true;
        # Passwordless sudo for wheel group - required for Ansible automation
        # Password auth via cloud-init cipassword is not supported by NixOS cloud-init module
        wheelNeedsPassword = false;
        execWheelOnly = true;
      };

      # Audit system
      auditd.enable = true;
      audit = {
        enable = true;
        rules = [
          "-a exit,always -F arch=b64 -S execve"
        ];
      };
    };

    # Firewall
    networking.firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ]; # SSH
      # Additional ports added by other modules
    };

    # User configuration
    # Use mkDefault so profiles can override (e.g., for cloud-init)
    users.mutableUsers = lib.mkDefault false;

    # Create iac admin user
    users.users.iac = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "systemd-journal"
      ];
      openssh.authorizedKeys.keys = [
        # SSH keys will be added via SOPS or Ansible
      ];
      shell = pkgs.bash;
    };
  };
}
