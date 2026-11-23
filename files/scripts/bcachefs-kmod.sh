#!/usr/bin/env bash
set -euo pipefail

echo "Installing Deps"
dnf install -y \
    dnf-plugins-core \
    rpm-build \
    cpio \
    tar \
    gcc \
    make \
    kmodtool

echo "Creating dir layout"
mkdir -p \
    /tmp/bcachefs-source \
    /tmp/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} \
    /tmp/rpms/output

echo "changing dir"
cd /tmp/bcachefs-source

echo "downloading bcachefs-tools srpm"
dnf download --source --destdir . bcachefs-tools

SRPM=$(find . -maxdepth 1 -name 'bcachefs-tools-*.src.rpm' -print -quit)

echo "installing builddeps of bcachefs-tools"
dnf builddep -y "$SRPM"

echo "unpacking srpm"
rpm2cpio "$SRPM" | cpio -idm

echo "Pulling version and source for kmod"
echo "Version:"
VERSION=$(rpm -qp --qf '%{VERSION}' "$SRPM")
echo "$VERSION"
SOURCE=$(find . -maxdepth 1 -name '*.tar.zst' -print -quit)
echo "$SOURCE"

SOURCE_NAME=$(basename "$SOURCE")
echo "$SOURCE_NAME"
TOPDIR=$(tar -tf "$SOURCE" | head -n1 | cut -d/ -f1)
echo "$TOPDIR"

echo "Substituting with real vars"
sed \
    -e "s|@VERSION@|$VERSION|g" \
    -e "s|@SOURCE0@|$SOURCE_NAME|g" \
    -e "s|@TOPDIR@|$TOPDIR|g" \
    /tmp/rpms/bcachefs-kmod.spec.in \
    > /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

cp "$SOURCE" /tmp/rpmbuild/SOURCES/

echo "building kmod"
rpmbuild -ba \
    --define "_topdir /tmp/rpmbuild" \
    /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

RPM_FILES=(/tmp/rpmbuild/RPMS/**/*.rpm)

echo "copying kmod to out"
cp "${RPM_FILES[@]}" /tmp/rpms/output/

echo "Successfully built RPMs:"
ls -lh /tmp/rpms/output/
