#!/bin/bash

echo "[Unit]" > /lib/systemd/system/bpodsound.service
echo "Description=Bpod Sound" >> /lib/systemd/system/bpodsound.service
echo "After=multi-user.target" >> /lib/systemd/system/bpodsound.service
echo "[Service]" >> /lib/systemd/system/bpodsound.service
echo "Type=simple" >> /lib/systemd/system/bpodsound.service



echo "ExecStart=/usr/bin/python3 /home/pi/PiSoundServer/RespberryPiAudioService.py" >> /lib/systemd/system/bpodsound.service
# need to check, is real sound server file there?


echo "Restart=always" >> /lib/systemd/system/bpodsound.service
echo "[Install]" >> /lib/systemd/system/bpodsound.service
echo "WantedBy=multi-user.target" >> /lib/systemd/system/bpodsound.service

sudo chmod 644 /lib/systemd/system/bpodsound.service


chmod +x /home/pi/PiSoundServer/RespberryPiAudioService.py
# need to check, is real sound server file there?


sudo systemctl daemon-reload
sudo systemctl enable bpodsound.service
sudo systemctl start bpodsound.service

echo "Rebooting.."
reboot
