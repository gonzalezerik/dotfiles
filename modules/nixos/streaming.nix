{ config, pkgs, lib, ... }:
# Sunshine (stream host) + Moonlight (client) between the two machines. KMS
# capture of niri's scanout; the web UI (47990) stays on localhost. Each host
# lists the peers allowed to reach the stream ports in
# dotfiles.streaming.allowFrom: 47984/47989/48010 TCP = pairing + RTSP,
# 47998-48000 UDP = video, control, audio.
let
  cfg = config.dotfiles.streaming;
  nvidia = config.dotfiles.gpu == "nvidia";
  sources = lib.concatStringsSep "," cfg.allowFrom;
in
{
  options.dotfiles.streaming.allowFrom = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Addresses allowed to reach Sunshine's stream ports.";
  };

  config = {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true; # KMS capture
      openFirewall = false;
      # nixpkgs builds Sunshine without CUDA by default, which leaves out NVENC.
      package = if nvidia then pkgs.sunshine.override { cudaSupport = true; } else pkgs.sunshine;
      settings = {
        sunshine_name = config.networking.hostName;
        origin_web_ui_allowed = "pc";
        capture = "kms";
        # radeonsi: VA-API is the mature path (auto picks the newer Vulkan encode).
        encoder = if nvidia then "nvenc" else "vaapi";
      };
    };

    networking.firewall.extraCommands = lib.mkIf (cfg.allowFrom != [ ]) ''
      iptables -A nixos-fw -s ${sources} -p tcp -m multiport --dports 47984,47989,48010 -j nixos-fw-accept
      iptables -A nixos-fw -s ${sources} -p udp -m multiport --dports 47998:48000,48010 -j nixos-fw-accept
    '';

    environment.systemPackages = [ pkgs.moonlight-qt ];
  };
}
