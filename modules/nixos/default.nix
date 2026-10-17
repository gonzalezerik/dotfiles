{ ... }:
# Everything both machines share. Hardware, kernel and network specifics are
# in hosts/<name>.
{
  imports = [
    ./options.nix
    ./base.nix
    ./boot.nix
    ./session.nix
    ./gaming.nix
    ./streaming.nix
    ./overlays.nix
    ./home.nix
    ../../fonts
  ];
}
