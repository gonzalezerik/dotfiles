{ pkgs, site, ... }:
{
  # CachyOS kernel (LTO+BORE by default) via Chaotic-Nyx, kconfig-parity with
  # upstream CachyOS.
  # nvidia-open's module build fails to sign its .ko files under this
  # kernel: scripts/sign-file hits an OpenSSL BIO "no such file" error, first
  # on certs/signing_key.pem (fixed by supplying our own pre-generated ECDSA
  # key - see git history) and then on a second, separate hardcoded
  # companion file (certs/signing_key.x509) that would need a real build-phase
  # patch (and another full kernel recompile) to also supply. Not worth
  # chasing further: this machine has no Secure Boot / kernel lockdown
  # enforcement, so module signing has no real security value here anyway.
  # Disabling it, not working around it further.
  #
  # NixOS's own boot.kernelPatches option is a no-op against this externally
  # pre-built package set. The config that actually reaches the build is
  # chaotic-nyx's `configfile` derivation output (a plain text file) - patch
  # that directly.
  #
  # Built for Zen 4 instead of the binary-cache kernel (generic x86-64-v1):
  # "ZEN4" is CachyOS's own MZEN4 kconfig (-march=znver4: AVX-512, VAES, etc.
  # on the 7800X3D). Explicit ZEN4 rather than NATIVE so the result is the
  # same wherever it's built.
  # kernel-patches/ (upstream commits only - drop each once the kernel has it):
  #   08 upstream 2e8ff3ac79eb: shorten amdgpu's hdmi_frl_status_polling
  #      workqueue name ("name exceeds WQ_NAME_LEN" warning; the iGPU's
  #      amdgpu driver loads on this machine too)
  boot.kernelPackages =
    let
      base = pkgs.linuxPackages_cachyos;
      zen4 = base.cachyOverride {
        cachyVars = base.kernel.cachyConfig.cachyVars // { "_processor_opt" = "ZEN4"; };
      };
    in
    (zen4.extend (final: prev: {
      kernel = prev.kernel.override (old: {
        configfile = old.configfile.overrideAttrs (oldAttrs: {
          postFixup = (oldAttrs.postFixup or "") + ''
            substituteInPlace $out --replace-fail \
              'CONFIG_MODULE_SIG_ALL=y' \
              '# CONFIG_MODULE_SIG_ALL is not set'
          '';
        });
        kernelPatches = (old.kernelPatches or [ ]) ++ map (name: {
          inherit name;
          patch = (site.kernelPatches.desktop or ./kernel-patches) + "/${name}";
        }) (builtins.attrNames (builtins.readDir ./kernel-patches));
      });
    })).extend (final: prev: {
      # Out-of-tree module builds (nvidia-open here) strip their .ko files
      # with `kernelModuleMakeFlags`, which has plain GNU strip; this kernel
      # is built with clang/lld (LTO) and GNU strip chokes on
      # nvidia-modeset.ko's LLVM section groups. Use llvm-strip from the same
      # toolchain as the NM= flag chaotic-nyx already sets.
      kernelModuleMakeFlags =
        let
          nmFlag = builtins.head (
            builtins.filter (f: pkgs.lib.hasPrefix "NM=" f) prev.kernelModuleMakeFlags
          );
          llvmBinDir = pkgs.lib.removeSuffix "llvm-nm" (pkgs.lib.removePrefix "NM=" nmFlag);
        in
        prev.kernelModuleMakeFlags ++ [ "STRIP=${llvmBinDir}llvm-strip" ];
    });
}
