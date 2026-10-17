{ config, pkgs, ... }:

# Pixel (GrapheneOS) ↔ px13, the Linux take on macOS iPhone Mirroring +
# Continuity:
#
#   scrcpy  - the phone's screen in a window, driven by mouse + keyboard,
#             phone audio played on the laptop. Talks adb, so the phone needs
#             Developer options → USB debugging (and Wireless debugging for
#             Wi-Fi). On GrapheneOS, keep these off when not mirroring.
#   Valent  - KDE Connect protocol (GTK4): notifications, SMS, clipboard,
#             files, media control. Phone side: KDE Connect from F-Droid.
#             Ports 1714-1764 are opened in configuration.nix.
#
# Wi-Fi: after a one-time `adb pair <ip>:<pairing-port>`, adb auto-connects
# over mDNS whenever Wireless debugging is on. Both that and Valent need the
# phone reachable on the LAN, which Mullvad blocks unless local network
# sharing is allowed (`mullvad lan set allow`). USB always works.
#
# adb USB access needs no udev rules or group: systemd's uaccess covers
# Android devices (nixpkgs dropped programs.adb for this reason).
let
  # Mirror the phone itself, shaped like the phone (iPhone Mirroring style):
  # borderless, 900 logical px tall with width from the screen's aspect, and
  # the niri rule in erikg.nix rounds the corners to match the panel. The
  # phone's screen turns off while mirrored and it locks when the window
  # closes. uhid = the phone sees a real hardware keyboard (layout set once
  # in Android's Physical keyboard settings); the mouse stays sdk so it
  # clicks like touch, no pointer grab. Move it with Mod+drag.
  pixel-mirror = pkgs.writeShellScriptBin "pixel-mirror" ''
    exec ${pkgs.scrcpy}/bin/scrcpy --window-title=Pixel --window-borderless \
      --window-height=900 --turn-screen-off --power-off-on-close \
      --keyboard=uhid "$@"
  '';
  # A separate 1080p Android desktop: apps open in their own virtual display
  # while the phone's own screen is left alone.
  desktopArgs = "--window-title=Pixel-Desktop --new-display=1920x1080/180 --keyboard=uhid";
in
{
  home.packages = with pkgs; [
    android-tools # adb
    scrcpy
    pixel-mirror
    valent
  ];

  xdg.desktopEntries.pixel-mirror = {
    name = "Pixel";
    genericName = "Phone mirroring";
    icon = "phone";
    exec = "${pixel-mirror}/bin/pixel-mirror";
    categories = [ "Utility" ];
  };

  xdg.desktopEntries.pixel-desktop = {
    name = "Pixel Desktop";
    genericName = "Phone apps in a desktop-sized window";
    icon = "phone";
    exec = "${pkgs.scrcpy}/bin/scrcpy ${desktopArgs}";
    categories = [ "Utility" ];
  };

  # Valent runs as a background service with a tray-less GApplication; open
  # its window from the launcher to pair or change plugins.
  systemd.user.services.valent = {
    Unit = {
      Description = "Valent (KDE Connect protocol)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "niri.service" ];
    };
    Service = {
      ExecStart = "${pkgs.valent}/bin/valent --gapplication-service";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
