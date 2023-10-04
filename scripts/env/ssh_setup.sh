#!/bin/bash
tunctl -u $USER -t tap0
ifconfig tap0 192.168.100.1 up


#As root in the host:
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -I FORWARD 1 -i tap0 -j ACCEPT
iptables -I FORWARD 1 -o tap0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# In the guest OS

auto eth0
iface eth0 inet static
address 192.168.100.2
netmask 255.255.255.0
network 192.168.100.0
gateway 192.168.100.1
dns-nameservers 8.8.8.8
