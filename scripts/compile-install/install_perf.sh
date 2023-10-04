#!/bin/bash

if [ -z "$NVMBASE" ]; then
    echo "PREFIX environment variable not defined. Have you ran setvars?"
    echo "Dont forget to change \$VER in setvars.sh"
    exit 1
fi

echo "If your intended linux kernel version is other than $KERN_SRC, you need to update \$VAR in scripts/setvars.sh"

sudo apt update
sudo apt install -y libunwind-dev libdwarf-dev libdw-dev libslang2-dev libelf-dev libaudit-dev

pushd $KERN_SRC/tools/perf
make clean; make NO_DWARF=0 -j `nproc`; make install
popd

sudo cp $KERN_SRC/vmlinux /boot/vmlinux-$VER
sudo cp $KERN_SRC/System.map /boot/System.map-$VER


sudo sh -c "echo \"kernel.kptr_restrict=0\" >> /etc/sysctl.conf"
sudo sh -c "echo \"kernel.perf_event_paranoid=-1\" >> /etc/sysctl.conf"
sudo sysctl -p /etc/sysctl.conf
echo "You need to reboot the machine now."
