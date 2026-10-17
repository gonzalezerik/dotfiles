{ config, pkgs, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  nixpkgs.config.allowUnfree = true;

  # ── Nix ──────────────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Weekly GC of anything older than 7 days; optimise hard-links identical
  # store files together.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };
  nix.optimise.automatic = true;
  # Set here (root config) so nix trusts them during nixos-rebuild.
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://noctalia.cachix.org"
    "https://nyx-cache.chaotic.cx"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
  ];

  # ── Locale ───────────────────────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS" "LC_IDENTIFICATION" "LC_MEASUREMENT" "LC_MONETARY" "LC_NAME"
    "LC_NUMERIC" "LC_PAPER" "LC_TELEPHONE" "LC_TIME"
  ] (_: "en_US.UTF-8");
  # Keyboard layout - works without an X server; niri reads it through
  # libxkbcommon.
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # ── Storage ──────────────────────────────────────────────────────────────
  # btrfs: transparent zstd:1 (nearly free, typically 30-50% smaller /nix
  # store) and noatime. Merged with the subvol options in
  # hardware-configuration.nix.
  fileSystems."/".options = [ "compress=zstd:1" "noatime" ];
  fileSystems."/home".options = [ "compress=zstd:1" "noatime" ];
  fileSystems."/nix".options = [ "compress=zstd:1" "noatime" ];
  services.btrfs.autoScrub = { enable = true; interval = "monthly"; fileSystems = [ "/" ]; };
  services.fstrim.enable = true;
  # I/O schedulers: "none" for NVMe, mq-deadline for SATA SSDs (bfq is for
  # spinning disks). Same rules CachyOS ships.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';

  # ── Memory ───────────────────────────────────────────────────────────────
  # zram swap with the standard swap-on-zram tuning (Fedora/Pop!_OS/CachyOS):
  # prefer compressing idle anonymous pages over dropping file cache, and no
  # readahead (page-cluster=0 - readahead only helps spinning disks).
  zramSwap.enable = true;
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  hardware.enableRedistributableFirmware = true;
  # Firmware/BIOS updates via LVFS (`fwupdmgr refresh && fwupdmgr update`).
  services.fwupd.enable = true;

  # ── Networking ───────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  # avahi: mDNS/DNS-SD so CUPS finds driverless network printers.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # Spotify local discovery / Connect.
  networking.firewall.allowedTCPPorts = [ 57621 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];

  # ── Hardware surfaces ────────────────────────────────────────────────────
  hardware.graphics.enable = true;
  # Bluetooth - the Control Center talks to BlueZ directly.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  # i2c: ddcutil controls external display brightness over DDC/CI.
  hardware.i2c.enable = true;

  # ── System services ──────────────────────────────────────────────────────
  # UPower (battery, lid) and power-profiles-daemon: Noctalia's widgets use
  # both over D-Bus.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.gnome.gnome-keyring.enable = true;
  # GVfs: trash, MTP, etc. for Nautilus and GTK file dialogs.
  services.gvfs.enable = true;
  security.polkit.enable = true;

  services.printing = {
    enable = true;
    # gutenprint: broad driver coverage as a fallback for printers that
    # aren't fully driverless-IPP capable.
    drivers = [ pkgs.gutenprint ];
    # cups-browsed would auto-create a duplicate temp queue for every
    # driverless printer avahi sees; the permanent queues are added once with
    # lpadmin.
    browsed.enable = false;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ── User ─────────────────────────────────────────────────────────────────
  users.users.erikg = {
    isNormalUser = true;
    description = "Erik Gonzalez";
    extraGroups = [ "networkmanager" "wheel" "render" "video" "i2c" "gamemode" ];
  };

  programs.bash.interactiveShellInit = ''
    export PATH="$HOME/.local/bin:$PATH"
  '';

  # dconf: gsettings (GTK dark mode, icon theme, cursor size).
  programs.dconf.enable = true;

  # nix-ld: lets non-NixOS binaries find system libs.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ curl stdenv.cc.cc ];

  # Electron/Chromium apps (Slack, Feishin, Spotify, ...) as native Wayland
  # clients through nixpkgs' wrappers.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Zoom: the module adds pipewire-pulse support; screen sharing needs
  # xdg-desktop-portal(-gnome) inside its FHS sandbox, which matches
  # xdg.portal.config.niri routing Screencast to -gnome. Native Wayland also
  # needs xwayland=false in ~/.config/zoomus.conf (mutable, Zoom rewrites it).
  programs.zoom-us = {
    enable = true;
    package = pkgs.zoom-us.override { gnomeXdgDesktopPortalSupport = true; };
  };

  environment.systemPackages = with pkgs; [
    # KiCad with its libraries and 3D models (also gives the KiCad skills
    # kicad-cli).
    kicad
    claude-code

    # Hardware / monitoring
    (if cfg.gpu == "nvidia" then nvtopPackages.nvidia else nvtopPackages.amd)
    lm_sensors
    pciutils
    usbutils
    vulkan-tools
    mesa-demos
    btop
    htop

    # CLI
    wireguard-tools
    git
    curl
    wget
    pulseaudio # pactl
    alsa-utils
    python3
    nodejs
  ];

  system.stateVersion = "26.05";
}
