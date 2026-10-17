# desktop-botanical: GMK Botanical greens (Pantone 5477 C / 5575 C).
# primary / secondary are the wallpaper's major / minor contour lines.
{
  slug = "desktop-botanical";
  gnomeAccent = "green";

  primary = "#92ACA0";
  onPrimary = "#0A1210";
  secondary = "#3E5D58";
  onSecondary = "#E8F0EC";
  tertiary = "#68857C"; # midpoint of the two line colours
  onTertiary = "#0A1210";
  error = "#C1666B";
  onError = "#0A1210";
  surface = "#0A0F0D"; # near-black with a sage cast
  onSurface = "#CBD9D2";
  surfaceVariant = "#151F1B";
  onSurfaceVariant = "#9DB3AB";
  outline = "#3E5D58";
  shadow = "#000000";
  hover = "#1E2E28";
  onHover = "#E8F0EC";
  success = "#7FA37A";

  ansi = {
    black = "#101A16";
    red = "#C1666B";
    green = "#3E5D58"; # the minor line colour doubles as ANSI green
    yellow = "#C9A46A";
    blue = "#6E8CA8"; # this palette's hues are green, so blue gets its own
    magenta = "#8C7AA6";
    cyan = "#92ACA0"; # the major line colour doubles as ANSI cyan
    white = "#CBD9D2";
  };
  ansiBright = {
    black = "#4C5650";
    red = "#D98A8E";
    green = "#6FA08F";
    yellow = "#E0C08A";
    blue = "#8FB2C9";
    magenta = "#AA9BC2";
    cyan = "#B7D4C6";
    white = "#E8F0EC";
  };
}
