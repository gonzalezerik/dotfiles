{ pkgs, lib, osConfig, ... }:

# mpv as the all-round video/audio player (VLC replacement).
#
# nixpkgs mpv: libplacebo, FFmpeg, libbluray, libcdio and yt-dlp come with
# its build; uosc, thumbfast, mpris and sponsorblock are nixpkgs'
# mpvScripts (the wrapper also hands uosc its fonts).
#
# HDR / Dolby Vision: gpu-next renders through libplacebo, which applies the
# Dolby Vision RPU itself (profile 5 IPTPQc2 reshaping, profile 8.x dynamic
# metadata; profile 7 plays its base layer + RPU, the FEL is ignored). With
# target-colorspace-hint mpv tags its Wayland surface with the video's real
# colour space; the niri HDR fork (hdr mode="auto") switches the
# panel to PQ/BT.2020 while an HDR video is fullscreen, and mpv tone-maps to
# SDR itself in a window.
let
  t = osConfig.dotfiles.theme;
  nvidia = osConfig.dotfiles.gpu == "nvidia";
  mpvConf = pkgs.writeText "mpv.conf" ''
    # ── Video ──────────────────────────────────────────────────────────────
    # libplacebo's high-quality preset (ewa_lanczossharp, spline36 chroma,
    # debanding, HDR peak detection).
    profile=high-quality
    vo=gpu-next
    gpu-api=vulkan
    # Hardware decode (VA-API on AMD, NVDEC on NVIDIA); Vulkan interop keeps
    # frames on the GPU. Software decode for anything else.
    hwdec=${if nvidia then "auto-safe" else "vaapi"}
    video-sync=display-resample

    # ── HDR / Dolby Vision ─────────────────────────────────────────────────
    # Follow the compositor's preferred image description: PQ when niri puts
    # the panel in HDR (fullscreen), otherwise the SDR output, which mpv then
    # tone-maps to itself.
    target-colorspace-hint=yes
    tone-mapping=auto
    gamut-mapping-mode=auto
    hdr-compute-peak=yes
    # Keep subtitles in the video's colour space so they aren't blown out
    # at PQ white on HDR output.
    blend-subtitles=no

    # ── Window / UI (uosc) ─────────────────────────────────────────────────
    osc=no
    osd-bar=no
    border=no
    keep-open=yes
    autofit-larger=90%x90%
    # Opening one file queues the rest of its folder, like VLC.
    autocreate-playlist=same
    directory-mode=lazy

    # ── Resume ─────────────────────────────────────────────────────────────
    save-position-on-quit=yes
    watch-later-options=start,vid,aid,sid,volume,mute,sub-delay,audio-delay

    # ── Audio ──────────────────────────────────────────────────────────────
    volume=100
    volume-max=150
    alang=en,eng,ja,jpn

    # ── Subtitles ──────────────────────────────────────────────────────────
    slang=en,eng
    sub-auto=fuzzy
    subs-with-matching-audio=forced

    # ── Streams / network ──────────────────────────────────────────────────
    ytdl-format=bestvideo[height<=?2160]+bestaudio/best
    cache=yes
    demuxer-max-bytes=1GiB
    demuxer-max-back-bytes=256MiB

    # ── Screenshots ────────────────────────────────────────────────────────
    screenshot-dir=~/Pictures/mpv
    screenshot-format=png
    screenshot-tag-colorspace=yes
    screenshot-high-bit-depth=yes
  '';

  inputConf = pkgs.writeText "input.conf" ''
    # uosc menus; everything else is mpv's default key map.
    mbtn_right  script-binding uosc/menu
    menu        script-binding uosc/menu
    o           script-binding uosc/open-file
    s           script-binding uosc/subtitles
    a           script-binding uosc/audio
    p           script-binding uosc/items
    c           script-binding uosc/chapters
    S           screenshot
  '';

  uoscConf = pkgs.writeText "uosc.conf" ''
    # palette accent
    color=foreground=${lib.removePrefix "#" t.primary},foreground_text=${lib.removePrefix "#" t.surface}
  '';

  thumbfastConf = pkgs.writeText "thumbfast.conf" ''
    hwdec=yes
    network=yes
  '';

  # Flathub io.mpv.Mpv.desktop's MimeType list (wider than mpv.desktop's).
  mpvMimeTypes = [
      "application/ogg" "application/x-ogg" "application/mxf" "application/sdp" "application/smil"
      "application/x-smil" "application/streamingmedia" "application/x-streamingmedia"
      "application/vnd.rn-realmedia" "application/vnd.rn-realmedia-vbr" "audio/aac" "audio/x-aac"
      "audio/vnd.dolby.heaac.1" "audio/vnd.dolby.heaac.2" "audio/aiff" "audio/x-aiff" "audio/m4a"
      "audio/x-m4a" "application/x-extension-m4a" "audio/mp1" "audio/x-mp1" "audio/mp2" "audio/x-mp2"
      "audio/mp3" "audio/x-mp3" "audio/mpeg" "audio/mpeg2" "audio/mpeg3" "audio/mpegurl"
      "audio/x-mpegurl" "audio/mpg" "audio/x-mpg" "audio/rn-mpeg" "audio/musepack" "audio/x-musepack"
      "audio/ogg" "audio/scpls" "audio/x-scpls" "audio/vnd.rn-realaudio" "audio/wav" "audio/x-pn-wav"
      "audio/x-pn-windows-pcm" "audio/x-realaudio" "audio/x-pn-realaudio" "audio/x-ms-wma"
      "audio/x-pls" "audio/x-wav" "video/mpeg" "video/x-mpeg2" "video/x-mpeg3" "video/mp4v-es"
      "video/x-m4v" "video/mp4" "application/x-extension-mp4" "video/divx" "video/vnd.divx"
      "video/msvideo" "video/x-msvideo" "video/ogg" "video/quicktime" "video/vnd.rn-realvideo"
      "video/x-ms-afs" "video/x-ms-asf" "audio/x-ms-asf" "application/vnd.ms-asf" "video/x-ms-wmv"
      "video/x-ms-wmx" "video/x-ms-wvxvideo" "video/x-avi" "video/avi" "video/x-flic" "video/fli"
      "video/x-flc" "video/flv" "video/x-flv" "video/x-theora" "video/x-theora+ogg"
      "video/x-matroska" "video/mkv" "audio/x-matroska" "application/x-matroska" "video/webm"
      "audio/webm" "audio/vorbis" "audio/x-vorbis" "audio/x-vorbis+ogg" "video/x-ogm"
      "video/x-ogm+ogg" "application/x-ogm" "application/x-ogm-audio" "application/x-ogm-video"
      "application/x-shorten" "audio/x-shorten" "audio/x-ape" "audio/x-wavpack" "audio/x-tta"
      "audio/AMR" "audio/ac3" "audio/eac3" "audio/amr-wb" "video/mp2t" "audio/flac" "audio/mp4"
      "application/x-mpegurl" "video/vnd.mpegurl" "application/vnd.apple.mpegurl" "audio/x-pn-au"
      "video/3gp" "video/3gpp" "video/3gpp2" "audio/3gpp" "audio/3gpp2" "video/dv" "audio/dv"
      "audio/opus" "audio/vnd.dts" "audio/vnd.dts.hd" "audio/x-adpcm" "application/x-cue" "audio/m3u"
      "audio/vnd.wave" "video/vnd.avi"
  ];
in
{
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [ uosc thumbfast mpris sponsorblock ];
  };

  xdg.configFile = {
    "mpv/mpv.conf".source = mpvConf;
    "mpv/input.conf".source = inputConf;
    "mpv/script-opts/uosc.conf".source = uoscConf;
    "mpv/script-opts/thumbfast.conf".source = thumbfastConf;
  };

  # nixpkgs' mpv.desktop, with the full MimeType list above.
  xdg.desktopEntries.mpv = {
    name = "mpv Media Player";
    genericName = "Multimedia player";
    icon = "mpv";
    exec = "mpv --player-operation-mode=pseudo-gui -- %U";
    categories = [ "AudioVideo" "Audio" "Video" "Player" "TV" ];
    mimeType = mpvMimeTypes;
  };

  xdg.mimeApps.defaultApplications =
    builtins.listToAttrs (map (m: { name = m; value = [ "mpv.desktop" ]; }) mpvMimeTypes);
}
