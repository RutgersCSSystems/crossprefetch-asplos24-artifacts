#!/bin/bash
set -x

#Compile the kernel
cd $KERN_SRC

if [[ $1 == "makemenu" ]];
then
	sudo cp -v /boot/config-$(uname -r) $KERN_SRC/.config
	make menuconfig
fi

#Disable them
scripts/config --disable SYSTEM_REVOCATION_KEYS
scripts/config --disable SYSTEM_TRUSTED_KEYS


#Compile the kernel with '-j' (denotes parallelism) in sudo mode
sudo make $PARA #&> compile.out
grep -r "error:" compile.out #&> errors.out
sudo make modules $PARA &>> compile.out
grep -r "error:" compile.out &>> errors.out
sudo make modules_install $PARA &>> compile.out
grep -r "error:" compile.out &>> errors.out
sudo make install &>> compile.out
grep -r "error:" compile.out &>> errors.out

 y="5.14.0"
   if [[ x$ == x ]];
  then
      echo You have to say a version!
      exit 1
   fi

sudo cp ./arch/x86/boot/bzImage /boot/vmlinuz-$y
sudo cp System.map /boot/System.map-$y
sudo cp .config /boot/config-$y

sudo update-initramfs -c -k $y
sudo update-grub
