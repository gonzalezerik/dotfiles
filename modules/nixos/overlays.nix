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
    })
  ];
}
