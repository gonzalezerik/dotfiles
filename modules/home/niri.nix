{ config, pkgs, lib, osConfig, ... }:
# niri config. Keybinds follow i3 where niri has an equivalent ($mod = Super
# = "Mod"). Host-specific pieces come from osConfig.dotfiles.display and
# dotfiles.niri.{extraConfig,extraBinds} (hosts/<name>/home.nix).
let
  cfg = osConfig.dotfiles;
  d = cfg.display;
  t = cfg.theme;

  # Mod+p: Jellyfin picture-in-picture (see the script for how it works).
  jellyfin-pip = pkgs.writeShellApplication {
    name = "jellyfin-pip";
    runtimeInputs = [ pkgs.niri pkgs.jq ];
    text = builtins.readFile ./files/jellyfin-pip.sh;
  };

  # Opens the Noctalia VPN panel.
  toggle-vpn = pkgs.writeShellScriptBin "toggle-vpn" ''
    noctalia msg panel-toggle andrewdems/vpn-manager:panel
  '';
in
{
  options.dotfiles.niri = {
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific niri config, appended after the shared rules.";
    };
    extraBinds = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific binds, added inside the binds block.";
    };
  };

  config = {
    home.packages = [ toggle-vpn pkgs.nwg-displays ];

    xdg.configFile."niri/config.kdl".text = ''
      // ── Input ────────────────────────────────────────────────────────────
      input {
          keyboard {
              xkb {
                  layout "us"
              }
              repeat-delay 600
              repeat-rate 25
          }
          touchpad {
              tap
              natural-scroll
              scroll-method "two-finger"
              dwt
          }

          // Hand the power key to logind instead of niri's own handling
          // (which suspends).
          disable-power-key-handling
      }

      output "${d.output}" {
          mode "${d.mode}"
          scale ${d.scale}
          position x=0 y=0
      ${lib.optionalString d.vrr ''
          variable-refresh-rate on-demand=true
      ''}${lib.optionalString d.autoRotate ''
          // Follow the accelerometer (iio-sensor-proxy) when folded into
          // tent/tablet (niri's auto-rotate feature, pkgs/niri).
          auto-rotate
      ''}    // HDR (niri HDR fork): SDR as usual, HDR while a fullscreen app
          // shows HDR content (brief blank on each switch).
          hdr mode="auto"
      }

      // Colour profiles (fork only): `color-profile` sections written by the
      // Control Center (Display > Colour profile). Optional: no file, no error.
      include optional=true "~/.config/niri/color-profiles.kdl"

      // Display layout written by the nwg-displays GUI; included after the
      // output block above so its settings win. The trailing comment is the
      // exact text nwg-displays looks for; without it, it tries to prepend
      // its own include to the read-only config.kdl.
      include optional=true "~/.config/niri/monitor.kdl" // include "monitor.kdl"

      // ── Layout ───────────────────────────────────────────────────────────
      layout {
          gaps 8

          preset-column-widths {
              proportion 0.333
              proportion 0.5
              proportion 0.667
              proportion 1.0
          }
          default-column-width { proportion 0.5; }

          // The wallpaper's two line colours (primary / secondary), the
          // same hexes as the Noctalia palette.
          focus-ring {
              width 2
              active-color "${t.primary}"
              inactive-color "${t.secondary}"
          }
          border { off; }
      }

      // ── Liquid glass (blur) ──────────────────────────────────────────────
      // Compositor background blur (niri 26.04+, wiki: Window-Effects).
      // Retune live with Mod+Shift+c (load-config-file).
      blur {
          passes 3
          offset 4.0
          noise 0.02
          saturation 1.6 // >1 = extra vibrancy behind glass, like macOS
      }

      // Round + clip every window so blur has a rounded shape to follow.
      window-rule {
          geometry-corner-radius 20
          clip-to-geometry true
      }

      // Blur only behind the windows that are actually translucent: foot,
      // zathura (its zathurarc paints foot's surface at 0.80) and
      // Thunderbird (same, via its userChrome). Blurring behind opaque
      // windows would be an invisible full-screen blur pass. Non-xray blur is
      // experimental upstream and drops out during open/close animations.
      window-rule {
          match app-id=r#"^foot"#
          match app-id=r#"^org\.pwmt\.zathura$"#
          match app-id=r#"^thunderbird$"#
          background-effect {
              blur true
              xray false
          }
      }

      // Helium: frosted glass only while unfocused. Chromium can't make just
      // its background translucent, so this fades the whole window to foot's
      // alpha; its theme (helium.nix) is foot's surface colour. Opaque on
      // focus, with no blur pass behind it while in use.
      window-rule {
          match app-id=r#"^helium$"# is-focused=false
          opacity 0.80
          background-effect {
              blur true
              xray false
          }
      }

      // Noctalia's bar/panels/notifications/OSD: non-xray blur (Noctalia's
      // documented namespace regex for niri).
      layer-rule {
          match namespace=r#"^noctalia-(bar-[^"]+|notification|dock|panel|attached-panel|osd)$"#
          background-effect {
              xray false
          }
      }
      layer-rule {
          match namespace="noctalia-window-switcher"
          background-effect {
              blur true
              xray false
          }
      }

      // ── Environment ──────────────────────────────────────────────────────
      environment {
          DISPLAY ":0"
          QT_QPA_PLATFORM "wayland"
          MOZ_ENABLE_WAYLAND "1"
      }

      screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
      prefer-no-csd

      // Clipboard history
      spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
      spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"

      // ── Window rules ─────────────────────────────────────────────────────
      // Games: VRR follows them on outputs with on-demand VRR. "gamescope"
      // is nested gamescope (HDR launch option).
      window-rule {
          match app-id=r#"^steam_app_"#
          match app-id=r#"^gamescope$"#
          variable-refresh-rate true
      }

      // Browsers + mail -> workspace 2
      window-rule {
          match app-id=r#"(?i)chromium"#
          match app-id=r#"(?i)thunderbird"#
          open-on-workspace "2"
      }

      // Gimp -> workspace 3, floating
      window-rule {
          match app-id=r#"(?i)gimp"#
          open-on-workspace "3"
          open-floating true
      }

      window-rule { match app-id=r#"org\.gnome\.Nautilus"#; open-floating true; }

      // Jellyfin picture-in-picture: Mod+p floats Jellium in the bottom-right
      // corner; while floating it stays visible above fullscreen windows
      // (games) - the fork's float-above-fullscreen rule (niri PR #4062).
      window-rule {
          match app-id=r#"^net\.nullsum\.JelliumDesktop$"#
          float-above-fullscreen true
      }

      ${config.dotfiles.niri.extraConfig}
      // ── Keybinds ─────────────────────────────────────────────────────────
      binds {
          // Escape hatch while Moonlight (or a game) holds the shortcuts
          // inhibitor: toggles it off so Mod binds act on this machine again.
          Mod+Escape hotkey-overlay-title="Toggle shortcut capture (Moonlight/games)" allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

          Mod+Return { spawn "foot"; }
          Mod+d { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
          Mod+Shift+q { close-window; }

          // ── Focus: vim hjkl. j/k fall back to the next column, since a
          // column usually holds a single window.
          Mod+h { focus-column-left; }
          Mod+j { focus-window-down-or-column-right; }
          Mod+k { focus-window-up-or-column-left; }
          Mod+l { focus-column-right; }
          Mod+Left  { focus-column-left; }
          Mod+Down  { focus-window-down-or-column-right; }
          Mod+Up    { focus-window-up-or-column-left; }
          Mod+Right { focus-column-right; }

          // ── Move: Shift + the same direction
          Mod+Shift+h { move-column-left; }
          Mod+Shift+j { move-window-down; }
          Mod+Shift+k { move-window-up; }
          Mod+Shift+l { move-column-right; }
          Mod+Shift+Left  { move-column-left; }
          Mod+Shift+Down  { move-window-down; }
          Mod+Shift+Up    { move-window-up; }
          Mod+Shift+Right { move-column-right; }

          // ── Layout
          Mod+BracketLeft  { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }
          Mod+v { toggle-column-tabbed-display; }
          // Mod+f = true fullscreen (edge to edge, scanned out directly - the
          //         Wayland equivalent of exclusive fullscreen)
          // Mod+e = half width (the default, two side by side)
          // Mod+Shift+f = full width but still gapped; again to go back
          Mod+f { fullscreen-window; }
          Mod+e { set-column-width "50%"; }
          Mod+Shift+f { maximize-column; }
          Mod+w { spawn "noctalia" "msg" "overview" "open"; }

          Mod+Shift+Space { toggle-window-floating; }

          // Jellyfin picture-in-picture; works while a game holds the
          // shortcuts inhibitor.
          Mod+p hotkey-overlay-title="Jellyfin picture-in-picture" allow-inhibiting=false { spawn "${jellyfin-pip}/bin/jellyfin-pip"; }

          // ── Resize
          Mod+r       { set-column-width "-10%"; }
          Mod+Shift+r { set-column-width "+10%"; }
          Mod+Ctrl+r  { set-window-height "-10%"; }
          Mod+Ctrl+Shift+r { set-window-height "+10%"; }

          // ── Workspaces
      ${lib.concatMapStrings (n: ''
          Mod+${toString (lib.mod n 10)} { focus-workspace ${toString n}; }
          Mod+Shift+${toString (lib.mod n 10)} { move-window-to-workspace ${toString n}; }
      '') (lib.range 1 10)}
          // ── Session
          Mod+Shift+c { spawn "niri" "msg" "action" "load-config-file"; }
          Mod+Shift+e { quit; }
          Mod+Shift+v { spawn "toggle-vpn"; }
          Ctrl+Alt+L      { spawn "noctalia" "msg" "session" "lock"; }
          Ctrl+Alt+Delete { spawn "noctalia" "msg" "session" "power-menu"; }

          // ── Audio
          XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "2%+"; }
          XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "2%-"; }
          XF86AudioMute        { spawn "wpctl" "set-mute"   "@DEFAULT_AUDIO_SINK@" "toggle"; }
          XF86AudioMicMute     { spawn "wpctl" "set-mute"   "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

          // ── Brightness
          XF86MonBrightnessUp   { spawn "brightnessctl" "set" "+10%"; }
          XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }

          // ── Screenshots: Mod+s area select, Mod+Shift+s focused window
          Print       { screenshot; }
          Ctrl+Print  { screenshot-screen; }
          Shift+Print { screenshot-window; }
          Mod+s       { screenshot; }
          Mod+Shift+s { screenshot-window; }

      ${config.dotfiles.niri.extraBinds}
      }
    '';
  };
}
