#!/bin/bash

set -ouex pipefail

### Build accountsservice with systemd-homed support

dnf5 install -y meson gcc glib2-devel polkit-devel systemd-devel \
    gobject-introspection-devel gtk-doc git vala python3-dbusmock \
    libxcrypt-devel gettext

git clone --depth 1 --branch 26.12.8 \
    https://gitlab.freedesktop.org/accountsservice/accountsservice.git /tmp/accountsservice-build

cd /tmp/accountsservice-build
meson setup build -Dcreate_homed=true -Dgtk_doc=true -Dadmin_group=wheel
meson compile -C build
meson install -C build
cd /
rm -rf /tmp/accountsservice-build

# Configure gnome-initial-setup vendor config
mkdir -p /usr/share/gnome-initial-setup
cp /ctx/arcos-oobe-vendor.conf /usr/share/gnome-initial-setup/vendor.conf

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Install GNOME desktop
dnf5 install -y \
    "@gnome-desktop" \
    gnome-session-wayland-session \
    gnome-initial-setup

# Set GNOME as default session
systemctl set-default graphical.target
systemctl enable gdm

# Configure GDM to launch initial-setup when no users exist
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf << 'EOF'
[daemon]
InitialSetupEnable=true

[security]

[xdmcp]

[greeter]

[chooser]

[debug]
EOF

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

# Configure systemd-homed: LUKS encryption with btrfs inside each user home
mkdir -p /etc/systemd
cat > /etc/systemd/homed.conf << 'EOF'
[Home]
DefaultStorage=luks
DefaultFileSystemType=btrfs
EOF

#### Example for enabling a System Unit File

