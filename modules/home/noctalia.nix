{ config, pkgs, lib, osConfig, noctalia, site, ... }:
let
  cfg = osConfig.dotfiles;
  t = cfg.theme;

  # Yosemite Valley topo wallpaper, rendered once at build time from the
  # host's 16-bit heightmap into a plain PNG (tools/wallpaper-render.py) and
  # shown by Noctalia as an ordinary image. Contour lines = the palette's
  # secondary (minor) and primary (major).
  wallpaper = pkgs.runCommand "yosemite-topo-${t.slug}.png" {
    nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.numpy p.pillow ])) ];
  } ''
    python3 ${../../tools/wallpaper-render.py} ${cfg.wallpaper.heightmap} $out \
      '${t.secondary}' '${t.primary}' ${cfg.wallpaper.demMin} ${cfg.wallpaper.demRange}
  '';
in
{
  # home-manager now ships its own programs.noctalia, which clashes with the
  # noctalia flake's module. Newer noctalia (2026-09-30+) disables it itself;
  # drop this once the noctalia input is updated past that.
  disabledModules = [ "programs/noctalia" ];

  programs.noctalia = {
    enable = true;
    package = noctalia.packages.x86_64-linux.default;

    # User systemd service - restarts cleanly on update without killing the
    # compositor session.
    systemd.enable = true;

    # Validate config.toml at build time against the real binary.
    checkConfig = true;

    # Material-style palette straight from the host theme (hosts/*/theme.nix):
    # mPrimary and mSecondary/mOutline are the wallpaper's LINE_MAJOR /
    # LINE_MINOR colours, so shell chrome and wallpaper share one source.
    customPalettes.${t.slug}.dark = {
      mPrimary = t.primary;
      mOnPrimary = t.onPrimary;
      mSecondary = t.secondary;
      mOnSecondary = t.onSecondary;
      mTertiary = t.tertiary;
      mOnTertiary = t.onTertiary;
      mError = t.error;
      mOnError = t.onError;
      mSurface = t.surface;
      mOnSurface = t.onSurface;
      mSurfaceVariant = t.surfaceVariant;
      mOnSurfaceVariant = t.onSurfaceVariant;
      mOutline = t.outline;
      mShadow = t.shadow;
      mHover = t.hover;
      mOnHover = t.onHover;
      terminal = {
        background = t.surface;
        foreground = t.onSurface;
        cursor = t.primary;
        cursorText = t.surface;
        selectionBg = t.hover;
        selectionFg = t.onHover;
        normal = t.ansi;
        bright = t.ansiBright;
      };
    };

    # Declarative layer. Noctalia never writes back here; GUI overrides go to
    # ~/.local/state/noctalia/settings.toml (and win over these).
    settings = {
      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = t.slug;
        # Off so bar/panel backgrounds are mSurface - foot's background - and
        # the glass bar tints exactly like foot.
        pure_black_dark = false;
        templates = {
          # gtk3/gtk4 only: Qt apps bridge through GTK (qt.platformTheme
          # gtk3), and niri's focus ring / foot's colours are set from the
          # same palette here, since those configs are read-only store links
          # Noctalia's template writer can't touch.
          enable_builtin_templates = true;
          builtin_ids = [ "gtk3" "gtk4" ];
        };
      };

      # Launch apps via systemd-run into their own units under app.slice, so
      # a Noctalia restart doesn't take every app started from it down too.
      shell.launch_apps_as_systemd_services = true;
      shell.font_family = "SF Pro";
      # Noctalia's own polkit agent (pkexec prompts: balenaEtcher, 1Password
      # system unlock, ...).
      shell.polkit_agent = true;

      # Liquid glass: Noctalia's translucent-panel style, blurred by niri
      # through the layer-rules in niri.nix (xray off, so the blur samples
      # real desktop content).
      shell.corner_radius_scale = 1.3; # matches niri's window radius (20px)
      shell.panel.transparency_mode = "glass";

      # Control Center avatar (also pushed to AccountsService's IconFile).
      # Clauncher pixel art from CLaunch's mascot.
      shell.avatar_path = "~/Pictures/avatars/clauncher.png";

      # OSD and toasts default to 0.97; lower lets the blur show through.
      osd.background_opacity = 0.75;
      notification.background_opacity = 0.8;
      # Toasts on the overlay layer, above fullscreen apps (e.g. "HDR on").
      notification.layer = "overlay";

      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        transition_on_startup = false;
        default.path = "${wallpaper}";
      };

      # Auto-hiding top bar: hidden until the pointer touches the top edge,
      # windows take the full height. Its ends and top edge sit niri's window
      # gap (gaps 8) from the screen edge, so it lines up with the windows.
      bar.main = {
        auto_hide = true;
        reserve_space = false;
        margin_ends = 8;
        margin_edge = 8;
        # Same glass as foot: mSurface at foot's alpha 0.80.
        background_opacity = 0.80;

        # Every widget in its own pill: surface_variant fill, no outline at
        # rest. The right-side pills are erikg/control plugin widgets
        # (control-center.nix) with a primary outline on hover. Built-in pills
        # can't draw an outline - their hover is a 10% tint of the widget
        # colour, hence color = "primary" on them.
        capsule = true;
        capsule_fill = "surface_variant";
        capsule_opacity = 0.85;
        capsule_padding = 8;
        icon_color = "primary";

        # Left: NixOS logo (session menu), hardware pill (CPU, RAM, GPU +
        # VRAM), printers (hidden unless a job is queued or a printer errors).
        # Middle: workspaces and weather.
        # Right, macOS order: battery (laptop), Wi-Fi, search, Control Center,
        # clock, tray drawer. Brightness, volume, Bluetooth and Now Playing
        # live in the Control Center.
        start = [ "session" "cc-hardware" "andrewdems/printers:printer" ];
        center = [ "workspaces" "weather" ];
        end = lib.optional cfg.laptop "cc-battery"
          ++ [ "cc-wifi" "cc-search" "cc-button" "cc-clock" "tray" ];
      };

      widget = {
        # erikg/control pills (they draw their own capsule).
        cc-battery.type = "erikg/control:battery";
        cc-wifi.type = "erikg/control:wifi";
        cc-search.type = "erikg/control:search";
        cc-button.type = "erikg/control:button";
        cc-clock.type = "erikg/control:clock";
        cc-hardware.type = "erikg/control:hardware";

        # Glyph + temperature only; condition text is in the tooltip.
        weather = {
          show_condition = false;
          color = "primary";
        };

        # Power/session menu: the same snowflake as rEFInd and Plymouth.
        session = {
          custom_image = "~/.local/share/noctalia/nixos-snowflake.png";
          custom_image_colorize = true;
          color = "primary";
        };

        # Background apps go into one drawer button instead of each landing
        # on the bar. Right-click an item -> Pin to keep it on the bar.
        tray = {
          drawer = true;
          hide_passive = true;
          color = "primary";
        };
      };

      # Weather (Open-Meteo): IP geolocation first, the address as fallback.
      location = {
        auto_locate = true;
        address = site.location;
      };
      weather = {
        enabled = true;
        unit = "imperial";
      };
    } // lib.optionalAttrs cfg.laptop {
      # Stay awake on AC: swayidle (dim/lock/suspend, idle.nix) runs only on
      # battery. Stopped when the charger goes in, started when it comes out,
      # so the battery timeouts count from the unplug; `started` covers boot
      # and Noctalia restarts. Stopping swayidle rather than caffeine:
      # caffeine is a logind inhibitor, which swayidle doesn't consult.
      hooks = let
        swayidle = action: "${pkgs.systemd}/bin/systemctl --user ${action} swayidle.service";
      in {
        battery_charging = swayidle "stop";
        battery_plugged = swayidle "stop";
        battery_discharging = swayidle "start";
        started = "${pkgs.bash}/bin/sh -c 'if [ \"$(cat /sys/class/power_supply/AC0/online)\" = 1 ]; then ${swayidle "stop"}; else ${swayidle "start"}; fi'";
      };
    };
  };

  # Lock screen authenticates against /etc/pam.d/noctalia (session.nix).
  systemd.user.services.noctalia.Service.Environment = [ "NOCTALIA_PAM_SERVICE=noctalia" ];
}
