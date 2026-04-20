{ config, lib, pkgs, ... }:

{
  # Minimal profile for low-resource VMs
  # Only essential services and packages

  # Minimal system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
  ];

  # Disable unnecessary services
  services = {
    # No audio
    pipewire.enable = false;
    pulseaudio.enable = false;

    # No GUI
    xserver.enable = false;

    # No printing
    printing.enable = false;

    # Minimal systemd services
    udisks2.enable = false;
  };

  # Minimal boot
  boot.plymouth.enable = false;

  # Disable documentation
  documentation = {
    enable = false;
    doc.enable = false;
    man.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  # Reduced journald retention
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    SystemMaxFileSize=10M
    MaxRetentionSec=3day
  '';

  # Aggressive garbage collection
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  # Minimal MOTD
  environment.etc."motd".text = ''
    ${config.networking.hostName} - Minimal NixOS Profile

    Type 'help' for available commands
  '';

  # Performance tuning for low resources
  boot.kernel.sysctl = {
    "vm.swappiness" = 60; # More aggressive swapping for low memory
    "vm.vfs_cache_pressure" = 50;
  };
}
