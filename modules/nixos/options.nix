{ lib, ... }:
# Per-host knobs. Everything shared reads these; each hosts/<name>/default.nix
# sets them. Home-manager modules see them as osConfig.dotfiles.
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.dotfiles = {
    theme = mkOption {
      type = types.attrs;
      description = ''
        The machine's palette (hosts/<name>/theme.nix). One source for
        Noctalia, the greeter, niri, foot, Helium, nvim, starship, zathura,
        mpv, Plymouth, rEFInd and the wallpaper.
      '';
    };

    laptop = mkEnableOption "laptop bits: battery widget and hooks, swayidle only on battery";

    gpu = mkOption {
      type = types.enum [ "amd" "nvidia" ];
      description = "Which GPU drives the session (encoders, hwdec, monitoring tools).";
    };

    display = {
      output = mkOption { type = types.str; description = "niri output name of the main panel."; };
      width = mkOption { type = types.int; };
      height = mkOption { type = types.int; };
      refresh = mkOption { type = types.int; description = "Refresh rate in whole Hz (gamescope)."; };
      mode = mkOption { type = types.str; description = "niri mode string, e.g. 2880x1800@60.000."; };
      scale = mkOption { type = types.str; };
      vrr = mkEnableOption "on-demand variable refresh rate";
      autoRotate = mkEnableOption "auto-rotate from the accelerometer (builds niri with the auto-rotate feature)";
    };

    wallpaper = {
      heightmap = mkOption { type = types.path; description = "16-bit heightmap from gen_heightmap.py."; };
      demMin = mkOption { type = types.str; description = "DEM_MIN_M printed by gen_heightmap.py."; };
      demRange = mkOption { type = types.str; description = "DEM_RANGE_M printed by gen_heightmap.py."; };
    };

    assets = {
      refindBanner = mkOption { type = types.path; };
      greeterWallpaper = mkOption { type = types.path; };
    };

    recoveryKernel = mkOption {
      type = types.raw;
      description = "Kernel package set for rEFInd's recovery entry (binary-cache built).";
    };

    xwaylandSatellite = mkOption {
      type = types.enum [ "nixpkgs" "0.8.1" "add2795" ];
      default = "nixpkgs";
      description = "xwayland-satellite build, see pkgs/xwayland-satellite.nix.";
    };

    protonWayland = mkEnableOption ''
      PROTON_ENABLE_WAYLAND=1 for every game: Wine's Wayland driver emulates
      mode changes, so exclusive-fullscreen games fill the panel. Costs the
      Steam overlay and Steam Input focus tracking (both X11-only)'';
  };
}
