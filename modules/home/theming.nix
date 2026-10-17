{ pkgs, osConfig, ... }:
# GTK/Qt accent and surface colours come from the Noctalia palette through
# its builtin gtk3/gtk4 templates (noctalia.nix); adw-gtk3-dark is the base
# skin those templates recolour at runtime.
{
  gtk = {
    enable = true;
    theme.name = "adw-gtk3-dark";
    theme.package = pkgs.adw-gtk3;
    # Tela, nord colour, dark: flat dark-slate folders and dark app icons.
    iconTheme.name = "Tela-nord-dark";
    iconTheme.package = pkgs.tela-icon-theme;
    font.name = "SF Pro"; # ../../fonts: system-wide SF Pro
    font.size = 11;
  };

  # Cursor for Wayland-native and XWayland apps.
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true; # propagates XCURSOR_* for XWayland
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  # Dark mode for apps that query the settings portal.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = "Adwaita";
    cursor-size = 24;
    icon-theme = "Tela-nord-dark";
    font-name = "SF Pro 11";
    document-font-name = "SF Pro 11";
    monospace-font-name = "SF Mono 11";
    # Closest GNOME preset to the palette, for apps that only read this enum.
    accent-color = osConfig.dotfiles.theme.gnomeAccent;
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];
}
