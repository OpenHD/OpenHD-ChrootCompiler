echo "hello world"
cd /opt
ls -a
#./build.sh
sudo apt install git
git clone https://github.com/OpenHD/OpenHD -recursive
cd OpenHD
bash  install_dep_ubuntu22.sh
cd OpenHD
build_cmake.sh
