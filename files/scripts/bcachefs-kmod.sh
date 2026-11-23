#!/bin/bash
set -euo pipefail
dnf install -y \
dnf-plugins-core rpm-build cpio tar gcc make kmodtool

mkdir -p /tmp/bcachefs-source /tmp/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cd /tmp/bcachefs-source

dnf download --source --destdir . bcachefs-tools
rpm2cpio bcachefs-tools-*.src.rpm | cpio -idm

VERSION=$(rpm -qp --qf '%{VERSION}' bcachefs-tools-*.src.rpm)
SOURCE=$(find . -maxdepth 1 -name '*.tar.zst' -print -quit)
SOURCE_NAME=${SOURCE##*/}
TOPDIR=$(tar -tf "$SOURCE" | head -n1 | cut -d/ -f1)

sed \
-e "s|@VERSION@|$VERSION|g" \
-e "s|@SOURCE0@|$SOURCE_NAME|g" \
-e "s|@TOPDIR@|$TOPDIR|g" \
/tmp/rpms/bcachefs-kmod.spec.in \
> /tmp/rpmbuild/SPECS/bcachefs-kmod.spec

cp "$SOURCE" /tmp/rpmbuild/SOURCES/

rpmbuild -ba \
--define "_topdir /tmp/rpmbuild" \
/tmp/rpmbuild/SPECS/bcachefs-kmod.spec
mkdir -p /tmp/rpms/output
find /tmp/rpmbuild/RPMS -name '*.rpm' -exec cp {} /tmp/rpms/output/ \;
