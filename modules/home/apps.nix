{ pkgs, site, ... }:
# Apps both machines have, all from nixpkgs (Electron/CEF ones run native
# Wayland through NIXOS_OZONE_WL). Flatpak only for what nixpkgs lacks:
# Jellium Desktop, the Jellyfin client with HDR (no native client works yet:
# nixpkgs' jellyfin-desktop 2.0.0 uses the HTML player and makes the server
# transcode everything).
{
  home.packages = with pkgs; [
    # Clipboard, screenshots (Noctalia has its own UI; these for scripts)
    wl-clipboard
    cliphist
    grim
    slurp

    nautilus
    xdg-utils
    pavucontrol # fallback mixer

    # Display brightness: internal backlight, external monitors over DDC/CI
    brightnessctl
    ddcutil

    # Music
    spotify
    feishin
    # Fyne only speaks Wayland when built with the `wayland` tag.
    (supersonic.overrideAttrs (old: { tags = (old.tags or [ ]) ++ [ "wayland" ]; }))

    slack

    # USB image writer (pkgs/balena-etcher.nix; asks for root via Noctalia's
    # polkit agent)
    (callPackage ../../pkgs/balena-etcher.nix { })

    yt-dlp

    # Bitwarden CLI for Vaultwarden. Vaultwarden 1.37.4+ rejects add/edit
    # (422, missing encryptedFor); carry doy/rbw#386 until it merges.
    (rbw.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (fetchpatch {
          url = "https://github.com/doy/rbw/commit/d65cba5c0353.patch";
          hash = "sha256-4MkFo2fEQ+V92gWGh8CKaJgZl1vYKeNLdN6hqYThJVM=";
        })
      ];
    }))
    pinentry-qt # rbw's master-password prompt
    immich-go # bulk photo upload to Immich

    # Mail: local Maildir copies of old inboxes. mbsync pulls, notmuch
    # indexes, aerc reads; Outlook.com needs XOAUTH2 via oama tokens.
    (isync.override { withCyrusSaslXoauth2 = true; })
    notmuch
    aerc
    oama
    libsecret # secret-tool, oama's gnome-keyring backend
  ];

  # ── Git / GitHub ─────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = "Erik Gonzalez";
      user.email = site.gitEmail;
      init.defaultBranch = "main";
      # Homelab Forgejo: scoped token straight from Vaultwarden at push/pull
      # time, so no password sits in remote URLs or a credentials file.
      credential.${site.forgejo.url}.helper =
        "!f() { test \"$1\" = get || exit 0; echo username=${site.forgejo.user}; "
        + "echo \"password=$(${pkgs.rbw}/bin/rbw get '${site.forgejo.tokenItem}')\"; }; f";
    };
  };
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  # ── Default apps ─────────────────────────────────────────────────────────
  # Video/audio -> mpv (mpv.nix), PDFs -> zathura (nvim.nix).
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "helium.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  programs.home-manager.enable = true;
}
