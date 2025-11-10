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
  # fix radxa's issues

  export DEBIAN_FRONTEND=noninteractive

  # Remove old Radxa repository from sources.list
  sudo sed -i '/radxa-repo.github.io/d' /etc/apt/sources.list || true

  # Remove any old Radxa repository list files
  sudo rm -f /etc/apt/sources.list.d/radxa.list /etc/apt/sources.list.d/70-radxa.list || true

  # Remove outdated keys (ignore errors if already gone)
  sudo apt-key del E572249A33EB9743 5D93177D0752732A >/dev/null 2>&1 || true

  # Download and install the new Radxa keyring
  keyring="$(mktemp)"
  version="$(curl -Ls https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/VERSION)"
  curl -L --output "$keyring" "https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/radxa-archive-keyring_${version}_all.deb"
  sudo dpkg -i "$keyring"
  rm -f "$keyring"

  # Add the updated repository to sources.list (append if missing)
  if ! grep -q 'radxa-repo.github.io/bullseye' /etc/apt/sources.list; then
    echo "deb [signed-by=/usr/share/keyrings/radxa-archive-keyring.gpg] https://radxa-repo.github.io/bullseye/ bullseye main" | sudo tee -a /etc/apt/sources.list
  fi

  echo "UPDATING___________"

  # ---------- APT PREFLIGHT FOR ROCK5 (Bullseye archive + robust fallbacks) ----------
  normalize_bullseye_sources() {
    sudo mkdir -p /etc/apt/sources.list.d
    sudo touch /etc/apt/sources.list

    # 1) Point Debian base & updates/backports to archive.debian.org
    sudo sed -i -E \
      -e 's|https?://deb\.debian\.org/debian|http://archive.debian.org/debian|g' \
      /etc/apt/sources.list || true
    sudo find /etc/apt/sources.list.d -name '*.list' -print0 2>/dev/null \
      | xargs -0 -r sudo sed -i -E \
        -e 's|https?://deb\.debian\.org/debian|http://archive.debian.org/debian|g'

    # 2) Ensure debian-security points to the *live* security mirror (NOT archive)
    sudo sed -i -E \
      -e 's|https?://security\.debian\.org/debian-security|https://security.debian.org/debian-security|g' \
      -e 's|http://archive\.debian\.org/debian-security|https://security.debian.org/debian-security|g' \
      /etc/apt/sources.list || true
    sudo find /etc/apt/sources.list.d -name '*.list' -print0 2>/dev/null \
      | xargs -0 -r sudo sed -i -E \
        -e 's|https?://security\.debian\.org/debian-security|https://security.debian.org/debian-security|g' \
        -e 's|http://archive\.debian\.org/debian-security|https://security.debian.org/debian-security|g'

    # 3) Ensure a sane minimal Bullseye set exists (append if missing)
    if ! grep -qE '^deb .* bullseye ' /etc/apt/sources.list; then
      cat <<'EOF' | sudo tee -a /etc/apt/sources.list >/dev/null
deb http://archive.debian.org/debian bullseye main contrib non-free
deb http://archive.debian.org/debian bullseye-updates main contrib non-free
deb http://archive.debian.org/debian bullseye-backports main contrib non-free
deb https://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
    fi
  }

  disable_backports_everywhere() {
    echo "[apt-preflight] Disabling bullseye-backports (fallback)..."
    sudo sed -i -E '/bullseye-backports/s/^[[:space:]]*deb/# &/' /etc/apt/sources.list || true
    sudo find /etc/apt/sources.list.d -name '*.list' -print0 2>/dev/null \
      | xargs -0 -r sudo sed -i -E '/bullseye-backports/s/^[[:space:]]*deb/# &/'
    export APT_BACKPORTS_DISABLED=1
  }

  disable_security_everywhere() {
    echo "[apt-preflight] Disabling bullseye-security (fallback)..."
    sudo sed -i -E '/debian-security/s/^[[:space:]]*deb/# &/' /etc/apt/sources.list || true
    sudo find /etc/apt/sources.list.d -name '*.list' -print0 2>/dev/null \
      | xargs -0 -r sudo sed -i -E '/debian-security/s/^[[:space:]]*deb/# &/'
    export APT_SECURITY_DISABLED=1
  }

  apt_update_tolerant() {
    sudo apt-get \
      -o Acquire::Check-Valid-Until=false \
      -o Acquire::Retries=2 \
      -o Acquire::http::Timeout=20 \
      -o Acquire::https::Timeout=20 \
      update
  }

  normalize_bullseye_sources

  if ! apt_update_tolerant; then
    echo "[apt-preflight] First update failed; attempting backports disable and retry..."
    disable_backports_everywhere
    if ! apt_update_tolerant; then
      echo "[apt-preflight] Still failing; disabling debian-security and retrying..."
      disable_security_everywhere
      apt_update_tolerant || {
        echo "[apt-preflight] ERROR: apt update failed even after disabling backports and security."
        exit 1
      }
    fi
  fi

  echo "[apt-preflight] Effective sources:"
  grep -Rhv '^[[:space:]]*#' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
  # ---------- END APT PREFLIGHT ----------

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

if [ -f "/etc/apt/sources.list.d/nvidia-l4t-apt-source.list" ]; then
  sudo sed -i 's|deb https://repo.download.nvidia.com/jetson/<SOC> r35.5 main|deb https://repo.download.nvidia.com/jetson/t194 r35.5 main|' /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
fi

if [[ "${OS}" == "debian-X20" ]]; then
  #  rm -Rf /etc/apt/sources.list.d/*
  #  rm -Rf /etc/apt/sources.list
  #  touch /etc/apt/sources.list
  apt update
  apt install -y swig gcc-arm* libpoco-dev python3-dev
  sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
  sudo sed -i 's/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/dev-release\/deb\/debian bullseye main/deb \[signed-by=\/usr\/share\/keyrings\/openhd-dev-release-archive-keyring.gpg\] https:\/\/dl.cloudsmith.io\/public\/openhd\/release\/deb\/debian sunxi main/' /etc/apt/sources.list.d/openhd-release.list
fi

if [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
  sudo apt-key del E572249A33EB9743 5D93177D0752732A >/dev/null 2>&1 || true
  wget -qO - https://radxa-repo.github.io/bullseye/public.key | sudo tee /usr/share/keyrings/radxa-apt-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/radxa-apt-keyring.gpg] https://radxa-repo.github.io/bullseye bullseye main" | sudo tee /etc/apt/sources.list.d/radxa.list
  sudo apt-get update
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
