{ config, pkgs, ... }:
# px13-only home: phone mirroring, mail/cloud apps, Arduino tools, tablet
# switch handling.
{
  imports = [ ./phone.nix ];

  dotfiles.niri.extraConfig = ''
    // Tablet mode: libinput already disables the built-in keyboard and
    // touchpad; also switch the keyboard backlight off, restoring it (-s
    // saves, -r restores) on unfold.
    switch-events {
        tablet-mode-on  { spawn "brightnessctl" "-d" "asus::kbd_backlight" "-s" "set" "0"; }
        tablet-mode-off { spawn "brightnessctl" "-d" "asus::kbd_backlight" "-r"; }
    }

    // Phone mirror (phone.nix): a phone-shaped floating window with the
    // panel's corner radius and a drop shadow. app-id is ".scrcpy-wrapped".
    window-rule {
        match app-id=r#"scrcpy"# title=r#"^Pixel$"#
        open-floating true
        geometry-corner-radius 40
        clip-to-geometry true
        focus-ring { off; }
        shadow {
            on
            softness 40
            spread 4
            offset x=0 y=8
            color "#0008"
        }
    }
  '';
  dotfiles.niri.extraBinds = ''
    Mod+Shift+p { spawn "pixel-mirror"; }
  '';

  home.packages = with pkgs; [
    newsflash
    bitwarden-desktop # native: niri hides data-control from Flatpak sandboxes
    protonmail-bridge-gui # launcher entry; the tray instance is the service below
    nextcloud-client # launcher entry; services.nextcloud-client autostarts it

    # Arduino Uno R3 (~/Projects/rtems-arduino): arduino-cli is FHS-wrapped
    # in nixpkgs, so the avr-gcc it downloads runs as-is; tio is a serial
    # console that survives the Uno's reset-on-open.
    arduino-cli
    avrdude
    tio

    # Were imperative `nix profile` installs.
    ffmpeg
    kubectl
    qemu
    sshpass
    tesseract
    python3Packages.huggingface-hub
    python3Packages.hf-transfer
  ];

  # Proton Mail Bridge, hidden in the tray: IMAP 127.0.0.1:1143 / SMTP
  # 127.0.0.1:1025 for Thunderbird. Vault key in gnome-keyring.
  systemd.user.services.proton-bridge = {
    Unit = {
      Description = "Proton Mail Bridge (tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "niri.service" ];
    };
    Service = {
      ExecStart = "${pkgs.protonmail-bridge-gui}/bin/protonmail-bridge-gui --no-window";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Its own "launch on startup" can't point at a store path; HM starts it.
  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  # Glass theme (files/thunderbird) dropped into every Thunderbird profile.
  home.activation.thunderbirdTheme = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    for p in "$HOME"/.thunderbird/*.default*/; do
      [ -f "$p/prefs.js" ] || continue
      run install -Dm644 ${../../modules/home/files/thunderbird/userChrome.css} "$p/chrome/userChrome.css"
      run install -Dm644 ${../../modules/home/files/thunderbird/user.js} "$p/user.js"
    done
  '';

  # Jellium and the music players take no idle inhibitor, so playback on
  # battery dimmed at 5 min and suspended at 10 (2026-10-14). Holds one via
  # niri's ScreenSaver interface whenever a PipeWire output stream runs.
  systemd.user.services.wayland-pipewire-idle-inhibit = {
    Unit = {
      Description = "Inhibit idle while audio or video is playing";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "pipewire.service" ];
    };
    Service = {
      ExecStart = "${pkgs.wayland-pipewire-idle-inhibit}/bin/wayland-pipewire-idle-inhibit --d-bus --quiet";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
