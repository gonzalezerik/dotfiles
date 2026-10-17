{ pkgs, lib, site, ... }:
# System-wide typography: SF Pro for all UI and document text, plus the
# Control Center's icon font when the private site input provides one
# (site.iconFont.fonts: a tarball of font files). Installed as system fonts
# (not just the user profile) so Flatpak apps see them too: Flatpak maps
# /run/current-system/sw/share/X11/fonts into every sandbox.
#
# Monospace is SF Mono, with Nerd Font Symbols behind it so terminal
# prompts/nvim still get their powerline and file-type glyphs.
let
  # Apple's SF Pro (Display, Text, Rounded + the variable "SF Pro" with
  # automatic optical sizing), as mirrored from developer.apple.com/fonts.
  sf-pro = pkgs.stdenvNoCC.mkDerivation {
    pname = "sf-pro";
    version = "2021-06-22";
    src = pkgs.fetchFromGitHub {
      owner = "sahibjotsaggu";
      repo = "San-Francisco-Pro-Fonts";
      rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
      hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
    };
    installPhase = ''
      install -Dm644 -t $out/share/fonts/opentype *.otf
      install -Dm644 -t $out/share/fonts/truetype *.ttf
    '';
  };

  # Apple's SF Mono, as mirrored from developer.apple.com/fonts.
  sf-mono = pkgs.stdenvNoCC.mkDerivation {
    pname = "sf-mono";
    version = "2021-04-07";
    src = pkgs.fetchFromGitHub {
      owner = "supercomputra";
      repo = "SF-Mono-Font";
      rev = "1409ae79074d204c284507fef9e479248d5367c1";
      hash = "sha256-3wG3M4Qep7MYjktzX9u8d0iDWa17FSXYnObSoTG2I/o=";
    };
    installPhase = ''
      install -Dm644 -t $out/share/fonts/opentype *.otf
    '';
  };

  iconFont = lib.optional (site ? iconFont) (pkgs.runCommand "icon-font" { } ''
    tar -xf ${site.iconFont.fonts}
    find . -name '*.otf' -exec install -Dm644 -t $out/share/fonts/opentype {} +
  '');

  # Families that apps and web pages commonly ask for by name. Each one gets
  # SF Pro put in front of it (prepend, strong binding), so the name still
  # resolves to SF Pro even though Liberation/TeX Gyre/DejaVu/Noto are
  # installed as metric aliases; the original stays behind it as a glyph
  # fallback (CJK, symbols, ...).
  overridden = [
    "Arial" "Helvetica" "Helvetica Neue" "Times New Roman" "Times" "Georgia"
    "Verdana" "Tahoma" "Trebuchet MS" "Segoe UI" "system-ui" "-apple-system"
    "BlinkMacSystemFont" "Liberation Sans" "Liberation Serif" "TeX Gyre Heros"
    "DejaVu Sans" "DejaVu Serif" "Noto Sans" "Noto Serif" "Cantarell" "Ubuntu"
    "Open Sans" "Roboto"
  ];
  # Same idea for monospace families asked for by name (code blocks on web
  # pages, editors, PDFs).
  overriddenMono = [
    "Courier New" "Courier" "Menlo" "Monaco" "Consolas" "DejaVu Sans Mono"
    "Liberation Mono" "Noto Sans Mono" "Source Code Pro" "Roboto Mono"
    "Ubuntu Mono" "JetBrains Mono"
  ];
  prepend = to: family: ''
    <match target="pattern">
      <test qual="any" name="family"><string>${family}</string></test>
      <edit name="family" mode="prepend" binding="strong"><string>${to}</string></edit>
    </match>
  '';
in
{
  nixpkgs.overlays = [ (_: _: { inherit sf-pro sf-mono; }) ];

  fonts.packages = [ sf-pro sf-mono pkgs.nerd-fonts.symbols-only ] ++ iconFont;

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "SF Pro" "Noto Sans" "Noto Sans CJK SC" ];
    serif     = [ "SF Pro" "Noto Serif" "Noto Sans CJK SC" ];
    monospace = [ "SF Mono" "Symbols Nerd Font Mono" "JetBrainsMono Nerd Font" ];
    emoji     = [ "Noto Color Emoji" ];
  };

  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${pkgs.lib.concatMapStrings (prepend "SF Pro") overridden}
      ${pkgs.lib.concatMapStrings (prepend "SF Mono") overriddenMono}
    </fontconfig>
  '';
}
