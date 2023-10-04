#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
sudo umount $TEST_TMPDIR
sudo mkdir $TEST_TMPDIR
sudo mkfs.xfs /dev/pmem0
sudo mount /dev/pmem0 $TEST_TMPDIR
sudo chown -R $USER $TEST_TMPDIR
