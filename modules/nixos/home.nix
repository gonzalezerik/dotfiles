{ inputs, site, ... }:
{
  imports = [
    inputs.noctalia.nixosModules.default
    inputs.chaotic.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit (inputs) noctalia; inherit site; };
    sharedModules = [ inputs.noctalia.homeModules.default ];
    users.erikg = import ../home;
  };
}
