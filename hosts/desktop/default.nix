{ config, pkgs, site, ... }:
# desktop: ASRock B650I Lightning WiFi, Ryzen 7 7800X3D, RTX 5070 Ti, LG
# UltraGear+ 5K2K (5120x2160@165, HDR, VRR) on HDMI-A-1.
{
  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
  ];

  networking.hostName = "desktop";

  dotfiles = {
    theme = import ./theme.nix;
    gpu = "nvidia";
    display = {
      output = "HDMI-A-1";
      mode = "5120x2160@165.058";
      width = 5120;
      height = 2160;
      refresh = 165;
      scale = "1.25";
      vrr = true;
    };
    # gen_heightmap.py 5120 2160 38.4 (7.5 m/px = 9.375 m per logical px)
    wallpaper = {
      heightmap = ./assets/yosemite-heightmap.png;
      demMin = "558.8428";
      demRange = "2952.3113";
    };
    assets = {
      refindBanner = ./assets/refind-banner.png;
      greeterWallpaper = ./assets/greeter-wallpaper.png;
    };
    # nixpkgs' kernel, so the recovery entry's NVIDIA module comes from the
    # binary cache.
    recoveryKernel = pkgs.linuxPackages_latest;
    xwaylandSatellite = "add2795";
    streaming.allowFrom = site.hosts.px13;
  };

  home-manager.users.erikg.imports = [ ./home.nix ];

  # HorizonHaptics: DualSense adaptive triggers for Forza Horizon 6 (Steam
  # launch option `horizonhaptics-launch %command%`).
  users.users.erikg.packages = [ (pkgs.callPackage ../../pkgs/horizonhaptics.nix { }) ];

  # Motherboard Super I/O sensors (Nuvoton NCT6686D) for lm_sensors/LACT.
  boot.kernelModules = [ "nct6683" ];

  # NVIDIA in the initrd (early KMS): the splash draws on the real GPU from
  # the start and hands straight over to the greeter.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # ── GPU (RTX 5070 Ti, Blackwell: open kernel modules only) ───────────────
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    # Saves VRAM to disk across suspend so the session survives resume.
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ]; # VA-API on NVDEC
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };
  # niri on NVIDIA: the driver's GL buffer pool grows without bound in Wayland
  # compositors (multi-GB VRAM). Upstream niri wiki fix.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = builtins.toJSON {
    rules = [ { pattern = { feature = "procname"; matches = "niri"; }; profile = "Limit Free Buffer Pool On Wayland Compositors"; } ];
    profiles = [ { name = "Limit Free Buffer Pool On Wayland Compositors"; settings = [ { key = "GLVidHeapReuseRatio"; value = 0; } ]; } ];
  };
  # LACT: GPU monitoring, fan curves, power limit.
  services.lact.enable = true;

  # SATA SSD: storage + second Steam library. ext4, not btrfs: game data is
  # already compressed and Steam patches large files in place, which CoW
  # turns into slow, fragmented rewrites. nofail: never blocks boot.
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "ext4";
    options = [ "noatime" "nofail" "x-systemd.device-timeout=10s" ];
  };
  systemd.tmpfiles.rules = [
    "d /mnt/storage 0755 erikg users -"
    "d /mnt/storage/SteamLibrary 0755 erikg users -"
  ];

  # /dev/uhid for the seat user: the Galactic Racer DualSense proxy
  # (~/Projects/swgr-haptics) creates a virtual DualSense Edge. Must sort
  # before 73-seat-late.rules for uaccess to apply.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "swgr-uhid-udev-rules";
      destination = "/etc/udev/rules.d/70-swgr-uhid.rules";
      text = ''
        KERNEL=="uhid", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uhid"
      '';
    })
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.erikg.openssh.authorizedKeys.keys = site.authorizedKeys;

  # Inbound multiplayer (Call of Duty 3074, Steam 4380 + 27015-27030), only
  # towards the gaming VLAN, where the router's UPnP is scoped.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -d ${site.gamingSubnet} -p udp -m multiport --dports 3074,4380,27015:27030 -j nixos-fw-accept
  '';
}
