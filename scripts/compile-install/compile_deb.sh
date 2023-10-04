#!/bin/bash -x
cd $KERN_SRC
sudo apt-get install -y libdpkg-dev kernel-package libncurses-dev
export CONCURRENCY_LEVEL=20
export CONCURRENCYLEVEL=20
touch REPORTING-BUGS

sudo make menuconfig


#Disable them
sudo scripts/config --disable SYSTEM_REVOCATION_KEYS
sudo scripts/config --disable SYSTEM_TRUSTED_KEYS

#sudo make menuconfig


#mv .config .config_back
#make distclean
#fakeroot make-kpkg clean
sudo fakeroot make-kpkg -j`nproc` --initrd kernel-image kernel-headers
sudo dpkg -i ../*image*.deb ../*header*.deb
exit
