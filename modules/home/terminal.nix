{ lib, osConfig, ... }:
# foot, bash + starship, fastfetch - all in the host palette.
let
  t = osConfig.dotfiles.theme;
  hex = lib.removePrefix "#";
  ansiNames = [ "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" ];
  ansiKeys = prefix: colours: lib.listToAttrs (lib.imap0 (i: name: {
    name = "${prefix}${toString i}";
    value = hex colours.${name};
  }) ansiNames);
in
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        # SF Mono (../fonts), Nerd Font symbols as the glyph fallback.
        font = "SF Mono:size=11,Symbols Nerd Font Mono:size=11";
        dpi-aware = "no";
      };
      "colors-dark" = {
        alpha = "0.80"; # low enough that niri's background blur behind it reads
        background = hex t.surface;
        foreground = hex t.onSurface;
        cursor = "${hex t.surface} ${hex t.primary}"; # text-color cursor-color (foot.ini(5))
        selection-foreground = hex t.onHover;
        selection-background = hex t.hover;
      } // ansiKeys "regular" t.ansi // ansiKeys "bright" t.ansiBright;
    };
  };

  # home-manager owns ~/.bashrc / ~/.profile so starship (and
  # home.sessionVariables like EDITOR) actually get loaded in bash.
  programs.bash = {
    enable = true;
    historyControl = [ "erasedups" "ignorespace" ];
    historySize = 50000;
    historyFileSize = 100000;
    shellOptions = [ "histappend" "checkwinsize" "extglob" "globstar" "checkjobs" ];
  };

  # Layout and glyphs in ./files/starship.toml; the palette comes from here.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = lib.importTOML ./files/starship.toml // {
      palette = t.slug;
      palettes.${t.slug} = {
        bg = t.surface;
        on_primary = t.onPrimary;
        float = t.surfaceVariant;
        hover = t.hover;
        fg = t.onSurface;
        fg_bright = t.onSecondary;
        fg_dim = t.onSurfaceVariant;
        primary = t.primary;
        secondary = t.secondary;
        tertiary = t.tertiary;
        red = t.error;
        green = t.success;
        yellow = t.ansi.yellow;
        magenta = t.ansi.magenta;
        muted = t.ansiBright.black;
      };
    };
  };

  # Logo type "sixel": foot speaks sixel, not the kitty graphics protocol.
  # Backdrop-filled PNG so the padding matches foot's own background.
  programs.fastfetch = {
    enable = true;
    settings.logo = {
      type = "sixel";
      source = "/home/erikg/Pictures/avatars/clauncher-bg.png";
      width = 32;
      height = 24;
    };
  };
}
