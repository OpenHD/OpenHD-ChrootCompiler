#!/bin/bash -e

echo ${TESTING}
apt update
 if [[ "${OS}" == "radxa-ubuntu" ]]; then
 #fix radxa's fuckup
 sudo apt update
 echo "everything is now setup for compiling"
 fi
echo "we've now entered a chroot environment, everything should be copied into /opt"
cd /opt
cd additionalFiles
ls -a
bash build_chroot.sh
echo "after building we can now push the contents outside the chroot"

