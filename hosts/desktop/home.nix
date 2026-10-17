{ pkgs, site, ... }:
# desktop-only home: Moonlight launchers for streaming the px13.
{
  # Two stream profiles for the px13 (panel 2880x1800, 60 Hz only): native for
  # sharpness, 1920x1200 (same 16:10, 56% fewer pixels) for lower bitrate.
  # The px13's address depends on its Wi-Fi, so each launcher tries them all.
  xdg.desktopEntries = let
    moonlight-px13 = pkgs.writeShellScript "moonlight-px13" ''
      for ip in ${toString site.hosts.px13}; do
        if ${pkgs.coreutils}/bin/timeout 1 ${pkgs.bash}/bin/bash -c "</dev/tcp/$ip/47989" 2>/dev/null; then
          exec ${pkgs.moonlight-qt}/bin/moonlight stream "$ip" Desktop \
            --display-mode fullscreen --capture-system-keys always \
            --absolute-mouse --no-vsync --no-frame-pacing --no-hdr \
            --video-decoder hardware --keep-awake --fps 60 "$@"
        fi
      done
      ${pkgs.libnotify}/bin/notify-send "Moonlight" "px13 isn't reachable (Sunshine down, asleep, or off the home network)"
      exit 1
    '';
  in {
    moonlight-px13-native = {
      name = "px13 (native 2880×1800)";
      comment = "Stream the px13 at its native resolution";
      icon = "moonlight";
      exec = "${moonlight-px13} --resolution 2880x1800 --video-codec AV1 --bitrate 80000";
      categories = [ "Network" "RemoteAccess" ];
    };
    moonlight-px13-fast = {
      name = "px13 (fast 1920×1200)";
      comment = "Stream the px13 at 1920x1200 for lower latency";
      icon = "moonlight";
      exec = "${moonlight-px13} --resolution 1920x1200 --video-codec HEVC --bitrate 30000";
      categories = [ "Network" "RemoteAccess" ];
    };
  };
}
