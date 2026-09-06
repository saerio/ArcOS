#!/bin/bash
# Install ArcOS default Flatpak applications on the live system.
#
# In a bootc/ostree image, only /usr is committed to the deployment; /var is
# runtime state and is NOT carried over from the container image. Flatpaks
# installed at container build time write to /var/lib/flatpak, so they are
# silently dropped on every bootc upgrade/switch (and never appear on fresh
# installs either). This script is run on boot by arcos-flatpaks.service so
# the default apps land in the host's persistent /var/lib/flatpak — appearing
# on both fresh installs and after bootc upgrades.
#
# It is idempotent: a marker file records the desired app set already
# installed, so normal boots skip without touching the network. When the app
# set changes (a new image release adds/removes an app), it re-runs once.

set -euo pipefail

APPS=(
    org.gnome.Showtime
    org.gnome.Calculator
    org.gnome.Calendar
    org.gnome.clocks
    org.gnome.Contacts
    org.gnome.SimpleScan
    org.gnome.Evince
    org.gnome.Loupe
    org.gnome.Maps
    org.gnome.TextEditor
    org.gnome.Weather
    app.zen_browser.zen
    net.nokyan.Resources
    org.gnome.World.PikaBackup
)

MARKER="/var/lib/arcos/flatpaks-installed"
mkdir -p "$(dirname "$MARKER")"

# Stable, sorted, space-separated fingerprint of the desired app set.
DESIRED="$(printf '%s\n' "${APPS[@]}" | sort | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

# Nothing to do if this exact app set was already installed.
if [[ -f "$MARKER" ]] && [[ "$(cat "$MARKER")" == "$DESIRED" ]]; then
    exit 0
fi

# Ensure the Flathub remote is configured (no-op if it already is).
flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

# Install (or refresh) the default apps system-wide.
flatpak install -y --system flathub "${APPS[@]}"

# Record success only after a clean install so a failed run retries next boot.
printf '%s\n' "$DESIRED" > "$MARKER"
