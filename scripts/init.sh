#!/bin/bash

REPO="https://github.com/RutgersCSSystems/crossprefetch-asplos24-artifacts.git"

export DEBIAN_FRONTEND=noninteractive

cd $HOME
sudo mkfs.ext4 /dev/nvme0n1
mkdir ~/ssd
sudo mount /dev/nvme0n1 ~/ssd
cd ~/ssd
sudo chown -R $USER .

git clone $REPO
cd crossprefetch-asplos24-artifacts

source ./scripts/setvars.sh
scripts/install_packages.sh

cd $BASE/linux-5.14.0
./compile_modified_deb.sh


