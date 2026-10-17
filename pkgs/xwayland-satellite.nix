# xwayland-satellite builds, per host (dotfiles.xwaylandSatellite):
#
#   "0.8.1"    px13. 0.8.2's regression (3273a0f) closes X11 override-redirect
#              popups ~35 ms after they open (JDownloader's menus, Steam's
#              context menus; Supreeeme/xwayland-satellite#503). The upstream
#              fix (add2795) blanked JDownloader's window here, so the last
#              release before the regression.
#   "add2795"  desktop. 0.8.2 + the fix ("never focus override-redirect
#              popups", #494): Steam's menus no longer close about a second
#              after opening. No JDownloader there.
#
# Both are in v0.8.3 (now in nixpkgs-unstable): switch to "nixpkgs" after the
# next nixpkgs bump, once JDownloader renders on the px13 with it.
{ xwayland-satellite, build, fetchFromGitHub, rustPlatform }:

if build == "0.8.1" then
  xwayland-satellite.overrideAttrs (old: rec {
    version = "0.8.1";
    src = fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "refs/tags/v0.8.1";
      hash = "sha256-BUE41HjLIGPjq3U8VXPjf8asH8GaMI7FYdgrIHKFMXA=";
    };
    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit src;
      name = "xwayland-satellite-${version}";
      hash = "sha256-16L6gsvze+m7XCJlOA1lsPNELE3D364ef2FTdkh0rVY=";
    };
  })
else if build == "add2795" then
  xwayland-satellite.overrideAttrs (old: rec {
    version = "0.8.2-unstable-2026-09-09";
    src = fetchFromGitHub {
      owner = "Supreeeme";
      repo = "xwayland-satellite";
      rev = "add2795134593faafce60e404a0a75df68e9ee0c";
      hash = "sha256-0TxfMgqW0/BLD4M942c5DCKYrtPvzsPJwvdcco4LQUM=";
    };
    cargoDeps = rustPlatform.importCargoLock {
      lockFile = "${src}/Cargo.lock";
      allowBuiltinFetchGit = true;
    };
  })
else
  xwayland-satellite
