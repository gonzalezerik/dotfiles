# Mod+p: picture-in-picture for Jellium Desktop (the Jellyfin client).
#
# Tiled -> move it to the workspace you're on, float it as a small 16:9
# window in the bottom-right corner and hand focus back to what you were
# using. The float-above-fullscreen window rule (niri patch 08) keeps it
# visible over fullscreen windows, games included.
# Floating -> back into the tiling layout, focused.

app=net.nullsum.JelliumDesktop
w=1024 # logical px = 1280x720 at scale 1.25
h=576
margin=32

window() {
  niri msg -j windows | jq -c --arg app "$app" 'map(select(.app_id == $app)) | first // empty'
}

win=$(window)
[ -n "$win" ] || exit 0
id=$(jq -r .id <<<"$win")

if [ "$(jq -r .is_floating <<<"$win")" = true ]; then
  niri msg action move-window-to-tiling --id "$id"
  niri msg action focus-window --id "$id"
  exit 0
fi

prev=$(niri msg -j focused-window | jq -r '.id // empty')
ws=$(niri msg -j workspaces | jq -r 'map(select(.is_focused)) | first | .idx')

niri msg action move-window-to-workspace --window-id "$id" --focus false "$ws"
niri msg action move-window-to-floating --id "$id"
niri msg action set-window-width --id "$id" "$w"
niri msg action set-window-height --id "$id" "$h"

# niri doesn't expose the working area (output minus the bar's exclusive
# zone) over IPC, so park the window at its top-left corner and read it back.
niri msg action move-floating-window --id "$id" -x 0 -y 0
read -r x0 y0 < <(window | jq -r '.layout.tile_pos_in_workspace_view | map(floor) | @tsv')
read -r ow oh < <(niri msg -j focused-output | jq -r '.logical | [.width, .height] | @tsv')
niri msg action move-floating-window --id "$id" \
  -x $((ow - x0 - w - margin)) -y $((oh - y0 - h - margin))

if [ -n "$prev" ] && [ "$prev" != "$id" ]; then
  niri msg action focus-window --id "$prev"
else
  niri msg action focus-tiling
fi
