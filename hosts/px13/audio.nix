{ pkgs, ... }:
# TI TAS2783 SoundWire speaker amps + RT721 jack codec.
let
  # UCM "Speaker" device for the TI TAS2783 SoundWire smart amps.  Upstream
  # alsa-ucm-conf has no tas2783 codec profile, so without this PipeWire only
  # ever sees the rt721 jack codec and no internal-speaker sink exists in the
  # HiFi profile.  PCM device 2 is the SmartAmp playback device exposed by
  # the machine driver.  (From github.com/brainchillz/asus-proart-px13-
  # linux-speaker-fix, adapted to alsa-ucm-conf 1.2.16.x Syntax 8.)
  tas2783-ucm = pkgs.writeText "tas2783-ucm.conf" ''
    SectionDevice."Speaker" {
    	Comment "Speaker"

    	Value {
    		PlaybackPriority 100
    		PlaybackPCM "hw:''${CardId},2"
    		PlaybackChannels 2
    	}
    }
  '';

  # ALSA UCM tree for the amd-soundwire card: nixpkgs' alsa-ucm-conf plus
  # the pieces upstream doesn't have yet for this laptop's TAS2783 amps
  # (checked against 1.2.16.1 on 2026-09-27 - no tas2783.conf, and rt721.conf
  # still sets the missing Headphone Switch). Without them there is no
  # Speaker sink at all. Three changes on top of upstream:
  #  1. sof-soundwire/tas2783.conf: adds the "Speaker" device (above).
  #  2. rt721.conf: drop the "Headphone Switch" csets - this codec/driver
  #     exposes no such control, and the HiFi verb's disdevall sequence
  #     fails on the missing control, killing verb activation entirely
  #     (PipeWire then falls back to stereo-fallback with no audible sound).
  #  3. Card conf for this machine's longname: force SpeakerCodec1=tas2783,
  #     since the components string has no " spk:" token so the generic
  #     profile never creates a Speaker device.
  px13-ucm2 = pkgs.runCommand "px13-alsa-ucm2" {} ''
    cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 $out
    chmod -R u+w $out

    install -m644 ${tas2783-ucm} $out/sof-soundwire/tas2783.conf

    sed -i "/cset \"name='Headphone Switch' on\"/d; /cset \"name='Headphone Switch' off\"/d" \
      $out/sof-soundwire/rt721.conf
    if grep -q "Headphone Switch" $out/sof-soundwire/rt721.conf; then
      echo "ERROR: rt721.conf still references Headphone Switch" >&2
      exit 1
    fi

    # Layout assertion: the injection point below only exists in the
    # Syntax 8 (>= 1.2.16) sof-soundwire.conf.  Fail the build loudly if a
    # future version restructures it rather than silently losing speakers.
    grep -q "^If.codec_default.Append.Define {" $out/sof-soundwire/sof-soundwire.conf

    mkdir -p $out/conf.d/amd-soundwire
    sed -e '/^If.codec_default.Append.Define {/i # PX13: CardComponents has no " spk:" token; force the TAS2783 Speaker device.' \
        -e '/^If.codec_default.Append.Define {/i Define.SpeakerCodec1 "tas2783"' \
      $out/sof-soundwire/sof-soundwire.conf \
      > "$out/conf.d/amd-soundwire/ASUSTeKCOMPUTERINC.-ProArtPX13HN7306EAC-1.0-HN7306EAC.conf"
  '';

in
{
  services.pipewire = {
    # The patched UCM tree (px13-ucm2) gives the SoundWire card its HiFi
    # profile: Speaker + Headphones sinks, headset mic + internal DMIC.

    # Plain device names everywhere (volume OSD, Noctalia, app mixers)
    # instead of ALSA's "Audio Coprocessor Speaker" etc.
    wireplumber.extraConfig."51-px13-device-names" = {
      "monitor.alsa.rules" = let
        rename = pattern: name: {
          matches = [ { "node.name" = "~${pattern}"; } ];
          actions.update-props = { "node.description" = name; "node.nick" = name; };
        };
      in [
        (rename "alsa_output.*amd_sdw.*Speaker.*" "Speakers")
        (rename "alsa_output.*amd_sdw.*Headphones.*" "Headphones")
        (rename "alsa_input.*amd_sdw.*Mic__source" "Built-in Microphone")
        (rename "alsa_input.*amd_sdw.*Headset.*" "Headset Microphone")
      ];
    };

    # LDAC at its fixed 990 kbps instead of "auto" (adaptive, can drop to
    # 330 kbps). Can stutter at range; set back to "auto" if it does.
    wireplumber.extraConfig."52-bluez-ldac-hq" = {
      "monitor.bluez.properties" = {
        "bluez5.a2dp.ldac.quality" = "hq";
      };
    };

    # Let the graph run at 44.1 kHz too, so 44.1 kHz FLAC (the TIDAL/Navidrome
    # library) plays without being resampled to 48 kHz.
    extraConfig.pipewire."92-sample-rates" = {
      "context.properties" = {
        "default.clock.allowed-rates" = [ 44100 48000 ];
      };
    };
  };

  # Point alsa-lib (inside PipeWire/WirePlumber and in CLI tools like
  # alsaucm/aplay) at the patched UCM tree instead of its baked-in copy.
  # DefaultEnvironment covers systemd user units (pipewire, wireplumber);
  # sessionVariables covers login shells.
  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${px13-ucm2}";
  systemd.user.settings.Manager.DefaultEnvironment = "ALSA_CONFIG_UCM2=${px13-ucm2}";
}
