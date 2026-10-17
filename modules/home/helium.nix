{ config, pkgs, lib, osConfig, ... }:
# Helium browser, themed in the host palette to match Noctalia / foot / niri.
#
# The theme is a plain Chromium theme extension generated from the same hexes
# as foot's colors-dark, loaded with --load-extension on every launch.
# Everything (sidebar, toolbar, frame, NTP) is foot's background so the
# vertical tab strip, the top bar and the gap around the rounded web contents
# read as one surface, and so the unfocused-window blur in niri (niri.nix)
# tints exactly like foot's does.
#
# Helium keeps its own lavender accent (focus ring, filled buttons): its
# baseline palette is hard-coded, extension themes can't set it, and the
# Chromium "user color" seed that could would repaint every surface in a
# lighter Material slate instead of the surface colour.
#
# Layout knobs (vertical tabs, rounded frame, minimal URL, hidden avatar) are
# regular Helium settings under helium.browser.* in the profile, not flags.
let
  t = osConfig.dotfiles.theme;
  rgb = hex: map (i: lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex))) [ 0 2 4 ];

  bg        = rgb t.surface; # foot background / Noctalia mSurface
  surface   = rgb t.surfaceVariant;
  fg        = rgb t.onSurface; # foot foreground
  fgBright  = rgb t.onSecondary;
  fgDim     = rgb t.onSurfaceVariant;
  primary   = rgb t.primary;

  # A stable path keeps the unpacked extension's ID stable across rebuilds.
  themeDir = ".local/share/helium/${t.slug}-theme";
in
{
  # Written as a single file so the directory itself is a real, writable
  # directory: Chromium caches the compiled theme ("Cached Theme.pak") next to
  # manifest.json, and a stable path keeps the unpacked extension's ID stable
  # across rebuilds.
  home.file."${themeDir}/manifest.json".text = builtins.toJSON {
    manifest_version = 3;
    name = t.slug;
    version = "1.0";
    theme.colors = {
      frame                        = bg;
      frame_inactive               = bg;
      frame_incognito              = bg;
      frame_incognito_inactive     = bg;
      # The vertical tab strip is painted with the toolbar color, so this has
      # to be bg too or the sidebar stops matching foot.
      toolbar                      = bg;
      tab_text                     = fgBright;
      tab_background_text          = fgDim;
      tab_background_text_inactive = fgDim;
      bookmark_text                = fg;
      toolbar_text                 = fg;
      toolbar_button_icon          = fgDim;
      omnibox_background           = surface;
      omnibox_text                 = fg;
      ntp_background               = bg;
      ntp_header                   = bg;
      ntp_text                     = fg;
      ntp_link                     = primary;
    };
  };

  # ungoogled-chromium fork; packaged via helium-flake input, since imputnet
  # only ships .deb/AppImage upstream. Wrapped rather than
  # helium.override { flags }: the override re-derives the package and drags
  # its whole build closure (gtk4, gst-plugins-bad, ...) back in, while this
  # only needs the helium that's already built.
  home.packages = [
    (pkgs.symlinkJoin {
      name = "helium-${t.slug}";
      paths = [ pkgs.helium ];
      postBuild = ''
        rm $out/bin/helium
        cat > $out/bin/helium <<EOF
        #!${pkgs.runtimeShell}
        exec ${pkgs.helium}/bin/helium --load-extension=${config.home.homeDirectory}/${themeDir} "\$@"
        EOF
        chmod +x $out/bin/helium

        # The .desktop files Exec the unwrapped store path directly.
        for f in $out/share/applications/*.desktop; do
          src=$(readlink -f "$f")
          rm "$f"
          sed "s|${pkgs.helium}/bin/helium|$out/bin/helium|g" "$src" > "$f"
        done
      '';
    })
  ];
}
