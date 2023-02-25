echo "hello world"
cd /opt
ls -a
#./build.sh
sudo apt update
wget -O - apt.radxa.com/bullseye-stable/public.key | sudo apt-key add - 
sudo apt install -y git
git clone https://github.com/OpenHD/OpenHD -recursive
cd OpenHD
bash  install_dep_ubuntu22.sh
cd OpenHD
build_cmake.sh
