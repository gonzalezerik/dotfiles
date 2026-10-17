{ pkgs, lib, site, ... }:
# Mullvad + the homelab WireGuard (wg-lab, a NetworkManager profile so the
# Control Center can toggle it) + Tailscale, all at once.
let
  homelab = lib.concatStringsSep ", " (site.homelabSubnets ++ [ site.hosts.desktop ]);
in
{
  # Mullvad: daemon + CLI plus the GUI. Its DNS handling expects
  # systemd-resolved; NetworkManager picks that up.
  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };
  services.resolved.enable = true;

  # Tailscale (reach the rover's Orin from anywhere). --operator lets erikg
  # run `tailscale up/down/set` (Control Center VPN page) without sudo.
  services.tailscale.enable = true;
  services.tailscale.extraSetFlags = [ "--operator=erikg" ];

  # Mullvad's firewall drops anything outside its tunnel. Its documented
  # exclusion marks (mullvad.net/en/help/split-tunneling-with-linux-advanced:
  # ct mark 0xf41 passes the firewall, meta mark 0x6d6f6c65 routes outside
  # the tunnel) let through:
  #  - the homelab over wg-lab (its subnets, DNS included);
  #  - the tailnet (100.64.0.0/10, fd7a:115c:a1e0::/48, MagicDNS);
  #  - incoming connections on tailscale0 / wg-lab;
  #  - the desktop both ways, for Sunshine/Moonlight.
  # tailscaled's own traffic is NOT excluded: Mullvad's ip rules sit before
  # Tailscale's, so it rides the Mullvad tunnel and peers go via DERP relay.
  # wg-lab's own UDP to the router also goes through Mullvad.
  systemd.services.mullvad-coexist = let
    rules = pkgs.writeText "mullvad-coexist.nft" ''
      table inet mullvad-coexist {}
      delete table inet mullvad-coexist
      table inet mullvad-coexist {
        set homelab4 {
          type ipv4_addr; flags interval
          elements = { ${homelab} }
        }
        chain excludeOutgoing {
          type route hook output priority -100; policy accept;
          ip daddr @homelab4 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
          ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
          ip6 daddr fd7a:115c:a1e0::/48 ct mark set 0x00000f41 meta mark set 0x6d6f6c65
        }
        chain allowIncoming {
          type filter hook input priority -100; policy accept;
          iifname { "tailscale0", "wg-lab" } ct mark set 0x00000f41
          ip saddr ${site.hosts.desktop} ct mark set 0x00000f41
        }
      }
    '';
  in {
    description = "Let homelab (wg-lab) and Tailscale traffic past Mullvad's firewall";
    wantedBy = [ "multi-user.target" ];
    before = [ "mullvad-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.nftables}/bin/nft -f ${rules}";
      ExecStop = "${pkgs.nftables}/bin/nft delete table inet mullvad-coexist";
    };
  };

  # KDE Connect protocol (Valent, home.nix): discovery + transfers.
  networking.firewall = rec {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
