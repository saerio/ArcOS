#!/bin/bash
#
# Build accountsservice RPM with systemd-homed support
# Run this on your build machine, NOT in the bootc image
#

set -euo pipefail

VERSION="26.12.8"
SPEC_DIR="$(pwd)"
OUTPUT_DIR="$(pwd)/rpms"

mkdir -p "$OUTPUT_DIR"

# Install build deps
sudo dnf5 install -y \
    rpmbuild \
    meson \
    gcc \
    glibc-devel \
    glib2-devel \
    polkit-devel \
    systemd-devel \
    gobject-introspection-devel \
    gtk-doc \
    git \
    vala \
    python3-dbusmock \
    libxcrypt-devel \
    gettext

# Download source
wget -P ~/rpmbuild/SOURCES/ \
    "https://gitlab.freedesktop.org/accountsservice/accountsservice/-/releases/${VERSION}/downloads/accountsservice-${VERSION}.tar.xz"

# Copy spec
cp "$SPEC_DIR/accountsservice-homed.spec" ~/rpmbuild/SPECS/accountsservice.spec

# Build
rpmbuild -ba ~/rpmbuild/SPECS/accountsservice.spec

# Copy results
cp ~/rpmbuild/RPMS/*/accountsservice-*.rpm "$OUTPUT_DIR/"
cp ~/rpmbuild/SRPMS/accountsservice-*.rpm "$OUTPUT_DIR/"

echo "Built RPMs:"
ls -la "$OUTPUT_DIR/"
