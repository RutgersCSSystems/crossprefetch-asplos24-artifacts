#!/bin/bash
set -x

if [ -z "$NVMBASE" ]; then
	echo "NVMBASE environment variable not defined. Have you ran setvars?"
	exit 1
fi

sudo umount $MOUNT_DIR
#Compile the kernel
cd $KERN_SRC
#Enable the KVM mode in your kernel config file
sudo make x86_64_defconfig
sudo make kvmconfig 
#make oldconfig
#make menuconfig
sudo make prepare
#Compile the kernel with '-j' (denotes parallelism) in sudo mode
#sudo make prepare ##Uses the modified .config file to compile kernel

#sudo make $PARA &> $KERN_SRC/compile.out
sudo make $PARA | tee $KERN_SRC/compile.out

grep -r "error:|undefined|warning|Permission" $KERN_SRC/compile.out &> $KERN_SRC/errors.out

cp ./arch/x86/boot/bzImage $KERNEL/vmlinuz-$VER
cp System.map $KERNEL/System.map-$VER
cp .config $KERNEL/config-$VER
#update-initramfs -c -k $y
grep -r "error:" $KERN_SRC/compile.out &> $KERN_SRC/errors.out
cat $KERN_SRC/errors.out
