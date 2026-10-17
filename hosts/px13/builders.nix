{ lib, site, ... }:
# Builds go to remote machines instead of this laptop, whose CPU and memory
# belong to the local LLM and the desktop session. Each builder runs a
# `builder` user that takes only this machine's key.
#
#   nix build / nixos-rebuild      automatic: nix-daemon hands derivations to
#                                  whichever builder has a free slot
#   docker --context <name>        builds and runs on that host's rootless
#                                  daemon (contexts made once per user with
#                                  docker context create <name>
#                                  --docker host=ssh://builder@<ip>)
#   ssh <name>-build               anything else (cargo, make) in a checkout
#                                  on the builder
#
# If no builder answers, nix builds here as before, at idle priority.
# Hosts, keys and job counts: site.builders (private).
{
  nix.distributedBuilds = true;
  nix.buildMachines = lib.mapAttrsToList (_: b: {
    hostName = b.ip;
    protocol = "ssh-ng";
    sshUser = "builder";
    sshKey = "/etc/nix/builder_ed25519"; # root-only, made with ssh-keygen here
    systems = [ "x86_64-linux" ];
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    inherit (b) maxJobs speedFactor;
  }) site.builders;
  # Builders fetch from the binary caches themselves instead of through here.
  nix.settings.builders-use-substitutes = true;
  # The local fallback never competes with the session.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  programs.ssh.knownHosts = lib.mapAttrs (_: b: {
    hostNames = [ b.ip ];
    publicKey = b.key;
  }) site.builders;

  programs.ssh.extraConfig = lib.concatStrings (lib.mapAttrsToList (name: b: ''
    Host ${name}-build
      HostName ${b.ip}
      User builder
  '') site.builders);
}
