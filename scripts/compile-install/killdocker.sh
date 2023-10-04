#!/bin/bash
sudo docker ps -a | grep minutes | awk '{PROC=$1; system(sudo docker stop  PROC); system(sudo docker rm  PROC)}'
