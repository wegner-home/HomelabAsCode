{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Server-specific configuration
  # Applied to headless server VMs

  # No GUI
  services.xserver.enable = false;

  # Disable unnecessary services
  services = {
    # No graphical display manager
    displayManager.enable = false;

    # No audio
    pipewire.enable = false;
    pulseaudio.enable = false;
  };

  # Console only
  boot.plymouth.enable = false;

  # Server packages
  environment.systemPackages = with pkgs; [
    # Additional server tools
    iotop
    iftop
    ncdu

    # Monitoring
    htop

    # Network diagnostics
    mtr
    iperf3
  ];

  # Disable smartd for VMs (no SMART-capable virtual disks)
  # Enable only on bare-metal hosts
  services.smartd.enable = lib.mkDefault false;

  # CPU frequency scaling (for power efficiency)
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
  };

  # Automatic timezone detection disabled (set explicitly)
  services.automatic-timezoned.enable = false;

  # Disable unnecessary documentation
  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    info.enable = false;
  };

  # Minimal MOTD additions for servers
  environment.etc."motd.d/00-server".text = ''
    Server Profile: Headless server configuration
    Performance: CPU governor set to 'ondemand'
  '';

  # Security hardening
  security = {
    # apparmor.enable = true;

    # Audit
    auditd.enable = true;
    audit.enable = true;

    # PAM limits
    pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "nofile";
        value = "65536";
      }
      {
        domain = "*";
        type = "hard";
        item = "nofile";
        value = "65536";
      }
    ];
  };

  # Network optimization for servers
  boot.kernel.sysctl = {
    # TCP tuning
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";

    # Connection tracking
    "net.netfilter.nf_conntrack_max" = 262144;

    # More aggressive connection timeouts
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 3;
  };

  # Systemd optimizations
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "30s";
    DefaultTimeoutStopSec = "30s";
  };

  # Automatic cleanup of temporary files
  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root 1d"
    "d /var/tmp 1777 root root 7d"
  ];
}
