# gravey.omacolors

Omarchy Quickshell bar widget: a split preview + saturation/brightness field, hue bar, **8-slot history**, screen **eyedropper**, and copyable **HEX / RGB / CMYK / HSV / HSL** values.

## Install

Plugins run as unsandboxed code inside `omarchy-shell`. Only add repos you trust.

From this checkout (needs at least one git commit):

```bash
omarchy plugin add "$(pwd)" --enable --yes
```

Or symlink while hacking:

```bash
ln -sfn "$(pwd)" ~/.config/omarchy/plugins/gravey.omacolors
omarchy-shell shell rescanPlugins
omarchy plugin enable gravey.omacolors --section right --yes
```

That lands in `~/.config/omarchy/plugins/gravey.omacolors/` and places the swatch on the right side of the bar.

## Use

- **Click** the bar swatch to open the picker
- Drag the **square** for saturation and brightness
- Drag the **hue bar** for the base color
- Click the **eyedropper** (or press **e**) to pick any pixel on screen via `hyprpicker` — the color is applied and saved to history
- System **Super+Print** / Capture → Color also saves into this history
- Click **Save** (or press **s**) to store the current color in history
- Click a filled history slot to load it; click an empty slot to save there; **right-click** a slot to clear it
- Click a value capsule to copy it
- **Enter** copies HEX and closes
- **Esc** or click outside closes without an extra copy

The last color and 8 history slots are stored in `~/.local/state/omarchy/omacolors-palette.json`.

## Layout

```text
manifest.json    Omarchy plugin manifest (must live at repo root)
BarWidget.qml    Bar swatch
Panel.qml        Wheel, slider, palette, format rows
Wheel.qml        HSV wheel + brightness slider
ColorModel.js    Hex / RGB / HSV / HSL and palette helpers
tests/run.js     Node tests for ColorModel.js
```

The repo root **is** the plugin. That is what `omarchy plugin add` and `omarchy plugin validate` expect.

## Scripting

```bash
omarchy-shell gravey.omacolors toggle
omarchy-shell gravey.omacolors open
omarchy-shell gravey.omacolors close
```

## Tests

```bash
node tests/run.js
omarchy plugin validate "$(pwd)"
```

## Requirements

- [Omarchy](https://omarchy.org/) with the Quickshell desktop
- `wl-copy` for clipboard (ships with Omarchy)
- `hyprpicker` for the screen eyedropper (ships with Omarchy)

## License

MIT. See [LICENSE](LICENSE).
