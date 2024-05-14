#!/bin/bash -e

echo ${TESTING}

if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]; then
 #fix radxa's fuckup
 sudo apt update
    PLATFORM_PACKAGES_HOLD="linux-image-rock-5b radxa-system-config-rtk-btusb-dkms r8125-dkms 8852bu-dkms 8852be-dkms task-rockchip radxa-system-config-rockchip linux-image-rock-5a linux-image-5.10.110-6-rockchip linux-image-5.10.110-11-rockchip"
     echo "Holding back platform-specific packages..."
    for package in ${PLATFORM_PACKAGES_HOLD}; do
        echo "Holding ${package}..."
        apt-mark hold ${package} || true
        if [ $? -ne 0 ]; then
            echo "Failed to hold ${package}!"
        fi
    done
 echo "everything is now setup for compiling"
 fi
 if [ -f "/etc/apt/sources.list.d/nvidia-l4t-apt-source.list" ]; then sudo sed -i 's|deb https://repo.download.nvidia.com/jetson/<SOC> r35.5 main|deb https://repo.download.nvidia.com/jetson/t194 r35.5 main|' /etc/apt/sources.list.d/nvidia-l4t-apt-source.list; fi
 if [[ "${OS}" == "debian-X20" ]]; then
   #  rm -Rf /etc/apt/sources.list.d/*
   #  rm -Rf /etc/apt/sources.list
   #  touch /etc/apt/sources.list
    apt update
    apt install -y swig gcc-arm*
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
 fi

 if [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
    PLATFORM_PACKAGES_HOLD="u-boot-radxa-zero3 radxa-system-config-common radxa-system-config-kernel-cmdline-ttyfiq0 radxa-firmware radxa-system-config-bullseye 8852be-dkms task-rockchip radxa-system-config-rockchip linux-image-radxa-cm3-rpi-cm4-io linux-headers-radxa-cm3-rpi-cm4-io linux-image-5.10.160-12-rk356x linux-headers-5.10.160-12-rk356x"
     echo "Holding back platform-specific packages..."
    for package in ${PLATFORM_PACKAGES_HOLD}; do
        echo "Holding ${package}..."
        apt-mark hold ${package} || true
        if [ $? -ne 0 ]; then
            echo "Failed to hold ${package}!"
        fi
    done
 fi

echo "we've now entered a chroot environment, everything should be copied into /opt"
echo "_____________________________________________________________________________"
sudo mkdir /host
lsblk
for partition in $(lsblk -rno NAME,TYPE | grep 'part$' | awk '{print "/dev/" $1}'); do
  if ! mount | grep -q "$partition"; then
    mount_point=$(mktemp -d)
    mount "$partition" "$mount_point" &>/dev/null
    if [ $? -eq 0 ]; then
      if [ -f "$mount_point/etc/os-release" ]; then
        grep -q "Ubuntu" "$mount_point/etc/os-release"
        if [ $? -eq 0 ]; then
          umount "$mount_point"
          rmdir "$mount_point"
          mkdir -p /host
          mount "$partition" /host
          echo "$partition is mounted to /host"
          exit 0
        fi
      fi
      umount "$mount_point"
    fi
    rmdir "$mount_point"
  fi
done

mount
touch /host/opt/file.txt

# cd additionalFiles
# bash build_chroot.sh
echo "after building we can now push the contents outside the chroot"
echo "___________________________________________________"