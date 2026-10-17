{ config, pkgs, ... }:
# niri + Noctalia session, the greeter in front of it, portals and Flatpak.
let
  t = config.dotfiles.theme;
in
{
  # niri: the compositor, its Wayland session for the greeter, and
  # xdg.portal.config.niri (GNOME+GTK). pkgs.niri is the HDR fork
  # (overlays.nix). useNautilus=false: Nautilus comes from home-manager.
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;
  programs.niri.useNautilus = false;

  # noctalia-greeter: a Wayland-native login screen (own embedded compositor
  # via greetd). It shows greeter-wallpaper.png - the host's topo art,
  # blurred and tinted with the surface colour (baked in: there's nothing
  # behind a login screen to blur live) - in the host's palette.
  services.displayManager.noctalia-greeter.enable = true;
  services.displayManager.noctalia-greeter.settings = {
    appearance = {
      scheme = "Synced";
      theme_mode = "dark";
      corner_radius_scale = 1.3; # matches shell.corner_radius_scale (home)
      palette = {
        inherit (t) primary secondary tertiary error surface outline shadow hover;
        on_primary = t.onPrimary;
        on_secondary = t.onSecondary;
        on_tertiary = t.onTertiary;
        on_error = t.onError;
        on_surface = t.onSurface;
        surface_variant = t.surfaceVariant;
        on_surface_variant = t.onSurfaceVariant;
        on_hover = t.onHover;
      };
      wallpaper = {
        path = "${config.dotfiles.assets.greeterWallpaper}";
        fill_mode = "crop";
      };
    };
    session.default = "niri";
  };

  # Unlock GNOME Keyring at login (greetd's PAM service), so the secret
  # portal works without a second password prompt.
  security.pam.services.greetd.enableGnomeKeyring = true;
  # PAM service for Noctalia's lock screen (NOCTALIA_PAM_SERVICE, home).
  security.pam.services.noctalia = { };

  # One implementation each for screencast and screenshot
  # (xdg-desktop-portal-gnome, via PipeWire).
  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.Screencast" = [ "gnome" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
  };

  # Flatpak: only for apps nixpkgs doesn't package (Jellium Desktop, plus
  # OpenBubbles and JDownloader on the px13). Remotes and apps are installed
  # with the flatpak CLI; this enables the service and portals.
  services.flatpak.enable = true;
}
