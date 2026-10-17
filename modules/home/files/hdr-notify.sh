# Watch niri's log for the HDR fork switching an output's HDR signalling,
# and tell the user. niri logs this only after the connector colour state
# was accepted, so it reflects the display actually changing mode.
journalctl --user -f -n 0 -o cat -u niri.service \
  | sed -u "s/\x1b\[[0-9;]*m//g" \
  | while IFS= read -r line; do
  case "$line" in
    *"updated HDR signalling"*) ;;
    *) continue ;;
  esac
  out=$(printf '%s' "$line" | grep -o 'connector="[^"]*"' | cut -d'"' -f2)
  case "$line" in
    *"hdr=true"*)
      echo "HDR on: ${out:-?}"
      notify-send -a "Display" -i video-display "HDR on" "${out:-Display} switched to HDR (BT.2020, PQ)" \
        || echo "notify-send failed" ;;
    *"hdr=false"*)
      echo "HDR off: ${out:-?}"
      notify-send -a "Display" -i video-display "HDR off" "${out:-Display} is back to SDR" \
        || echo "notify-send failed" ;;
  esac
done
