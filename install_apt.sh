#!/bin/bash

sudo apt update
sudo apt install -y curl wget tar git ruby python-is-python3 python3 bc

# for docker
sudo apt install -y docker.io
sudo groupadd docker
sudo usermod -aG docker $

sudo apt install -y libpq-dev

sudo apt install -y busybox-static bash-static fakeroot dmsetup kpartx netcat-openbsd nmap snmp uml-utilities util-linux vlan
sudo apt install -y mtd-utils gzip bzip2 tar arj lhasa p7zip p7zip-full cabextract fusecram cramfsswap squashfs-tools sleuthkit default-jdk cpio lzop lzma srecord zlib1g-dev liblzma-dev liblzo2-dev unzip
sudo apt install -y openjdk-8-jdk unrar

sudo apt install -y qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils