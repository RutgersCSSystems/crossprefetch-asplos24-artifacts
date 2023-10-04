sudo cp modifiednix.config .config

#Compile the kernel with '-j' (denotes parallelism) in sudo mode
sudo make -j$PROC
sudo make modules
sudo make INSTALL_MOD_STRIP=1 modules_install
sudo make INSTALL_MOD_STRIP=1 install

y="5.14.0"

sudo cp ./arch/x86/boot/bzImage /boot/vmlinuz-$y
sudo cp System.map /boot/System.map-$y
sudo cp .config /boot/config-$y
sudo update-initramfs -c -k $y
