#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

# Automation script to create specs to build cc-oci-runtime
# Default image to build is the one specified in file configure.ac
# located at the root of the repository.
# set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

CC_VERSIONS_FILE="../../../versions.txt"
source "$CC_VERSIONS_FILE"
clear_vm_kernel_version=$(echo $clear_vm_kernel_version | cut -d'-' -f1)
VERSION=${1:-$clear_vm_kernel_version}

OBS_PUSH=${OBS_PUSH:-false}

last_release=`cat wd/debian/changelog | head -1 | awk '{print $2}' | cut -d'-' -f2 | tr -d ')'`
next_release=$(( $last_release + 1 ))

echo "Running: $0 $@"
echo "Update linux-container to: $VERSION-$next_release"

function changelog_update {
    d=`date +"%a, %d %b %Y %H:%M:%S"`
    cp wd/debian/changelog wd/debian/changelog-bk
    cat <<< "linux-container ($VERSION-$next_release) stable; urgency=medium

  * Update kernel $VERSION

 -- $AUTHOR <$AUTHOR_EMAIL>  $d -0600
" > wd/debian/changelog

    cat wd/debian/changelog-bk >> wd/debian/changelog
    rm wd/debian/changelog-bk
}

changelog_update $VERSION

sed "s/\@VERSION\@/$VERSION/g; s/\@RELEASE\@/$next_release/g" linux-container.spec-template > linux-container.spec
spectool -g linux-container.spec

ln -s linux-$VERSION.tar.xz linux-container_$VERSION.orig.tar.xz

for i in `cat wd/debian/patches/series`
do
    cp $i wd/debian/patches/
done

cp config wd/debian/
cd wd
debuild -S -sa

if [ $? = 0 ] && [ "$OBS_PUSH" = true ]
then
    cd ..
    rm wd/debian/patches/*.patch
    rm linux-container_$VERSION-${next_release}_source.build \
    linux-container_$VERSION-${next_release}_source.changes
    osc co home:clearlinux:preview:clear-containers-staging/linux-container
    cd home\:clearlinux\:preview\:clear-containers-staging/linux-container/
    osc rm linux-*.tar.xz
    osc rm linux-container*.dsc
    mv ../../linux-*.tar.xz .
    mv ../../linux-container*.dsc .
    mv ../../linux-container.spec .
    cp ../../cmdline .
    cp ../../config .
    osc add linux-*.tar.xz
    osc add linux-container*.dsc
    osc commit -m "Update linux-container to: $VERSION-$next_release"
fi
