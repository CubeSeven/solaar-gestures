#!/usr/bin/env bash
# uninstall.sh — put the machine back the way it was.
#
#   1. restores the most recent ~/.config/solaar/rules.yaml backup
#   2. removes ~/.local/bin/mouse-action, ~/.local/bin/mouse-doctor
#   3. removes ~/.config/mouse-gestures
#   4. resets the gsettings keys install.sh touched
#   5. restarts Solaar

set -eu

BIN_DIR="$HOME/.local/bin"
RULES="$HOME/.config/solaar/rules.yaml"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mouse-gestures"
KB=org.gnome.shell.keybindings
WM=org.gnome.desktop.wm.keybindings

say() { printf '%s\n' "$*"; }

say "solaar-gestures uninstaller"
say "---------------------------"

# ------------------------------------------------------------------ gsettings --
for key in toggle-overview; do
    gsettings reset "$KB" "$key" 2>/dev/null && say "  reset $key"
done
for key in show-desktop switch-to-workspace-left switch-to-workspace-right; do
    gsettings reset "$WM" "$key" 2>/dev/null && say "  reset $key"
done

# ---------------------------------------------------------------------- files --
rm -f "$BIN_DIR/mouse-action" "$BIN_DIR/mouse-doctor" && say "  removed helper scripts"
rm -rf "$CONF_DIR" && say "  removed $CONF_DIR"

# ---------------------------------------------------------------------- rules --
latest=$(ls -1t "$RULES".pre-gestures-*.bak 2>/dev/null | head -1 || true)
if [ -n "$latest" ]; then
    cp "$latest" "$RULES"
    say "  restored rules from $latest"
else
    rm -f "$RULES"
    say "  no backup found — removed $RULES (buttons revert to normal clicks)"
fi

# -------------------------------------------------------------------- restart --
pkill -x solaar 2>/dev/null || true
sleep 1
( setsid solaar --window=hide >/dev/null 2>&1 & ) || true
sleep 3
pgrep -x solaar >/dev/null && say "  solaar restarted"

say ""
say "done. Buttons are back to plain clicks; desktop keybindings back to defaults."
say "Diversion is device-side: if the buttons feel dead, set 'Regular' in Solaar → Key/Button Diversion."
