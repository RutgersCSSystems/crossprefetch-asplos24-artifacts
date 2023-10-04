#!/bin/bash
set -x

sudo sysctl -w vm.dirty_background_ratio=10
sudo sysctl -w vm.dirty_ratio=10
sudo sysctl -w vm.dirtytime_expire_seconds=4000
