#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Install GNOME desktop
dnf5 install -y \
    "@gnome-desktop" \
    gnome-session-wayland-session

# Set GNOME as default session
systemctl set-default graphical.target
systemctl enable gdm

# Add Flathub remote
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install GNOME apps from Flathub
flatpak install -y flathub \
    org.gnome.Lollypop \
    org.gnome.Calculator \
    org.gnome.Calendar \
    org.gnome.clocks \
    org.gnome.Contacts \
    org.gnome.SimpleScan \
    org.gnome.Evince \
    org.gnome.Nautilus \
    org.gnome.eog \
    org.gnome.Maps \
    org.gnome.gedit \
    org.gnome.Weather \
    org.gnome.Epiphany \
    org.gnome.World.PikaBackup

# Enable systemd-homed
systemctl enable systemd-homed.service
systemctl enable systemd-homed-activate.service

#### Example for enabling a System Unit File

