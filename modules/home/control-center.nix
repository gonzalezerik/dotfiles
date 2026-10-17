{ config, pkgs, lib, osConfig, site, ... }:
# macOS-style Control Center for Noctalia (plugin erikg/control, sources in
# ./files/noctalia-control). Installed into Noctalia's local plugin dir, which it
# discovers as the built-in "local" source; enabled once with
#   noctalia msg plugins enable erikg/control
# (the enabled list lives in Noctalia's mutable state, next to vpn-manager).
#
# The panel reads state through one helper script with absolute tool paths,
# because the noctalia systemd user service has a minimal PATH.
let
  sys = osConfig.services;
  # The VPN page shows Mullvad / Tailscale cards only where they run.
  hasMullvad = sys.mullvad-vpn.enable;
  hasTailscale = sys.tailscale.enable;

  noctaliaBin = "${config.programs.noctalia.package}/bin/noctalia";

  stateHelper = pkgs.writeShellScript "noctalia-control-state" ''
    export PATH=${lib.makeBinPath (with pkgs; [
      coreutils gnugrep gnused gawk networkmanager bluez wireplumber
      brightnessctl power-profiles-daemon playerctl pulseaudio upower
      jq
    ] ++ lib.optional hasMullvad pkgs.mullvad ++ lib.optional hasTailscale pkgs.tailscale)}

    con=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null)

    wifi() {
      [ "$(nmcli -t -f WIFI general 2>/dev/null)" = enabled ] && echo wifi=on || echo wifi=off
      echo "ssid=$(printf '%s\n' "$con" | awk -F: '$2 == "802-11-wireless" { print $1; exit }')"
      # From NetworkManager's cached scan (--rescan no: never triggers a scan);
      # this driver leaves /proc/net/wireless empty.
      echo "signal=$(nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | awk -F: '$1 == "*" { print $2; exit }')"
    }

    battery() {
      for b in /sys/class/power_supply/BAT*; do
        [ -e "$b/capacity" ] || continue
        echo "bat=$(cat "$b/capacity")"
        echo "batstatus=$(cat "$b/status")"
        break
      done
    }

    # amdgpu: busy %, dedicated VRAM (the BIOS carve-out) and GTT (GPU
    # allocations in system RAM), in bytes.
    gpu() {
      for d in /sys/class/drm/card*/device; do
        [ -e "$d/mem_info_vram_total" ] || continue
        echo "gpubusy=$(cat "$d/gpu_busy_percent")"
        echo "vramused=$(cat "$d/mem_info_vram_used")"
        echo "vramtotal=$(cat "$d/mem_info_vram_total")"
        echo "gttused=$(cat "$d/mem_info_gtt_used")"
        echo "gtttotal=$(cat "$d/mem_info_gtt_total")"
        break
      done
    }

    # Sound page: devices, streams and defaults as one JSON object.
    audio() {
      printf '{"sinks":%s,"sources":%s,"streams":%s,"defaultSink":"%s","defaultSource":"%s"}\n' \
        "$(pactl -f json list sinks 2>/dev/null || echo '[]')" \
        "$(pactl -f json list sources 2>/dev/null || echo '[]')" \
        "$(pactl -f json list sink-inputs 2>/dev/null || echo '[]')" \
        "$(pactl get-default-sink 2>/dev/null)" \
        "$(pactl get-default-source 2>/dev/null)"
    }

    # Bluetooth page: one tab-separated line per known/discovered device.
    bt() {
      bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo "power	on" || echo "power	off"
      bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
        info=$(bluetoothctl info "$mac" 2>/dev/null)
        get() { printf '%s\n' "$info" | awk -v k="$1:" '$1 == k { print $2; exit }'; }
        bat=$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\([0-9]*\)).*/\1/p')
        printf 'dev\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mac" "$name" "$(get Paired)" "$(get Connected)" "$bat" "$(get Icon)"
      done
    }

    # Power page: UPower battery details as key=value.
    power() {
      bat=$(upower -e 2>/dev/null | grep -m1 BAT)
      [ -n "$bat" ] && upower -i "$bat" | awk -F': *' '
        /state:/ { print "state=" $2 } /percentage:/ { print "percent=" $2 }
        /time to empty:/ { print "toempty=" $2 } /time to full:/ { print "tofull=" $2 }
        /energy-rate:/ { print "rate=" $2 } /capacity:/ { print "health=" $2 }'
      echo "profile=$(powerprofilesctl get 2>/dev/null)"
      echo "profiles=$(powerprofilesctl list 2>/dev/null | sed -n 's/^[* ] *\([a-z-]*\):$/\1/p' | tr '\n' ' ')"
    }

    # VPN page: Mullvad and Tailscale daemons, tab-separated.
    #   mullvad <state> <country> <city> <relay hostname>
    #   mullvadloc <constraint words from `mullvad relay get`, e.g. country us>
    #   tailscale <BackendState> <ip> <tailnet> <exit node id>
    #   exit <host> <ip> <online> <in use>      (peers offering an exit node)
    vpn() {
      mullvad status -j 2>/dev/null | jq -r '
        (.details.location? // {}) as $l
        | "mullvad\t\(.state)\t\($l.country // "")\t\($l.city // "")\t\($l.hostname // "")"'
      mullvad relay get 2>/dev/null | awk '$1 == "Location:" { $1 = ""; sub(/^ +/, ""); print "mullvadloc\t" $0; exit }'
      tailscale status --json 2>/dev/null | jq -r '
        "tailscale\t\(.BackendState)\t\(.Self.TailscaleIPs[0]? // "")\t\(.CurrentTailnet.Name? // "")\t\(.ExitNodeStatus.ID? // "")",
        (.Peer // {} | to_entries[] | .value | select(.ExitNodeOption)
         | "exit\t\(.HostName)\t\(.TailscaleIPs[0])\t\(.Online)\t\(.ExitNode)")'
    }

    # Mullvad relay locations: "country <code> <name>", each followed by
    # its "city <country code> <city code> <name>" lines.
    vpncountries() {
      mullvad relay list 2>/dev/null | awk '
        /^[^\t].* \([a-z]+\)$/ {
          cc = $NF; gsub(/[()]/, "", cc); name = $0; sub(/ \([a-z]+\)$/, "", name)
          print "country\t" cc "\t" name; next }
        /^\t[^\t].* \([a-z]+\) @/ {
          line = $0; sub(/^\t/, "", line); sub(/ @.*$/, "", line)
          code = line; sub(/^.* \(/, "", code); sub(/\)$/, "", code); sub(/ \([a-z]+\)$/, "", line)
          print "city\t" cc "\t" code "\t" line }'
    }

    # Bar widgets poll a single section; the panel asks for everything.
    case "''${1:-}" in
      vpn) vpn; exit 0 ;;
      vpn-countries) vpncountries; exit 0 ;;
      # `tailscale up` refuses unless every non-default pref (operator,
      # hostname, ...) is repeated, and prints the exact command that keeps
      # them; run that one.
      tailscale-up)
        out=$(tailscale up 2>&1) && exit 0
        cmd=$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*\(tailscale up .*\)$/\1/p' | head -n1)
        [ -n "$cmd" ] || { printf '%s\n' "$out" >&2; exit 1; }
        read -ra argv <<< "$cmd"
        exec "''${argv[@]}" ;;
      wifi) wifi; exit 0 ;;
      battery) battery; exit 0 ;;
      gpu) gpu; exit 0 ;;
      audio) audio; exit 0 ;;
      bt) bt; exit 0 ;;
      power) power; exit 0 ;;
    esac

    wifi
    battery

    bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo bt=on || echo bt=off
    echo "btdev=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)"

    # Every active VPN: Mullvad, Tailscale, then NetworkManager profiles
    # (Mullvad's own wg0-mullvad link is not an NM profile of its own).
    vpns=""
    add() { vpns="''${vpns:+$vpns · }$1"; }
    command -v mullvad >/dev/null && [ "$(mullvad status -j 2>/dev/null | jq -r .state)" = connected ] && add Mullvad
    command -v tailscale >/dev/null && [ "$(tailscale status --json 2>/dev/null | jq -r .BackendState)" = Running ] && add Tailscale
    nm=$(printf '%s\n' "$con" | awk -F: '($2 == "vpn" || $2 == "wireguard") && $1 != "wg0-mullvad" { print $1 }')
    [ -z "$nm" ] && [ -e /sys/class/net/wg-lab ] && nm=wg-lab
    while IFS= read -r n; do [ -n "$n" ] && add "$n"; done <<< "$nm"
    [ -n "$vpns" ] && echo vpn=on || echo vpn=off
    echo "vpnname=$vpns"

    echo "dnd=$(${noctaliaBin} msg notification-dnd-status 2>/dev/null)"

    v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    echo "vol=$(printf '%s' "$v" | awk '{ printf "%d", $2 * 100 + 0.5 }')"
    case "$v" in *MUTED*) echo muted=on ;; *) echo muted=off ;; esac

    echo "bri=$(brightnessctl -m -c backlight 2>/dev/null | head -n1 | cut -d, -f4 | tr -d %)"

    echo "profile=$(powerprofilesctl get 2>/dev/null)"

    echo "mstatus=$(playerctl status 2>/dev/null)"
    echo "title=$(playerctl metadata title 2>/dev/null | head -n1)"
    echo "artist=$(playerctl metadata artist 2>/dev/null | head -n1)"
    echo "art=$(playerctl metadata mpris:artUrl 2>/dev/null | head -n1)"
  '';

  pluginDir = ".local/share/noctalia/plugins/control";

  # The same NixOS snowflake as the rEFInd entry icon and the Plymouth
  # splash (configuration.nix): nixos-icons' white variant. Noctalia tints
  # it with the widget icon color (primary - the colour rEFInd and Plymouth
  # recolour it to), so it follows the theme.
  nixosLogo = pkgs.runCommand "nixos-snowflake-bar.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    rsvg-convert -w 96 -h 96 \
      ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg -o $out
  '';
  # Reads/writes niri's colour profiles (~/.config/niri/color-profiles.kdl)
  # for the Display page; niri reloads that file itself.
  colorProfileHelper = pkgs.writers.writePython3Bin "niri-color-profile" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./files/niri-color-profile.py);

  pathsLuau = pkgs.writeText "paths.luau" ''
    return {
      state = "${stateHelper}",
      colorProfile = "${colorProfileHelper}/bin/niri-color-profile",
      noctalia = "${noctaliaBin}",
      nmcli = "${pkgs.networkmanager}/bin/nmcli",
      pactl = "${pkgs.pulseaudio}/bin/pactl",
      bluetoothctl = "${pkgs.bluez}/bin/bluetoothctl",
${lib.optionalString hasMullvad ''      mullvad = "${pkgs.mullvad}/bin/mullvad",
''}${lib.optionalString hasTailscale ''      tailscale = "${pkgs.tailscale}/bin/tailscale",
''}    }
  '';

  # The plugin as ONE store directory (not per-file links): Noctalia resolves
  # require() from each file's real path, so lib/ and pages/ modules must
  # live next to each other in the store.
  plugin = pkgs.runCommand "noctalia-plugin-erikg-control" { } ''
    cp -r ${./files/noctalia-control} $out
    chmod -R u+w $out
    cp ${pathsLuau} $out/paths.luau
    cp ${site.iconFont.map or ../../site.example/icon-font.luau} $out/lib/icon-font.luau
  '';
in
{
  home.file = {
    "${pluginDir}".source = plugin;
    ".local/share/noctalia/nixos-snowflake.png".source = nixosLogo;
    # ICC profiles the Display page offers (docs/color-profiles).
    ".local/share/icc" = {
      source = ../../docs/color-profiles/icc;
      recursive = true;
    };
  };

  # MPRIS CLI for Now Playing metadata (also handy on its own).
  home.packages = [ pkgs.playerctl ];
}
