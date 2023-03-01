echo "we've now entered a chroot environment, everything should be copied into /opt"
cd /opt
ls -a
./build.sh
echo "after building we can now push the contents outside the chroot"

