#!/bin/bash

set -ouex pipefail

### Build accountsservice with systemd-homed support

dnf5 install -y meson gcc glib2-devel polkit-devel systemd-devel \
    gobject-introspection-devel gtk-doc git vala python3-dbusmock \
    libxcrypt-devel gettext json-c-devel dbus-devel

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
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/44/x86_64/repoview/index.html&protocol=https&redirect=1

### Locale support
## The fedora-bootc base image is minimal and ships no locale data
## (glibc-minimal-langpack). Without locale definitions installed, every
## program that calls setlocale() fails with:
##   "setlocale: cannot change locale (xx_XX.UTF-8): No such file or directory"
## Install the full langpack set so whatever locale the user picks during
## OOBE / GNOME Settings actually resolves. en_US.UTF-8 is kept as the
## default fallback in /etc/locale.conf.
dnf5 install -y glibc-all-langpacks

cat > /etc/locale.conf << 'EOF'
LANG=en_US.UTF-8
EOF

# Install GNOME desktop — the desktop shell + infrastructure, plus the few
## GNOME apps we keep as RPMs (nautilus, gnome-software). All other GNOME
## apps come from Flatpak (see below), so exclude them. Also drop the
## terminal (ptyxis) and avahi (mDNS) which we don't want.
##
## Kept (desktop + infra): gnome-shell, gnome-session-wayland-session, gdm,
##   gnome-control-center, gnome-settings-daemon, polkit, dconf,
##   gnome-initial-setup, gvfs-* backends (also listed explicitly below),
##   gnome-bluetooth, gnome-backgrounds, fonts, thumbnailers, librsvg2.
## Kept (RPM apps): nautilus (Files), gnome-software.
## Excluded (apps): gnome-text-editor, yelp, baobab, decibels, gnome-boxes,
##   gnome-calculator, gnome-calendar, gnome-characters, gnome-clocks,
##   gnome-connections, gnome-contacts, gnome-disk-utility, gnome-font-viewer,
##   gnome-logs, gnome-maps, gnome-system-monitor, gnome-weather.
## Excluded (other): ptyxis (terminal — not wanted), avahi (mDNS — not wanted).
dnf5 install -y \
    "@gnome-desktop" \
    gnome-session-wayland-session \
    gnome-initial-setup \
    gvfs-afc gvfs-afp gvfs-archive gvfs-fuse gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-smb \
    --exclude=ptyxis \
    --exclude=avahi \
    --exclude=gnome-text-editor \
    --exclude=yelp \
    --exclude=baobab \
    --exclude=decibels \
    --exclude=gnome-boxes \
    --exclude=gnome-calculator \
    --exclude=gnome-calendar \
    --exclude=gnome-characters \
    --exclude=gnome-clocks \
    --exclude=gnome-connections \
    --exclude=gnome-contacts \
    --exclude=gnome-disk-utility \
    --exclude=gnome-font-viewer \
    --exclude=gnome-logs \
    --exclude=gnome-maps \
    --exclude=gnome-system-monitor \
    --exclude=gnome-weather

# Force-remove the terminal (ptyxis) in case the base image or a dependency
# pulled it in despite the exclude above. Guarded so a "not installed" result
# doesn't abort the build (errexit is on).
dnf5 remove -y ptyxis || true

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

### Default Flatpak applications (first-boot install)
## In a bootc/ostree image only /usr is committed to the deployment; /var is
## runtime state and is NOT carried over from the container image. Flatpaks
## installed at build time write to /var/lib/flatpak, so they are silently
## dropped on every bootc upgrade/switch and never appear on the booted
## system. Instead, ship a first-boot systemd service that installs the
## default apps into the host's persistent /var/lib/flatpak — so they appear
## on both fresh installs and after bootc upgrades.
dnf5 install -y flatpak

install -Dm755 /ctx/arcos-install-flatpaks.sh /usr/sbin/arcos-install-flatpaks.sh
install -Dm644 /ctx/arcos-flatpaks.service /usr/lib/systemd/system/arcos-flatpaks.service
systemctl enable arcos-flatpaks.service

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

### Mask systemd-remount-fs.service
## In a bootc image the root filesystem is a deployment managed by bootc
## itself (mounted via the kernel command line), so there is no "/" entry in
## /etc/fstab. systemd-remount-fs.service reads fstab and tries to remount the
## root, finds nothing to remount, and fails. bootc owns the root mount, so
## mask this unit to avoid the failed-unit error on every boot.
systemctl mask systemd-remount-fs.service

