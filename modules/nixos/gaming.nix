{ config, pkgs, lib, ... }:
# Steam the SteamOS way on both machines: the niri desktop for normal play, a
# "Steam" greeter session (gamescope, gamepad UI, HDR) like a Steam Deck.
let
  d = config.dotfiles.display;
in
{
  # Steam, as on wiki.nixos.org/wiki/Steam. programs.steam also turns on
  # hardware.steam-hardware (controller udev rules) and 32-bit graphics. The
  # client itself is X11 (via xwayland-satellite).
  programs.steam = {
    enable = true;
    # PROTON_ENABLE_HDR=1: GE-Proton offers HDR to games (DXVK_HDR=1).
    package = pkgs.steam.override {
      extraEnv = { PROTON_ENABLE_HDR = "1"; }
        // lib.optionalAttrs config.dotfiles.protonWayland { PROTON_ENABLE_WAYLAND = "1"; };
    };
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    # GE-Proton from nixpkgs ("GE-Proton" in the compatibility list).
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    # Unwrapped gamescope inside Steam's FHS env as /usr/bin/gamescope: the
    # cap_sys_nice wrapper in /run/wrappers fails there (Steam runs with
    # NoNewPrivs). HDR on the niri desktop is a per-game launch option:
    #   /usr/bin/gamescope -W <w> -H <h> -r <hz> -f --hdr-enabled
    #     --force-grab-cursor -- env DXVK_HDR=1 %command%
    extraPackages = [ pkgs.gamescope ];
    # "Steam" session in the greeter: Steam's gamepad UI in gamescope (HDR,
    # VRR, Steam button and overlay all work there).
    gamescopeSession = {
      enable = true;
      args = [ "-W" (toString d.width) "-H" (toString d.height) "-r" (toString d.refresh) ]
        ++ lib.optional d.vrr "--adaptive-sync"
        ++ [ "--hdr-enabled" "--expose-wayland" ];
      steamArgs = [ "-gamepadui" "-pipewire-dmabuf" ];
    };
  };

  # enableWsi: gamescope's Vulkan WSI layer, needed for HDR inside gamescope
  # (wiki.nixos.org/wiki/Steam#Gamescope_HDR).
  programs.gamescope = {
    enable = true;
    capSysNice = true;
    enableWsi = true;
  };

  # Performance governor/platform profile while a game runs with the launch
  # option `gamemoderun %command%`.
  programs.gamemode.enable = true;

  # Official Discord client (wiki.nixos.org/wiki/Discord) and Prism Launcher
  # (Minecraft). Unsandboxed: Discord's game detection sees running games,
  # and games/mods (Minecraft's Rich Presence mod) reach its socket in
  # $XDG_RUNTIME_DIR.
  users.users.erikg.packages = [ pkgs.discord pkgs.prismlauncher ];

  environment.systemPackages = [ pkgs.mangohud ];
}
