{ config, pkgs, lib, inputs, site, ... }:
# px13: ASUS ProArt PX13 (HN7306EAC), Ryzen AI MAX+ 395 / Radeon 8060S,
# 2880x1800 OLED (60 Hz, HDR), 2-in-1 hinge.
{
  imports = [
    ./hardware-configuration.nix
    ./kernel.nix
    ./audio.nix
    ./network.nix
    ./builders.nix
    inputs.asus-dialpad-driver.nixosModules.default
  ];

  networking.hostName = "px13";

  dotfiles = {
    theme = import ./theme.nix;
    laptop = true;
    gpu = "amd";
    display = {
      output = "eDP-1";
      mode = "2880x1800@60.000";
      width = 2880;
      height = 1800;
      refresh = 60;
      scale = "1.5";
      autoRotate = true;
    };
    # 2880x2880 at native scale, so Noctalia's crop shows it 1:1 in landscape
    # and, rotated, in portrait. gen_heightmap.py 2880 2880 18.0
    wallpaper = {
      heightmap = ./assets/yosemite-heightmap.png;
      demMin = "1173.1304";
      demRange = "1839.9355";
    };
    assets = {
      refindBanner = ./assets/refind-banner.png;
      greeterWallpaper = ./assets/greeter-wallpaper.png;
    };
    # Stock binary-cache CachyOS kernel (generic x86-64, no local patches).
    recoveryKernel = pkgs.linuxPackages_cachyos;
    xwaylandSatellite = "0.8.1";
    # Exclusive-fullscreen games (Proton via xwayland-satellite) never got
    # their mode change; Wine's Wayland driver emulates it (2026-10-08).
    protonWayland = true;
    streaming.allowFrom = [ site.hosts.desktop ];
  };

  home-manager.users.erikg.imports = [ ./home.nix ];

  # amdgpu in the initrd, the way Ubuntu/CachyOS/Fedora initramfs builders
  # include the KMS driver: the splash draws on the real GPU from the start.
  hardware.amdgpu.initrd.enable = true;

  # 2-in-1 (tent/tablet): with kernel patches 20+21, asus-wmi reports
  # SW_TABLET_MODE from the hinge (tablet_mode_sw=3 = lid-flip-rog, this
  # model's hinge devid), and libinput disables the built-in keyboard and
  # touchpad while folded. iio-sensor-proxy serves the accelerometer to
  # niri's auto-rotate.
  boot.extraModprobeConfig = "options asus_nb_wmi tablet_mode_sw=3";
  hardware.sensor.iio.enable = true;

  boot.kernelParams = [
    # GTT/TTM pool size for large local models in unified memory
    # (amdgpu.gttsize is the deprecated way; setting both conflicts).
    "ttm.pages_limit=32505856"
    # A local LLM's Vulkan compute dispatch legitimately runs long at deep
    # context and tripped the compute-ring hang detector ("ring comp_1.3.1
    # timeout", auto-recovered). Raises only the compute timeout;
    # [GFX,Compute,SDMA,Video] ms, 0 = kernel default.
    "amdgpu.lockup_timeout=0,60000,0,0"
  ];

  # 400GB microSD (Steam library). No automount daemon under niri, so mount
  # on first access; nofail keeps boot going without the card, and the 2 s
  # device timeout makes Steam list the library as unavailable instead of
  # hanging on "Loading user data" when it's out.
  fileSystems."/run/media/erikg/SDCARD" = {
    device = "/dev/disk/by-uuid/${site.disks.px13.sdcard}";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" "noauto" "x-systemd.device-timeout=2s" ];
  };

  # asusd: fan curves, battery charge limit. Auto-switching is off in
  # asusd.ron, so power-profiles-daemon owns platform_profile and asusd
  # applies the matching fan curve.
  services.asusd.enable = true;

  # F-row: this keyboard has no fn-lock exposed to Linux, and reports the
  # same key as two keycodes depending on Fn (bare F2 -> KEY_F2, Fn+F2 ->
  # KEY_VOLUMEDOWN). keyd swaps them at the evdev layer, so plain F-keys do
  # the media action and Fn+F-key sends the F-key.
  # "-0000:0000" keeps keyd off "Asus WMI hotkeys" (and the DialPad's virtual
  # device): that device also carries SW_TABLET_MODE, which keyd's grab
  # swallowed - niri stayed in tablet mode with the touchpad off.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" "-0000:0000" ];
      settings.main = {
        f1 = "mute";
        mute = "f1";
        f2 = "volumedown";
        volumedown = "f2";
        f3 = "volumeup";
        volumeup = "f3";
      };
    };
  };

  # niri hands the power key to logind. Ignore short presses so the press
  # that wakes the machine doesn't send it straight back to sleep.
  services.logind.settings.Login.HandlePowerKey = "ignore";
  # logind ignores the lid for 30 s after boot/resume by default, so closing
  # it again right after opening did nothing. 5 s still lets a dock show up.
  services.logind.settings.Login.HoldoffTimeoutSec = "5s";

  # ProArt DialPad: hold a finger on the touchpad's top-right corner ~1 s,
  # then circle to turn the dial. "proartp16" is the layout the driver lists
  # for the PX13 (HN7306*). Wayland only.
  nixpkgs.overlays = [ inputs.asus-dialpad-driver.overlays.default ];
  hardware.asus-dialpad-driver = {
    enable = true;
    layout = "proartp16";
    sessionTypes = [ "wayland" ];
  };
  # Start once niri's socket exists (niri.service is Type=notify), or the
  # first start at login fails to connect and only the restart works.
  systemd.user.services.asus-dialpad-driver.after = [ "niri.service" ];

  users.users.erikg.extraGroups = [
    "input" # asus-dialpad-driver reads the touchpad's evdev node
    "uinput" # ...and emits the dial's events through uinput
    "dialout" # /dev/ttyACM* - Arduino serial
    "docker"
  ];
  virtualisation.docker.enable = true;

  # 1Password via its module: the setgid BrowserSupport helper and polkit
  # policy for system-auth unlock and browser integration.
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "erikg" ];
  };
  programs.thunderbird.enable = true;

  # ── Local AI (ROCm userspace for llama.cpp HIP builds) ───────────────────
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-runtime
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    rocmPackages.hipcc
    cmake
    ninja
  ];
  # hipcc, cmake and the launch scripts expect the toolchain under /opt/rocm.
  systemd.tmpfiles.rules = let
    rocm = pkgs.symlinkJoin {
      name = "rocm-merged";
      paths = with pkgs.rocmPackages; [
        rocm-runtime # HSA runtime (rocminfo, libhsa-runtime)
        clr # HIP runtime (libamdhip64, amdclang++)
        hipcc
        rocblas # required by llama.cpp GGML_HIP
        hipblas
        hipblas-common
        rocm-device-libs # bitcode device libs for hipcc
        rocm-comgr # code object manager (hipcc)
      ];
    };
  in [
    "L+ /opt/rocm - - - - ${rocm}"
    "d /etc/asusd 0755 root root -"
  ];
  # Unlimited memlock for NPU inference (FastFlowLM) without cap_ipc_lock,
  # which would put the binary in secure-exec mode and break its library
  # lookup.
  security.pam.loginLimits = [
    { domain = "erikg"; type = "-"; item = "memlock"; value = "unlimited"; }
  ];

  # ROS 2 / Gazebo prebuilt binaries (nix-ros-overlay).
  nix.settings.substituters = [ "https://ros.cachix.org" "https://attic.iid.ciirc.cvut.cz/ros" ];
  nix.settings.trusted-public-keys = [
    "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
    "ros:JR95vUYsShSqfA1VTYoFt1Nz6uXasm5QrcOsGry9f6Q="
  ];
}
