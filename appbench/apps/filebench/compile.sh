#!/bin/bash
sudo apt update
sudo apt-get install libtool -y
sudo apt-get install bison -y
sudo apt install flex -y
alias yacc="bison"
sudo ln -s /bin/bison /bin/yacc
libtoolize
aclocal
autoheader
automake --add-missing
autoconf



./configure

make clean
make -j$(nproc)
