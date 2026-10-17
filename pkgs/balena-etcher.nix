# balenaEtcher from the official upstream .deb (not in nixpkgs or Flathub).
# The GUI is autoPatchelf'd; etcher-util is a vercel/pkg binary that patchelf
# would corrupt, so it runs unmodified inside an FHS env (as root via pkexec).
{ pkgs }:
let
  inherit (pkgs) lib stdenv;
  version = "2.1.7";
  src = pkgs.fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${version}/balena-etcher_${version}_amd64.deb";
    hash = "sha256-nb6mFl3e4ewfG3o4/pLw0sVMYhdxBDinr2dSwmfRk5U=";
  };

  utilRaw = stdenv.mkDerivation {
    pname = "etcher-util-raw";
    inherit version src;
    nativeBuildInputs = [ pkgs.dpkg ];
    unpackPhase = "dpkg --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner --one-top-level=root";
    installPhase = "install -Dm755 root/usr/lib/balena-etcher/resources/etcher-util $out/etcher-util";
    dontStrip = true;
    dontPatchELF = true;
  };

  utilFhs = pkgs.buildFHSEnv {
    name = "etcher-util";
    targetPkgs = p: [ p.stdenv.cc.cc.lib p.util-linux p.systemd p.coreutils ];
    runScript = "${utilRaw}/etcher-util";
  };
in
stdenv.mkDerivation {
  pname = "balena-etcher";
  inherit version src;

  nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook makeWrapper asar ];
  buildInputs = with pkgs; [
    alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat glib gtk3 libdrm libgbm
    libxkbcommon nspr nss pango systemd libGL stdenv.cc.cc.lib
    libx11 libxcomposite libxdamage libxext libxfixes
    libxrandr libxcb libxshmfence
  ];
  runtimeDependencies = with pkgs; [ systemd libGL wayland vulkan-loader ];

  unpackPhase = "dpkg --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner --one-top-level=root";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt $out/bin $out/share
    cp -r root/usr/lib/balena-etcher $out/opt/
    cp -r root/usr/share/pixmaps $out/share/
    install -Dm644 root/usr/share/applications/balena-etcher.desktop -t $out/share/applications

    res=$out/opt/balena-etcher/resources
    # Unpack the asar to a plain app/ dir (allowed: OnlyLoadAppFromAsar fuse is off)
    asar extract $res/app.asar $res/app
    rm -rf $res/app.asar $res/app.asar.unpacked
    # NixOS has no /usr/bin/pkexec or /bin/bash
    substituteInPlace $res/app/.webpack/renderer/main_window/index.js \
      --replace-fail '["/usr/bin/kdesudo","/usr/bin/pkexec"]' '["/run/wrappers/bin/pkexec"]' \
      --replace-fail 'n.push("/bin/bash")' 'n.push("${pkgs.bash}/bin/bash")'

    rm $res/etcher-util
    ln -s ${utilFhs}/bin/etcher-util $res/etcher-util

    makeWrapper $out/opt/balena-etcher/balena-etcher $out/bin/balena-etcher \
      --prefix PATH : ${lib.makeBinPath [ pkgs.util-linux ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.libGL pkgs.vulkan-loader ]}:/run/opengl-driver/lib \
      --add-flags "--ozone-platform-hint=auto --enable-wayland-ime"
    runHook postInstall
  '';

  dontStrip = true;
  meta.mainProgram = "balena-etcher";
}
