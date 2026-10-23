# Themes

*System → Launcher settings → Theme* changes the launcher's colours. The
values are a list; moving along it repaints the panel at once, so the list
itself is the preview. The choice is saved with the other settings and kept
by updates.

There are eight: **Default**, the launcher's original grey look, and seven
two-colour themes, three on a dark base and four on a light one. (Meadow,
Sky and Violet were taken out in 0.14.0; a TV that had one of them saved
falls back to Default.)

## What the two colours do

Every theme other than Default is an **accent** and a **base**:

| | Where it shows |
| :--- | :--- |
| **Accent** | The focused tile's ring; the focused HDMI pill and System tile, filled; the dot in the clock bar; the glow in the bottom-left corner while an input, *Apps* or *System* is focused (an app keeps its own glow colour); the scroll bar in *Apps*; the focused row in the settings menu |
| **Base** | The tiles, the HDMI pills, the System tiles and the settings menu. On a light base they are light with dark text |
| **Shade** | Not chosen: always dark, a near-black of the base, under the name and the rail and behind the clock bar. The big name, the hints and the version over it stay white or light grey in every theme |

Text on the accent is white, or near-black when the accent is a light colour
(Lime, Lagoon, Midnight). Warnings and the favourite you are moving use
amber in every theme.

The pictures below are the real panel, drawn on a computer with an HDMI input
focused (see [Development](development.md#theme-pictures)). The app icons are
stand-ins.

| Theme | Colours | Accent | Base |
| :--- | :---: | :--- | :--- |
| [Default](#default) | <img src="themes/default-colors.svg" width="56" alt="Default: focused #F2F3F5, tiles #26282E"> | `#F2F3F5` | `#26282E` |
| [Lime](#lime) | <img src="themes/lime-colors.svg" width="56" alt="Lime: accent #B6FF2E, base #1F2329"> | `#B6FF2E` | `#1F2329` |
| [Lagoon](#lagoon) | <img src="themes/lagoon-colors.svg" width="56" alt="Lagoon: accent #D6FFCB, base #042F32"> | `#D6FFCB` | `#042F32` |
| [Midnight](#midnight) | <img src="themes/midnight-colors.svg" width="56" alt="Midnight: accent #D7FFE0, base #050505"> | `#D7FFE0` | `#050505` |
| [Terracotta](#terracotta) | <img src="themes/terracotta-colors.svg" width="56" alt="Terracotta: accent #E26F4A, base #FFFCF4"> | `#E26F4A` | `#FFFCF4` |
| [Cherry](#cherry) | <img src="themes/cherry-colors.svg" width="56" alt="Cherry: accent #FF173D, base #F9DEDF"> | `#FF173D` | `#F9DEDF` |
| [Cobalt](#cobalt) | <img src="themes/cobalt-colors.svg" width="56" alt="Cobalt: accent #1D61F3, base #F1F4F9"> | `#1D61F3` | `#F1F4F9` |
| [Indigo](#indigo) | <img src="themes/indigo-colors.svg" width="56" alt="Indigo: accent #263BAA, base #FFF4D6"> | `#263BAA` | `#FFF4D6` |

## Default

The original look: grey tiles and pills, white focus, a neutral blue-grey glow.
Its accent and base above are the focused and the plain tile colours; Default
is spelled out colour by colour rather than made from two.

<img src="themes/default.png" width="100%" alt="Default theme: grey tiles, white focused HDMI 2 pill">

## Dark themes

Tiles in the base colour (Midnight's near-black base is lifted to a dark grey so
the tiles stand out from the shade), light text on them, the accent on what is
focused.

### Lime

<img src="themes/lime-colors.svg" width="56" alt=""> Accent `#B6FF2E` on graphite `#1F2329`.

<img src="themes/lime.png" width="100%" alt="Lime theme: graphite tiles, lime focused HDMI 2 pill">

### Lagoon

<img src="themes/lagoon-colors.svg" width="56" alt=""> Accent `#D6FFCB` on deep teal `#042F32`.

<img src="themes/lagoon.png" width="100%" alt="Lagoon theme: deep teal tiles, pale green focused HDMI 2 pill">

### Midnight

<img src="themes/midnight-colors.svg" width="56" alt=""> Accent `#D7FFE0` on black `#050505`.

<img src="themes/midnight.png" width="100%" alt="Midnight theme: near-black tiles, pale mint focused HDMI 2 pill">

## Light themes

Light tiles and pills with dark text and icons, over the same dark shade as the
dark themes, so the name and the hints stay white over any picture.

### Terracotta

<img src="themes/terracotta-colors.svg" width="56" alt=""> Accent `#E26F4A` on cream `#FFFCF4`.

<img src="themes/terracotta.png" width="100%" alt="Terracotta theme: cream tiles, terracotta focused HDMI 2 pill">

### Cherry

<img src="themes/cherry-colors.svg" width="56" alt=""> Accent `#FF173D` on blush `#F9DEDF`.

<img src="themes/cherry.png" width="100%" alt="Cherry theme: blush tiles, red focused HDMI 2 pill">

### Cobalt

<img src="themes/cobalt-colors.svg" width="56" alt=""> Accent `#1D61F3` on cool grey `#F1F4F9`.

<img src="themes/cobalt.png" width="100%" alt="Cobalt theme: light grey tiles, blue focused HDMI 2 pill">

### Indigo

<img src="themes/indigo-colors.svg" width="56" alt=""> Accent `#263BAA` on parchment `#FFF4D6`.

<img src="themes/indigo.png" width="100%" alt="Indigo theme: parchment tiles, indigo focused HDMI 2 pill">

## Adding a theme

See [Development → Adding a theme](development.md#adding-a-theme).
