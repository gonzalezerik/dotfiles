{
  description = "NixOS + home-manager for two machines (px13 laptop, desktop): niri (HDR fork) + Noctalia";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Track the cachix branch: always points to the latest already-built commit.
    # No nixpkgs.follows - following our nixpkgs invalidates noctalia.cachix.org
    # and forces a multi-hour local C++ rebuild. Bump it together with nixpkgs:
    # its glibc has to be at least the system's, or the lock screen's PAM
    # modules fail to load.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    # CachyOS kernel via the Chaotic-Nyx binary cache. No nixpkgs.follows
    # either - it's pinned to whatever nixpkgs rev the cache was built against.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    # Helium isn't in nixpkgs - imputnet only ships a .deb/AppImage upstream.
    # This flake grabs the GitHub-release .deb and patches it to run on NixOS.
    helium-flake.url = "github:oxcl/nix-flake-helium-browser";
    helium-flake.inputs.nixpkgs.follows = "nixpkgs";

    # ProArt DialPad (px13): userspace driver for the virtual dial on the
    # touchpad's top-right corner. Pinned to the release tag.
    asus-dialpad-driver = {
      url = "github:asus-linux-drivers/asus-dialpad-driver/v2.5.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri with HDR: my fork (dividebysandwich's HDR branch + fixes, colour
    # profiles, auto-rotate). Built with nixpkgs' niri recipe, see pkgs/niri.
    niri-src = {
      url = "github:gonzalezerik/niri/erikg-hdr";
      flake = false;
    };

    # Private values (LAN addresses, homelab hosts, location) live in a
    # separate, unpublished repo. To build this flake without it:
    #   --override-input site path:./site.example
    site = {
      url = "git+file:///home/erikg/Projects/dotfiles-private";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      mkHost = name: nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          site = import inputs.site;
        };
        modules = [ ./modules/nixos ./hosts/${name} ];
      };
    in
    {
      nixosConfigurations = {
        px13 = mkHost "px13";
        desktop = mkHost "desktop";
      };
    };
}
