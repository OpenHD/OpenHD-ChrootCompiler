#!/bin/bash -e

echo ${TESTING}
apt update
 if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]; then
 #fix radxa's fuckup
 sudo apt update
 echo "everything is now setup for compiling"
 fi
 if [[ "${OS}" == "debian-X20" ]]; then
    rm -Rf /etc/apt/sources.list.d/*
    rm -Rf /etc/apt/sources.list
    touch /etc/apt/sources.list
    apt update
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
 fi

echo "we've now entered a chroot environment, everything should be copied into /opt"
cd /opt
cd additionalFiles
ls -a
bash build_chroot.sh
echo "after building we can now push the contents outside the chroot"

