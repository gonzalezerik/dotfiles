{ config, pkgs, lib, extendModules, ... }:
# rEFInd -> Plymouth -> noctalia-greeter, all in the machine's palette.
let
  cfg = config.dotfiles;
  t = cfg.theme;
  host = config.networking.hostName;
  hex = lib.removePrefix "#";

  # The NixOS snowflake (white variant) recoloured to the palette's primary;
  # the same image is rEFInd's OS icon and Plymouth's watermark.
  snowflake = pkgs.runCommand "nixos-snowflake-${t.slug}.png" { nativeBuildInputs = [ pkgs.imagemagick pkgs.librsvg ]; } ''
    rsvg-convert -w 256 -h 256 \
      ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg -o white.png
    magick white.png -fill '${t.primary}' -colorize 100 $out
  '';

  # Recovery boot entry: this same system on a binary-cache kernel, in case
  # the locally built one ever fails to boot. Built with extendModules (a
  # variant of this exact config) and written as rEFInd's first menu entry.
  recovery = (extendModules {
    modules = [{
      boot.kernelPackages = lib.mkForce cfg.recoveryKernel;
      system.nixos.tags = [ "generic-kernel" ];
      # cut the self-reference (this variant's own bootloader config is
      # never installed)
      boot.loader.refind.extraConfig = lib.mkForce "";
      boot.loader.refind.additionalFiles = lib.mkForce { };
    }];
  }).config;
  recoveryTop = recovery.system.build.toplevel;
in
{
  boot.loader.efi.canTouchEfiVariables = true;
  # rEFInd's menu timeout: the module appends its own `timeout` line after
  # extraConfig, so this is the only setting that counts. A short, visible
  # pause on the themed menu, then the newest generation boots.
  boot.loader.timeout = 1;

  boot.loader.systemd-boot.enable = false;
  # otherwise grub's own mkDefault re-enables it once systemd-boot isn't the
  # active default
  boot.loader.grub.enable = false;
  boot.loader.refind = {
    enable = true;
    # Only the latest generation (roll back with `nixos-rebuild switch
    # --rollback`). Must stay 1: the NixOS installer always writes
    # "default_selection 2" and rEFInd reads a digit as "the Nth loader in the
    # menu"; the recovery entry (extraConfig, before the NixOS entries) is
    # loader #1, so #2 is exactly the newest generation.
    maxGenerations = 1;
    extraConfig = lib.mkMerge [
      ''
        # No auto-scanning: leftover NVRAM entries from old OSes made the scan
        # hang before the menu appeared. Our own menu entries cover NixOS.
        scanfor manual
        # Keep the banner on screen while the kernel + initrd load.
        use_graphics_for linux
        banner banner.png
        banner_scale fillscreen
        # No resolution directive: the firmware GOP can't switch modes
        # cleanly ("max" hung the menu, "1024 768" garbled the screen).
      ''
      (lib.mkAfter ''
        menuentry "NixOS (generic kernel - recovery)" {
          loader /efi/refind/recovery/bzImage
          initrd /efi/refind/recovery/initrd
          options "init=${recoveryTop}/init ${lib.concatStringsSep " " recovery.boot.kernelParams}"
        }
      '')
    ];
    # The module doesn't install rEFInd's own icons/ (the menu is plain text
    # without them). os_linux.png - the icon every NixOS entry falls back to -
    # becomes the snowflake. additionalFiles paths are relative to
    # efi/refind/.
    additionalFiles =
      {
        "banner.png" = cfg.assets.refindBanner;
        "recovery/bzImage" = "${recoveryTop}/kernel";
        "recovery/initrd" = "${recoveryTop}/initrd";
      }
      // (lib.mapAttrs' (
        name: _: lib.nameValuePair "icons/${name}" "${pkgs.refind}/share/refind/icons/${name}"
      ) (builtins.readDir "${pkgs.refind}/share/refind/icons"))
      // { "icons/os_linux.png" = snowflake; };
  };

  # Plymouth: the snowflake on the shell's surface colour with the stock
  # spinner, from kernel handoff to the greeter. Built on plymouth's compiled
  # two-step plugin (the one behind "spinner"/"bgrt"); a script theme booted
  # to a black screen.
  boot.plymouth.enable = true;
  boot.plymouth.theme = "nixos-${host}";
  # Plymouth only puts this one font file in the initrd; the variable SF Pro
  # covers both weights below.
  boot.plymouth.font = "${pkgs.sf-pro}/share/fonts/truetype/SF-Pro.ttf";
  boot.plymouth.themePackages = [
    (pkgs.runCommand "plymouth-theme-nixos-${host}" { } ''
      d=$out/share/plymouth/themes/nixos-${host}
      mkdir -p $d
      cp ${config.boot.plymouth.package}/share/plymouth/themes/spinner/*.png $d/
      cp ${snowflake} $d/watermark.png
      cat > $d/nixos-${host}.plymouth <<EOF
      [Plymouth Theme]
      Name=NixOS ${host}
      Description=NixOS snowflake in the ${t.slug} palette
      ModuleName=two-step

      [two-step]
      Font=SF Pro 12
      TitleFont=SF Pro 30
      ImageDir=$d
      DialogHorizontalAlignment=.5
      DialogVerticalAlignment=.382
      TitleHorizontalAlignment=.5
      TitleVerticalAlignment=.382
      HorizontalAlignment=.5
      VerticalAlignment=.75
      WatermarkHorizontalAlignment=.5
      WatermarkVerticalAlignment=.5
      Transition=none
      TransitionDuration=0.0
      BackgroundStartColor=0x${lib.toLower (hex t.surface)}
      BackgroundEndColor=0x${lib.toLower (hex t.surface)}
      ProgressBarBackgroundColor=0x${lib.toLower (hex t.secondary)}
      ProgressBarForegroundColor=0x${lib.toLower (hex t.primary)}
      MessageBelowAnimation=true

      [boot-up]
      UseEndAnimation=false

      [shutdown]
      UseEndAnimation=false

      [reboot]
      UseEndAnimation=false
      EOF
    '')
  ];

  # Smaller initrd = less for the firmware to read off the ESP. Neither is
  # used: no LVM volumes, no TPM disk unlock. zstd -19 only costs build time.
  services.lvm.enable = false;
  boot.initrd.systemd.tpm2.enable = false;
  boot.initrd.compressorArgs = [ "-19" "-T0" ];

  boot.kernelParams = [
    "quiet" # let Plymouth's splash show ("splash" itself comes from boot.plymouth)
    # Keep udev/systemd from printing to the console behind the splash;
    # everything still lands in the journal.
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "rd.systemd.show_status=auto"
  ];
  # Only critical/alert/emergency kernel lines reach the console.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
}
