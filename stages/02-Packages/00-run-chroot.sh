#!/bin/bash -e

echo "we've now entered a chroot environment, everything should be copied into /opt"
cd /opt
ls -a
cd additionalFiles
ls -a
bash build_chroot.sh
echo "after building we can now push the contents outside the chroot"

