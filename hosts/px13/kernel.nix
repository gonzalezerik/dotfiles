{ pkgs, site, ... }:
{
  # CachyOS kernel (LTO+BORE) via Chaotic-Nyx, built for this CPU instead of
  # the binary-cache build (generic x86-64-v1). "NATIVE" is CachyOS's
  # X86_NATIVE_CPU (-march=native): znver5 when built on this Ryzen AI MAX+
  # 395. Same ThinLTO, BORE and every other CachyOS default.
  # Note: -march=native follows the machine that builds it - the current
  # kernel was built here; one built on a remote builder targets that CPU.
  #
  # kernel-patches/ (applied in filename order; all verified to apply
  # cleanly to 7.2.6 with plain `patch -p1`, no fuzz):
  #  Upstream, from Linus's tree (7.3), backported unchanged:
  #   01 7bc99dff4d97 asus-armoury: gate PPT writes behind an active fan
  #      curve (safety prerequisite for 02 - no raising power limits while
  #      the firmware fan curve can't keep up)
  #   02 32ca220f74fe asus-armoury: power limits for HN7306EA/EAC (this
  #      laptop) - fixes "asus_armoury: No matching power limits found" and
  #      exposes real PPT/TDP limits (AC 60/70/85W default, battery 45/55/65W)
  #   03 6303451189a6 asus-nb-wmi: map the ProArt key (0x8b) to KEY_PROG3
  #   04 0c7aeb0f5ece tas2783-sdw: don't treat read-only Controls as writable
  #   06 fc56d1e687bc sdw_utils + tas2783-sdw (2 patches): re-prepare the
  #      SoundWire port on the resume path and power the amp Function up
  #      first - fixes speakers silent after s2idle/S0i3 resume
  #   07 173cb3147ba2 tas2783-sdw: split stereo across the two mono amps -
  #      without it only one amp played, left channel out of the right side
  #   08 2e8ff3ac79eb amdgpu: shorten hdmi_frl_status_polling workqueue name
  #      (fixes the "name exceeds WQ_NAME_LEN" warning; context-rebased)
  #  Posted upstream, not merged yet (2-in-1 tablet switch):
  #   20 + 21 Robin Everaars, "platform/x86: asus-wmi: make the tablet switch
  #      work on the ProArt PX13" v1 (on lore.kernel.org), tested on this
  #      model (HN7306EAC). The hinge is
  #      read at LID_FLIP_ROG, but folding notifies with NOTIFY_LID_FLIP and
  #      sets the UNKNOWN bit, so stock asus-wmi never reports SW_TABLET_MODE.
  #      Paired with asus_nb_wmi tablet_mode_sw=3 below. v2 only swaps in
  #      FIELD_GET(), which the maintainer asked to drop again.
  #  Local, the ONLY non-upstream patch (keep until the kernel has a real fix):
  #   10 amd_sfh: deliver feature replies as HID_FEATURE_REPORT. Without it
  #      the 7.x HID core rejects the sensor hub's feature replies ("Event
  #      data for report 1/4 was too short", ~1/s) and feature-backed sensor
  #      attributes read wrong (accel sampling frequency 10 instead of 12.5,
  #      hysteresis 0 instead of 1.27). Accelerometer samples and auto-rotate
  #      still work without it (tested 2026-09-29). Root cause: the driver's
  #      report_type[] array is never written (bug since 2020, exposed by HID
  #      core commit 0a3fe972a7cb). Fix prepared for upstream (linux-input)
  #      2026-09-29; same message on other AMD SFH devices, e.g.
  #      github.com/ublue-os/bazzite/issues/5796.
  # Drop each patch once the CachyOS kernel reaches a release containing it.
  boot.kernelPackages =
    let
      base = pkgs.linuxPackages_cachyos;
      native = base.cachyOverride {
        cachyVars = base.kernel.cachyConfig.cachyVars // { "_processor_opt" = "NATIVE"; };
      };
    in
    native.extend (_final: prev: {
      kernel = prev.kernel.override (old: {
        kernelPatches = (old.kernelPatches or [ ]) ++ map (name: {
          inherit name;
          patch = (site.kernelPatches.px13 or ./kernel-patches) + "/${name}";
        }) (builtins.attrNames (builtins.readDir ./kernel-patches));
      });
    });
}
