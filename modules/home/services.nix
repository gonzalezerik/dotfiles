{ config, pkgs, ... }:
# Session services: XWayland, HDR toasts, idle/lock/suspend.
let
  noctalia = "${config.programs.noctalia.package}/bin/noctalia";
in
{
  # ── XWayland satellite ───────────────────────────────────────────────────
  # niri has no built-in XWayland; xwayland-satellite runs a rootless Xserver
  # that forwards X11 windows (Steam's client, ...) into the session.
  systemd.user.services.xwayland-satellite = {
    Unit = {
      Description = "XWayland satellite (rootless X11 for niri)";
      Documentation = "https://github.com/Supreeeme/xwayland-satellite";
      BindsTo = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      # sd_notifies once Xwayland is up, so ExecStartPost waits for that.
      Type = "notify";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      # niri's `environment { DISPLAY ":0" }` only reaches processes niri
      # spawns itself; apps Noctalia launches (systemd-run / D-Bus
      # activation) need it in the systemd and D-Bus environments too.
      # DISPLAY=:0 explicitly: given a bare name, the tool reads the value
      # from its own environment, which doesn't have it.
      ExecStartPost = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY=:0";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── HDR notification ─────────────────────────────────────────────────────
  # "HDR on"/"HDR off" whenever niri switches an output into or out of HDR,
  # keyed off niri's own "updated HDR signalling" log line (written only
  # once the display accepted the new mode).
  systemd.user.services.hdr-notify = {
    Unit = {
      Description = "Notify when niri switches a display into or out of HDR";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "niri.service" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellApplication {
        name = "hdr-notify";
        runtimeInputs = with pkgs; [ systemd gnused gnugrep coreutils libnotify ];
        text = builtins.readFile ./files/hdr-notify.sh;
      }}/bin/hdr-notify";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── Idle, lock, suspend ──────────────────────────────────────────────────
  # dim (300 s) -> lock (330 s) -> suspend (600 s). On the laptop only on
  # battery (Noctalia's battery hooks stop it on AC, noctalia.nix).
  # swayidle, not hypridle: hypridle needs hyprland-lock-notify-v1, which
  # niri doesn't implement; together with niri's own ScreenSaver service it
  # woke, flashed the lock screen and resuspended.
  # Full store paths: the unit's PATH only has bash in it.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10%";
        resumeCommand = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      { timeout = 330; command = "${noctalia} msg session lock"; }
      { timeout = 600; command = "${pkgs.systemd}/bin/systemctl suspend"; }
    ];
    # Lock before the freeze step, so logind sees the session as locked
    # before suspend commits.
    events.before-sleep = "${noctalia} msg session lock";
  };
}
