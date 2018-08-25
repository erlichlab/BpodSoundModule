#!/bin/bash

echo "Start serial port setting"
echo "enable_uart=1" >> /boot/config.txt
echo "dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes  rootwait" > /boot/cmdline.txt
#usermod -aG dialout erlichrig

echo "Configuring the sound card"
echo "dtoverlay=iqaudio-dacplus" >> /boot/config.txt
sed -i 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt

echo "Install Jack Server"
sudo apt-get install qjackctl

#aplay -l
python3 -m pip install NumPy --user
python3 -m pip install cffi --user
apt-get install libasound-dev
python3 -m pip install pysoundfile --user
python3 -m pip install sounddevice --user
apt-get install libtool pkg-config build-essential autoconf automake

echo "Install libsodium"
wget https://github.com/jedisct1/libsodium/releases/download/1.0.3/
libsodium-1.0.3.tar.gz
tar -zxvf libsodium-1.0.3.tar.gz
cd libsodium-1.0.3/
./configure
make
make install

echo "Install Zeromq"
wget http://download.zeromq.org/zeromq-4.1.3.tar.gz
tar -zxvf zeromq-4.1.3.tar.gz
cd zeromq-4.1.3/
./configure
make
make install
ldconfig

echo "Install PyZMQ"
apt-get install python-dev
python3 -m pip install pyzmq --user

echo "Rebooting.."
reboot

