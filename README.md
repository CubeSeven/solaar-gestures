# solaar-gestures

Turn the extra buttons on a Logitech mouse into real desktop actions on **GNOME Wayland** — overview, workspaces, show desktop — using [Solaar](https://github.com/pwr-Solaar/Solaar) plus a small wrapper that does the two things Solaar alone can't.

Ships with MX Master 4 defaults; works with any mouse Solaar can divert.

```
gesture tap         → overview
gesture swipe ←/→   → previous / next workspace
gesture swipe ↑/↓   → overview / show desktop
second button tap   → app launcher (vicinae, if installed)
```

## Why this exists

Solaar can divert a Logitech button and run a command when you gesture with it. Two things then break, and both look like "the mouse is dead":

1. **Every physical press is emitted twice.** The mouse sends two press/release pairs ~300–450 ms apart for a single tap. Any toggle action (overview, show desktop) opens and instantly closes. Solaar logs a clean `Execute` every time, so nothing looks wrong. Fix: a 600 ms debounce in `mouse-action`.
2. **Injected key combos do not always arrive.** `Ctrl+Alt+O` may be swallowed by a remapper in the input stack (keyd, a second layout changing letter keysyms, …). The action fires, the desktop does nothing, and you have no way to tell which layer failed. Fix: `mouse-doctor` *measures* which combos work on your machine instead of assuming.

## Requirements

- GNOME on **Wayland** (tested on GNOME Shell 51)
- `solaar` — sees the mouse and diverts the button
- `ydotool` + `ydotoold` running — `systemctl --user enable --now ydotool.service`
- `python3` not required; everything is bash + coreutils

KDE Plasma support: not included. The previous KDE profile used `qdbus org.kde.kglobalaccel … invokeShortcut`, which is a separate backend.

## Install

```bash
git clone https://github.com/<you>/solaar-gestures
cd solaar-gestures
./install.sh            # asks before writing anything
```

`install.sh` backs up `~/.config/solaar/rules.yaml`, installs `mouse-action` and `mouse-doctor` into `~/.local/bin`, writes the rules for the buttons it detects, runs the doctor, restarts Solaar, and verifies the buttons are still diverted.

Flags: `--yes` (no prompt), `--no-doctor`, `--mods "Shift+Alt"`, `--gesture "Mouse Gesture Button"`, `--haptic "Haptic"`, `--no-haptic`.

Then one manual step, because diversion is device-side and Solaar's CLI cannot arm gestures:

> Open Solaar → your mouse → **Key/Button Diversion** → set the gesture button to **Mouse Gestures**.

Test with your hands: one tap per action (a double tap is a double action).

## How mouse-doctor decides

It never guesses a keybinding. It temporarily binds `org.gnome.shell.keybindings screenshot` to a candidate combo, injects that combo through `ydotool`, and counts new files in `~/Pictures/Screenshots`:

```
probing modifier sets:
  [ok]   Shift+Alt
  [fail] Ctrl+Alt
  [fail] Ctrl
```

First working set wins, then each action combo (`Home`, `End`, `Left`, `Right`) is verified the same way. Only verified combos are written into `~/.config/mouse-gestures/keymap.conf` and into gsettings. Probe screenshots are moved out of `~/Pictures/Screenshots` on exit, the screenshot binding and the screen-reader shortcut are restored.

```bash
mouse-doctor --dry-run            # measure and print, change nothing
mouse-doctor --mods "Shift+Alt"   # skip probing
```

## The keymap

`~/.config/mouse-gestures/keymap.conf`:

```ini
# action = <Modifiers>+<Key>   |   action = cmd:<shell command>
overview  = Shift+Alt+Home
showdesk  = Shift+Alt+End
ws_prev   = Shift+Alt+Left
ws_next   = Shift+Alt+Right
appgrid   = cmd:vicinae toggle
hermes    = cmd:hermes desktop
```

Supported modifier names: `Shift`, `Alt`, `Ctrl`, `Super`. Supported keys: arrows, `Home`, `End`, `Page_Up`, `Page_Down`, `Insert`, `Delete`, `Escape`, `Space`, `Print`, `F1`–`F12`.

**Letters are deliberately unsupported.** With a second keyboard layout installed (Greek, Cyrillic, …) the keysym for a letter changes with the active layout, so `Ctrl+Alt+D` silently stops matching in that window. Arrows and Home/End are layout-independent — that is why the defaults use them.

## Custom mapping

Edit `rules.yaml` (Solaar restarts to reload rules — it has no file watcher) and `keymap.conf` (reloaded per press). Gesture names Solaar understands: `Mouse Left`, `Mouse Right`, `Mouse Up`, `Mouse Down`, `Mouse Up Left`, and so on.

```yaml
%YAML 1.3
---
- MouseGesture: [Mouse Gesture Button, Mouse Down]
- Execute: ["/home/you/.local/bin/mouse-action", "showdesk"]
...
```

`Execute` runs argv directly — no shell, no `~` expansion. Use absolute paths.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Rules fire in `solaar -ddd` but nothing happens | combo swallowed before reaching the compositor | run `mouse-doctor` |
| Toggle actions flash open and close | device double-emission | `MOUSE_GESTURES_DEBOUNCE=1000 mouse-action overview` |
| Nothing fires at all | button not diverted | Solaar → Key/Button Diversion → `Mouse Gestures` |
| Gesture works after a restart only | diversion written but not armed | power-cycle the mouse, then restart Solaar |
| `failed to connect socket` | `ydotoold` down | `systemctl --user enable --now ydotool.service` |
| Screen reader starts talking during probing | injected `Alt+Super+S` | the doctor empties that shortcut while probing; if it happens manually: `gsettings set org.gnome.settings-daemon.plugins.media-keys screenreader "@as []"` |
| Unchanged keybinding has no effect | gsettings value is live-updated, but some components cache at start | log out and back in once after changing bindings |

Diagnostics that tell you which layer is broken:

```bash
solaar -ddd --window=hide > ~/solaar.log 2>&1   # then tap the button; look for 'mouse gesture notification' + 'Execute action'
ydotool key 115:1 115:0                          # volume up: proves injection reaches the compositor
mouse-doctor --dry-run                           # proves binding + injection per combo
```

## Tested on

- MX Master 4 (Bolt receiver, HID++ 4.5) — CachyOS, GNOME Shell 51.1, Wayland, Solaar 1.1.20
- Same setup previously working on KDE Plasma 6 via `qdbus6 invokeShortcut`

## Uninstall

```bash
./uninstall.sh
```

Restores the newest `rules.yaml.pre-gestures-*.bak`, removes the helpers and `~/.config/mouse-gestures`, resets the gsettings keys, restarts Solaar.

## License

MIT
