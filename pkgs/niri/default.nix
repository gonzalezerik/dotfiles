# niri from my fork (github.com/gonzalezerik/niri, branch erikg-hdr):
# dividebysandwich/niri's HDR branch plus GPU-fault fixes, per-output colour
# profiles, the HDR exit grace / pending-fullscreen fixes, the
# `float-above-fullscreen` window rule (niri-wm/niri PR #4062, Zhai Can) and
# auto-rotate as an opt-in cargo feature (enabled with autoRotate, i.e.
# dotfiles.display.autoRotate).
# Everything else - build features, systemd units, portal config, tests - is
# nixpkgs' recipe. HDR is opted into per output with `hdr` in the output
# config.
{ niri, src, autoRotate ? false, rustPlatform, lib }:

niri.overrideAttrs (old: {
  inherit src;
  patches = [ ];
  # Hash-free: follows the fork's Cargo.lock on every `nix flake update`
  # (Smithay is a git dependency, pinned there).
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
  # buildRustPackage copies buildFeatures into cargo{Build,Check}Features
  # when the package is defined, so extend those directly.
  cargoBuildFeatures = old.cargoBuildFeatures ++ lib.optional autoRotate "auto-rotate";
  cargoCheckFeatures = old.cargoCheckFeatures ++ lib.optional autoRotate "auto-rotate";
  env = old.env // { NIRI_BUILD_COMMIT = "erikg-hdr-${src.shortRev}"; };
})
