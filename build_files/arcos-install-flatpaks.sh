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

set -uo pipefail

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

echo "arcos-flatpaks: installing ${#APPS[@]} default Flatpak applications..."

# Ensure the Flathub remote is configured, retrying for a while in case
# network isn't up yet at boot (e.g. WiFi still connecting).
remote_ok=0
for _ in $(seq 1 12); do
    if flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo; then
        remote_ok=1
        break
    fi
    echo "arcos-flatpaks: waiting for network to reach Flathub..."
    sleep 10
done
if [[ "$remote_ok" -ne 1 ]]; then
    echo "arcos-flatpaks: could not configure Flathub remote; will retry later." >&2
    exit 0
fi

# Install each app on its own so a single transient failure can't abort the
# whole set. Already-installed apps are a fast no-op, so retries are cheap.
failed=0
for app in "${APPS[@]}"; do
    if ! flatpak install -y --noninteractive --system flathub "$app"; then
        echo "arcos-flatpaks: WARNING - failed to install $app" >&2
        failed=1
    fi
done

# Record success only after a clean full install, so a partial run retries on
# the next timer tick. Always exit 0 so the unit never shows as "failed" (the
# marker absence drives the retry, not the service exit code).
if [[ "$failed" -eq 0 ]]; then
    printf '%s\n' "$DESIRED" > "$MARKER"
    echo "arcos-flatpaks: all default apps installed."
else
    echo "arcos-flatpaks: some apps failed; will retry on the next timer tick." >&2
fi

exit 0
