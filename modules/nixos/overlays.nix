{ config, inputs, ... }:
let
  cfg = config.dotfiles;
in
{
  nixpkgs.overlays = [
    inputs.helium-flake.overlays.default
    (final: prev: {
      niri = final.callPackage ../../pkgs/niri {
        inherit (prev) niri;
        src = inputs.niri-src;
        autoRotate = cfg.display.autoRotate;
      };
      xwayland-satellite = final.callPackage ../../pkgs/xwayland-satellite.nix {
        inherit (prev) xwayland-satellite;
        build = cfg.xwaylandSatellite;
      };
      # Upstream fix for nested gamescope losing its app_id after the window
      # is unmapped, which stopped the niri `^gamescope$` VRR rule matching
      # (ValveSoftware/gamescope#2446). Not in a release yet (3.16.31); drop
      # once nixpkgs ships a gamescope that contains e0602ccc.
      gamescope = prev.gamescope.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (final.fetchpatch {
            url = "https://github.com/ValveSoftware/gamescope/commit/e0602ccc313b6dee0dabb09c67e50a28eb784de9.patch";
            hash = "sha256-PwgviWfW9EzibLBV1aVYI+8VfJoCq4JMml0STplnx2E=";
          })
        ];
      });
    })
  ];
}
