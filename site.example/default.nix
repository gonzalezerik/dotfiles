# Placeholder for the private `site` input (see flake.nix). Copy it, fill in
# your own network, and point the input at your copy.
{
  location = "Yosemite Valley, CA";

  hosts = {
    px13 = [ "192.0.2.10" ];
    desktop = "192.0.2.20";
  };

  gamingSubnet = "192.0.2.0/24";

  homelabSubnets = [ "198.51.100.0/24" ];

  builders = {
    builder1 = {
      ip = "198.51.100.10";
      key = "<builder host key>";
      maxJobs = 4;
      speedFactor = 1;
    };
  };

  authorizedKeys = [ ];

  disks = {
    px13 = { root = "cc044c00-759b-4ae1-88fb-b8a299c98183"; boot = "9CED-7A91"; sdcard = "b2e4f8d4-7c92-4c62-9614-d36473f3bd2f"; };
    desktop = { root = "36ddb8ee-b531-4e70-bebd-e1db9fed6235"; boot = "90E5-8191"; swap = "987ef977-9c5d-49de-ad27-dd078a388a91"; };
  };

  # Optional: directories of kernel patches to apply instead of
  # hosts/<host>/kernel-patches (same file names).
  # kernelPatches = { px13 = ./kernel-patches/px13; };

  gitEmail = "you";

  forgejo = {
    url = "https://git.example.com";
    user = "git";
    tokenItem = "Forgejo token";
  };
}
