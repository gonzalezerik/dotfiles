# HorizonHaptics: DualSense adaptive triggers for Forza Horizon 6.
# FH6 has no native trigger support on PC; this reads the game's "Data Out"
# UDP telemetry (port 5300) and writes trigger effects to the controller's
# hidraw node (access comes from hardware.steam-hardware's uaccess rules).
#
#   horizonhaptics          Qt GUI (tuning; settings in ~/.config/horizonhaptics)
#   horizonhaptics-launch   Steam launch option: `horizonhaptics-launch %command%`
#                           runs it headless for the length of the game
#                           (log: ~/.local/state/horizonhaptics/launch.log).
#
# The app's GitHub self-updater is disabled (it unzips over its own directory);
# update by bumping rev/hash here.
{ lib, stdenv, fetchFromGitHub, python3, qt6, makeWrapper, writeShellScriptBin, symlinkJoin }:

let
  python = python3.withPackages (ps: [ ps.pyside6 ps.numpy ps.sounddevice ]);

  app = stdenv.mkDerivation {
    pname = "horizonhaptics";
    version = "1.3.0-unstable-2026-06-03";

    src = fetchFromGitHub {
      owner = "haritha99ch";
      repo = "HorizonHaptics";
      rev = "79fbe2fd7a56e21bd101867dbf14718f2e91ffab";
      hash = "sha256-pt9+O5Sv45AJX6PsElrhXaovGhFGv6MIBDd8oIcx4+k=";
    };

    # Log when Data Out packets arrive (and their size) so a silent setup is
    # diagnosable; upstream only shows this in the GUI.
    patches = [ ./horizonhaptics-log-packets.patch ];

    nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
    buildInputs = [ qt6.qtbase qt6.qtwayland ];
    dontWrapQtApps = true;

    postPatch = ''
      substituteInPlace ui.py \
        --replace-fail 'updater.start_check(lambda' 'None and updater.start_check(lambda'
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/horizonhaptics $out/bin
      cp -r main.py preferences.py ui.py updater.py version.py worker.py \
        Config GameParsers dualsense $out/share/horizonhaptics/
      makeWrapper ${python}/bin/python3 $out/bin/horizonhaptics \
        --add-flags $out/share/horizonhaptics/main.py \
        "''${qtWrapperArgs[@]}"
      install -Dm644 /dev/stdin $out/share/applications/horizonhaptics.desktop <<EOF
      [Desktop Entry]
      Type=Application
      Name=HorizonHaptics
      Comment=DualSense adaptive triggers for Forza Horizon 6
      Exec=$out/bin/horizonhaptics
      Icon=input-gaming
      Categories=Game;Utility;
      EOF
      runHook postInstall
    '';

    meta = {
      description = "DualSense adaptive triggers for Forza Horizon 6 via UDP telemetry";
      homepage = "https://github.com/haritha99ch/HorizonHaptics";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "horizonhaptics";
    };
  };

  # Job control on so the background job keeps SIGINT (non-interactive bash
  # ignores it otherwise); SIGINT runs the app's shutdown, which releases the
  # triggers instead of leaving the last resistance applied.
  launch = writeShellScriptBin "horizonhaptics-launch" ''
    set -m
    logdir="''${XDG_STATE_HOME:-$HOME/.local/state}/horizonhaptics"
    mkdir -p "$logdir"
    [ -f "$logdir/launch.log" ] && mv -f "$logdir/launch.log" "$logdir/launch.log.1"
    ${app}/bin/horizonhaptics --no-gui > "$logdir/launch.log" 2>&1 &
    hh=$!
    "$@"
    rc=$?
    kill -INT "$hh" 2>/dev/null
    wait "$hh" 2>/dev/null
    exit $rc
  '';
in
symlinkJoin {
  name = "horizonhaptics-${app.version}";
  paths = [ app launch ];
  inherit (app) meta;
}
