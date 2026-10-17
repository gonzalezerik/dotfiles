# dotfiles

NixOS + home-manager for my two machines, one flake:

| Host | Hardware | Palette |
|---|---|---|
| `px13` | ASUS ProArt PX13 (Ryzen AI MAX+ 395, Radeon 8060S), 2880×1800 HDR OLED, 2-in-1 | `px13-blue` |
| `desktop` | Ryzen 7 7800X3D, RTX 5070 Ti, 5120×2160 165 Hz HDR | `desktop-botanical` |

Both run the same setup: rEFInd → Plymouth → noctalia-greeter, [niri](https://github.com/gonzalezerik/niri) (my HDR fork) with the [Noctalia](https://github.com/noctalia-dev/noctalia) shell and a macOS-style Control Center plugin, CachyOS kernel, Steam with a gamescope HDR session, Sunshine/Moonlight between the two. Only the palette and the hardware differ.

## Control Center (Noctalia plugin)

`modules/home/files/noctalia-control` is a macOS-style Control Center for the Noctalia shell, plugin id `erikg/control`, installed by `modules/home/control-center.nix`. It runs on the real system services (NetworkManager, BlueZ, PipeWire, UPower, power-profiles-daemon, Noctalia's IPC); nothing is mocked.

**Bar pills**: battery (laptops), Wi-Fi, search (opens Noctalia's launcher), the Control Center button, a clock, and a hardware pill showing CPU %, RAM used/total and GPU busy % with VRAM used/total.

**The sheet**: Wi-Fi, Bluetooth and VPN tiles (click toggles, the arrow opens that page), *Focus* (Do Not Disturb), *Night Light*, *Keep Awake*, brightness and volume sliders, and Now Playing with album art and playback controls (MPRIS).

**Pages**, all inside the sheet:

- **Wi-Fi**: the current network with signal and IP, nearby networks (saved first), join with an inline password field, forget.
- **Bluetooth**: power, your devices with battery levels, connect/disconnect, discover and pair new ones.
- **Sound**: output and input devices, per-app volume.
- **VPN**: Mullvad (connect, relay country and city), Tailscale (up/down, exit node) and every NetworkManager VPN/WireGuard profile, each with its own switch and status. The Mullvad and Tailscale cards appear only on machines that run them.
- **Display**: brightness, Night Light, Keep Awake, what each screen is running at, and its **colour profile** (below).
- **Battery / power**: charge, time to empty/full, battery health, and power-profile selection.

## HDR and colour profiles

Both machines run [niri's `erikg-hdr` branch](https://github.com/gonzalezerik/niri/tree/erikg-hdr): HDR (an output switches to PQ/BT.2020 while a fullscreen app shows HDR content, with `hdr mode="auto"`) plus **per-output colour profiles**, KDE-style:

- **Source**: sRGB, an **ICC profile**, or the display's **EDID** primaries.
- An optional separate **HDR ICC profile**, used while the output is in HDR.
- **SDR colour intensity** (0-100): how far SDR content is stretched towards the panel's native gamut.

The profile is applied in the GPU's own display pipeline (DEGAMMA → CTM → GAMMA), with Night Light composed on top. The Control Center's Display page writes `~/.config/niri/color-profiles.kdl`, which niri reloads live.

**[Color profiles](docs/color-profiles/README.md)**: every ICC profile for both displays, downloadable, the **ASUS ProArt PX13** (HN7306EAC) factory profiles (native/CMDEF, HDR, sRGB, Display P3, DCI-P3) and the **RTINGS** calibration for the **LG UltraGear 45GX950A-B** 5K2K OLED. Each comes with a CIE 1931 gamut chart, tone-response curves, primaries, white point and sRGB / P3 / Rec.2020 coverage.

Around it, the config makes the rest of the HDR stack work: mpv tags its surface with the video's colour space (HDR10/Dolby Vision through libplacebo); games get HDR in the gamescope "Steam" session, or on the niri desktop through a nested-gamescope launch option; a toast says "HDR on/off" whenever an output switches.

To build and configure that niri yourself, including the opt-in `auto-rotate` feature for 2-in-1 laptops, see the [branch's README](https://github.com/gonzalezerik/niri/tree/erikg-hdr#readme). This flake builds it from that branch in `pkgs/niri`.

## Layout

```
flake.nix
hosts/<name>/        hardware, kernel, theme.nix (palette), host-only extras
modules/nixos/       everything shared at system level
modules/home/        everything shared in home-manager
  files/             nvim config, starship, Control Center plugin, scripts
pkgs/                niri (fork), xwayland-satellite, small packages
fonts/               SF Pro / SF Mono everywhere
tools/               wallpaper heightmap generator + renderer
docs/color-profiles/ ICC profile analysis and gamut charts for both displays
site.example/        placeholder for the private `site` input
```

One palette per host (`hosts/<name>/theme.nix`) drives Noctalia, the greeter, niri's focus ring, foot, Helium, nvim, starship, zathura, mpv, Plymouth, rEFInd and the wallpaper. The wallpaper is a Yosemite Valley topographic map rendered once at build time from a heightmap (`tools/gen_heightmap.py` makes the heightmap, `tools/wallpaper-render.py` draws the contours).

## The `site` input

Network addresses, homelab hosts, keys and a licensed font live in a separate private repo, read as the `site` flake input. To build without it:

```sh
nix build .#nixosConfigurations.px13.config.system.build.toplevel \
  --override-input site path:./site.example
```

## Use

```sh
sudo nixos-rebuild switch --flake .#px13
```

Personal config, shared for reference.
