#!/bin/bash -x

##To be used when this kernel has already been installed once using deb
##Will reflect new changes to the kernel

set -x
VER="4.15.1"
PROC=`nproc`

CC=/usr/lib/ccache/bin/gcc make -j$PROC &>compile.out
grep -r "error:" compile.out &> errors.out
grep -r "undefined:" compile.out &> errors.out

#CC=/usr/lib/ccache/bin/gcc make bzImage -j$PROC &>>compile.out
CC=/usr/lib/ccache/bin/gcc make vmlinux -j$PROC &>>compile.out
grep -r "error:" compile.out &> errors.out
grep -r "undefined:" compile.out &> errors.out

CC=/usr/lib/ccache/bin/gcc make modules -j$PROC &>>compile.out
CC=/usr/lib/ccache/bin/gcc make modules_install -j$PROC &>> compile.out
CC=/usr/lib/ccache/bin/gcc make install -j$PROC &>> compile.out
grep -r "error:" compile.out &> errors.out
grep -r "undefined:" compile.out &> errors.out


#cp ./arch/x86/boot/bzImage /boot/vmlinuz-$VER
cp ./vmlinux /boot/vmlinux-$VER
cp System.map /boot/System.map-$VER
cp .config /boot/config-$VER
rm -rf /boot/initrd.img-$VER
update-initramfs -c -k $VER
#echo Now edit menu.lst or run /sbin/update-grub

grep -r "warning:" compile.out &> warnings.out
grep -r "error:" compile.out &> errors.out
grep -r "undefined:" compile.out &> errors.out
set +x

