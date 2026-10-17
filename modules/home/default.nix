{ ... }:
# home-manager for erikg, shared by both machines. Host extras are in
# hosts/<name>/home.nix.
{
  imports = [
    ./noctalia.nix
    ./control-center.nix
    ./niri.nix
    ./services.nix
    ./theming.nix
    ./terminal.nix
    ./apps.nix
    ./helium.nix
    ./mpv.nix
    ./nvim.nix
  ];

  home.username = "erikg";
  home.homeDirectory = "/home/erikg";
  home.stateVersion = "26.05";
}
