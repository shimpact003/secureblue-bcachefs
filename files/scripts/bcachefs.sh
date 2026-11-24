#!/usr/bin/env bash
set -euo pipefail

echo "Installing dependencies"
dnf install -y \
    git \
    fedpkg \
    dnf-plugins-core \
    rpm-build \
    rpmdevtools \
    cpio \
    tar \
    gcc \
    make \
    kmodtool \
    python3-krb5 \
    krb5-libs

echo "Creating directory layout"
mkdir -p \
    /tmp/bcachefs-source \
    /tmp/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} \
    /tmp/rpms/output

cd /tmp/bcachefs-source

echo "Cloning Fedora packaging"
git clone --depth=1 --branch=rawhide \
    https://src.fedoraproject.org/rpms/bcachefs-tools

cd bcachefs-tools

echo "Downloading Fedora source archives"
fedpkg sources

echo "Building source RPM"
rpmbuild -bs \
    --define "_topdir /tmp/rpmbuild" \
    bcachefs-tools.spec

SRPM=$(find /tmp/rpmbuild/SRPMS \
    -name 'bcachefs-tools-*.src.rpm' -print -quit)

if [[ -z "$SRPM" ]]; then
    echo "SRPM not found"
    exit 1
fi

echo "Installing build dependencies"
dnf builddep -y "$SRPM"

echo "Extracting SRPM"
cd /tmp/bcachefs-source
rpm2cpio "$SRPM" | cpio -idm

echo "Finding source archive"
SOURCE=$(find . -maxdepth 1 -name '*.tar.*' -print -quit)

if [[ -z "$SOURCE" ]]; then
    echo "Source archive not found"
    exit 1
fi

VERSION=$(rpm -qp --qf '%{VERSION}' "$SRPM")
SOURCE_NAME=$(basename "$SOURCE")

TOPDIR=$(tar -tf "$SOURCE" | sed -n '1{s|/.*||;p;}')

echo "Version: $VERSION"
echo "Source: $SOURCE_NAME"
echo "Topdir: $TOPDIR"

echo "Generating kmod spec"
sed \
    -e "s|@VERSION@|$VERSION|g" \
    -e "s|@SOURCE0@|$SOURCE_NAME|g" \
    -e "s|@TOPDIR@|$TOPDIR|g" \
    /tmp/files/rpms/bcachefs-kmod.spec.in \
    > /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

cp "$SOURCE" /tmp/rpmbuild/SOURCES/

echo "Installing kmod build dependencies"
dnf builddep -y /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

echo "Building kmod"
rpmbuild -ba \
    --define "_topdir /tmp/rpmbuild" \
    /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

echo "Collecting RPMs"
shopt -s globstar nullglob
RPM_FILES=(/tmp/rpmbuild/RPMS/**/*.rpm)

if ((${#RPM_FILES[@]} == 0)); then
    echo "No RPMs were built"
    exit 1
fi

cp "${RPM_FILES[@]}" /tmp/rpms/output/

echo "Successfully built RPMs:"
ls -lh /tmp/rpms/output/
