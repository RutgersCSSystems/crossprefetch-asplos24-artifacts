#!/bin/bash

mkdir $HOME/ssd/Downloads

pushd $HOME/ssd/Downloads

wget http://ftp.gromacs.org/pub/gromacs/gromacs-2019.tar.gz

tar -xvf gromacs-2019.tar.gz

cd gromacs-2019

mkdir build

cd build

cmake .. -DGMX_BUILD_OWN_FFTW=on -DREGRESSIONTEST_DOWNLOAD=ON
make -j`nproc`
sudo make install
cmake .. -DGMX_BUILD_OWN_FFTW=on -DREGRESSIONTEST_DOWNLOAD=ON -DGMX_MPI=on -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx -DGMX_BUILD_MDRUN_ONLY=on -DGMX_GPU=OFF
make -j`nproc`
sudo make install

popd
