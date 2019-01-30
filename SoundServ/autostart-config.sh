#!/bin/bash
echo "Configuring Bpod Sound system service"

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

echo "Bpod Sound Service Configeration Complete"
echo "Configuring Bpod Sound system service priority"

echo "[Unit]" > /lib/systemd/system/bpodsoundpri.service
echo "Description=Sound Prio Config" >> /lib/systemd/system/bpodsoundpri.service
echo "After=multi-user.target bpodsound.service" >> /lib/systemd/system/bpodsoundpri.service
echo "[Service]" >> /lib/systemd/system/bpodsoundpri.service
echo "Type=oneshot" >> /lib/systemd/system/bpodsoundpri.service
echo "RemainAfterExit=true" >> /lib/systemd/system/bpodsoundpri.service



echo "ExecStart=/home/pi/PiSoundServer/soundserv_prio.sh" >> /lib/systemd/system/bpodsoundpri.service
# need to check, is real soundserv_prio file there?



echo "[Install]" >> /lib/systemd/system/bpodsoundpri.service
echo "WantedBy=multi-user.target" >> /lib/systemd/system/bpodsoundpri.service

sudo chmod 644 /lib/systemd/system/bpodsoundpri.service


sudo chmod +700 /home/pi/PiSoundServer/soundserv_prio.sh
# need to check, is real soundserv_prio file there?

sudo systemctl daemon-reload
sudo systemctl enable bpodsoundpri.service
sudo systemctl start bpodsoundpri.service

echo "priority configurate complete!"

echo "Rebooting.."
reboot
