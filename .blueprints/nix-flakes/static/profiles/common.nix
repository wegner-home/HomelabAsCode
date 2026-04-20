{ config
, lib
, pkgs
, ...
}:

{
  imports = [
    ../modules/base.nix
  ];

  # Common configuration applied to ALL hosts
  # Enable base module
  iac.base.enable = true;
  iac.base.timeZone = "Europe/Berlin";

  # System state version (DON'T CHANGE without reading release notes)
  # mkDefault so per-host configuration.nix can override
  system.stateVersion = lib.mkDefault "25.11";

  # Root filesystem - use disk label for reliability
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  # Bootloader (GRUB for BIOS/UEFI compatibility)
  boot.loader = {
    grub = {
      enable = true;
      device = lib.mkDefault "/dev/vda"; # VirtIO disk; override per-host if using scsi (/dev/sda)
      efiSupport = false;
    };
  };

  # Enable partition growing on first boot
  boot.growPartition = true;

  # Networking
  networking = {
    # Use systemd-networkd
    useNetworkd = true;
    useDHCP = lib.mkDefault true; # Allow DHCP by default

    # Domain (default; overridden per-host by generated configuration.nix)
    domain = lib.mkDefault "example.lan";

    # Firewall enabled in modules/base.nix
  };

  # Disable wait-online entirely — on cloud-init VMs the network is
  # already configured before NixOS activation runs.  The service has
  # nothing useful to wait for and its timeout (even with anyInterface)
  # causes switch-to-configuration to return rc=4.
  systemd.network.wait-online.enable = false;

  # Ansible/automation user - required for deployment
  users.users.ansible = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!"; # No password, SSH key only
  };

  # Allow mutableUsers so cloud-init can add SSH keys
  users.mutableUsers = true;

  # SSH host keys (managed via cloud-init or manually)
  services.openssh.hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # Locale/Console: set in modules/base.nix

  # Documentation
  documentation = {
    enable = true;
    doc.enable = false;
    info.enable = false;
    nixos.enable = true;
  };

  # Allow unfree packages (for proprietary software if needed)
  nixpkgs.config.allowUnfree = true;

  # Common environment variables
  environment.variables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };

  # Shell aliases
  environment.shellAliases = {
    ll = "ls -lah";
    la = "ls -A";
    l = "ls -CF";
    ".." = "cd ..";
    "..." = "cd ../..";

    # NixOS helpers
    rebuild = "nixos-rebuild switch --flake /etc/nixos";
    rebuild-test = "nixos-rebuild test --flake /etc/nixos";
    rebuild-boot = "nixos-rebuild boot --flake /etc/nixos";

    # Systemd helpers
    start = "systemctl start";
    stop = "systemctl stop";
    restart = "systemctl restart";
    status = "systemctl status";
    enable = "systemctl enable";
    disable = "systemctl disable";

    # Journal helpers
    jctl = "journalctl";
    jctlf = "journalctl -f";
    jctlu = "journalctl -u";
  };

  # Message of the Day
  environment.etc."motd".text = ''
    ╔════════════════════════════════════════════════════╗
    ║  NixOS Infrastructure             ║
    ╚════════════════════════════════════════════════════╝

    Hostname: ${config.networking.hostName}.${config.networking.domain}
    NixOS: ${config.system.nixos.version}
    Kernel: ${pkgs.linux.version}

    Configuration: /etc/nixos
    Rebuild: nixos-rebuild switch --flake /etc/nixos

  '';

  # Automatic system maintenance
  system.autoUpgrade = {
    enable = false; # Controlled manually via Ansible
  };

  # Swap file — safety net for Nix evaluation memory spikes during nixos-rebuild
  swapDevices = lib.mkDefault [
    {
      device = "/var/swapfile";
      size = 2048; # 2GB swap
    }
  ];

  # Nix settings (base flakes/gc/store settings in modules/base.nix)
  nix.settings = {
    # Build settings — limit parallelism to reduce RAM pressure on small VMs
    cores = 1; # Single core per build job to limit peak RAM usage
    max-jobs = 1; # Only one build at a time to avoid OOM on 4GB VMs

    # Trusted users
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  # Security (sudo settings in modules/base.nix)
  security = {
    # Polkit (for non-root system management)
    polkit.enable = true;
  };

  # Systemd configuration
  systemd = {
    # Service defaults
    services = {
      # Keep tty1 enabled for Proxmox VNC console recovery access
      # Disable auto-spawning on additional TTYs to save resources
      "autovt@".enable = false;
    };

    # Journald
    settings.Manager = {
      DefaultTimeoutStopSec = "30s";
    };
  };

  # Performance tuning
  boot.kernel.sysctl = {
    # Networking
    "net.ipv4.tcp_fin_timeout" = lib.mkDefault 30;
    "net.ipv4.tcp_keepalive_time" = lib.mkDefault 1200; # Server profile overrides to 600
    "net.core.somaxconn" = lib.mkDefault 1024;

    # Virtual memory
    "vm.swappiness" = lib.mkDefault 10;

    # File system
    "fs.file-max" = lib.mkDefault 100000;
  };
}
