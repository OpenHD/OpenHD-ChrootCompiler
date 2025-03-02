#!/bin/bash -e

# Do NOT TOUCH, this allows files to be copied outside of the CHROOT
ls /opt/additionalFiles/
cat /opt/additionalFiles/mount.txt
cat /opt/additionalFiles/pwd.txt
HOST=$(cat /opt/additionalFiles/mount.txt)
mkdir /host
mount $HOST /host
INDIR=$(cat /opt/additionalFiles/pwd.txt)
OUTDIR="/host"$INDIR
ln -s $OUTDIR /out
rm -Rf /out/*

echo "_______________________Starting build____________________________"

if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]; then
 #fix radxa's fuckup
# Remove old Radxa repository from sources.list
sudo sed -i '/radxa-repo.github.io/d' /etc/apt/sources.list

# Remove any old Radxa repository list files
sudo rm -f /etc/apt/sources.list.d/radxa.list /etc/apt/sources.list.d/70-radxa.list

# Remove outdated keys
sudo apt-key del E572249A33EB9743 5D93177D0752732A

# Download and install the new Radxa keyring
keyring="$(mktemp)"
version="$(curl -Ls https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/VERSION)"
curl -L --output "$keyring" "https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/radxa-archive-keyring_${version}_all.deb"
sudo dpkg -i "$keyring"
rm -f "$keyring"

# Add the updated repository to sources.list
echo "deb [signed-by=/usr/share/keyrings/radxa-archive-keyring.gpg] https://radxa-repo.github.io/bullseye/ bullseye main" | sudo tee -a /etc/apt/sources.list

# Update package lists
echo "UPDATING___________"
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
    apt install -y swig gcc-arm* libpoco-dev
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
    sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
 fi

 if [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
    sudo apt-key del E572249A33EB9743 5D93177D0752732A; wget -qO - https://radxa-repo.github.io/bullseye/public.key | sudo tee /usr/share/keyrings/radxa-apt-keyring.gpg >/dev/null; echo "deb [signed-by=/usr/share/keyrings/radxa-apt-keyring.gpg] https://radxa-repo.github.io/bullseye bullseye main" | sudo tee /etc/apt/sources.list.d/radxa.list; sudo apt-get update
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


ls -a
cd /opt/additionalFiles
bash build_chroot.sh

