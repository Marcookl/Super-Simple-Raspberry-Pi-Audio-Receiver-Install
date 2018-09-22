#!/bin/bash

#The bluetooth device can appear as a number of things.
#Change the line '+ Class = 0x200414' below to one of the following classes;
# 0x200418 - Headphones
# 0x200414 - Loudspeaker (default)
# 0x200420 - Car Audio
# 0x200434 - Car audio, Loudspeaker
# 0x200438 - Car Audio, Headphones
#
# All of the above classes show the headphone icon on iOS when connected.
# If you wish to not have that icon then use one of the following;
# 0x20041C - Headphones, Portable Audio / Portable Audio
# 0x20043C - Headphones, Portable Audio, Car audio / Portable Audio, Car audio

if [ -z "$BluetoothName" ]
then
 read -p "Bluetooth device name: " BluetoothName
fi
if [ -z "$exc" ]
then 
    source functions.sh
    source dependencies.sh
fi


sudo -S cp usr/local/bin/volume-watcher.py /usr/local/bin/volume-watcher.py
sudo -S chmod +x /usr/local/bin/volume-watcher.py
sudo -S cp lib/systemd/system/volume-watcher.service /lib/systemd/system/volume-watcher.service
sudo -S systemctl enable volume-watcher
exc cd `dirname $0`

sudo -S echo "PRETTY_HOSTNAME=$BluetoothName" >> /tmp/machine-info
exc tst sudo -S cp /tmp/machine-info /etc

save_original /etc/init.d/pulseaudio
sudo -S cp init.d/pulseaudio /etc/init.d/pulseaudio
sudo -S chmod +x /etc/init.d/pulseaudio
sudo -S update-rc.d pulseaudio defaults

save_original /etc/init.d/bluetooth
sudo -S cp init.d/bluetooth /etc/init.d/bluetooth
sudo -S chmod +x /etc/init.d/bluetooth
sudo -S update-rc.d bluetooth defaults

save_original /etc/init.d/bluetooth-agent
if [ "$VOL_USER" = "\"arm\"" ]
then
	sudo -S cp init.d/bluetooth-agent-vol /etc/init.d/bluetooth-agent
else
	sudo -S cp init.d/bluetooth-agent /etc/init.d/bluetooth-agent
fi
sudo -S chmod +x /etc/init.d/bluetooth-agent
sudo -S update-rc.d bluetooth-agent defaults

sudo -S cp usr/local/bin/bluez-udev /usr/local/bin
sudo -S chmod 755 /usr/local/bin/bluez-udev

sudo -S cp usr/local/bin/simple-agent.autotrust /usr/local/bin
sudo -S chmod 755 /usr/local/bin/simple-agent.autotrust

sudo -S cp usr/local/bin/say.sh /usr/local/bin
sudo -S chmod 755 /usr/local/bin/say.sh

sudo -S cp usr/local/bin/bluezutils.py /usr/local/bin

if [ -d "/etc/pulse" ]
then
  PA_FILES=`ls /etc/pulse`
  for _file in ${PA_FILES[@]}; do
        if [ -e $_file ]; then 
            if [ -d $_file ]; then 
               continue
            else
               save_original $_file
            fi
        fi
  done
else
  sudo -S mkdir /etc/pulse  
fi
sudo -S cp etc/pulse/daemon.conf /etc/pulse/daemon.conf

save_original /boot/config.txt
exc cat << EOT | sudo -S tee -a /boot/config.txt
 # Enable audio (loads snd_bcm2835)
 dtparam=audio=on
audio_pwm_mode=2
EOT

if [ -f /etc/udev/rules.d/99-com.rules ]; then
save_original /etc/udev/rules.d/99-com.rules
sudo -S patch /etc/udev/rules.d/99-com.rules << EOT
***************
*** 1 ****
--- 1,2 ----
  SUBSYSTEM=="input", GROUP="input", MODE="0660"
+ KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluez-udev"
EOT

else
save_original /etc/udev/rules.d/99-com.rules
sudo -S touch /etc/udev/rules.d/99-com.rules
sudo -S chmod 666 /etc/udev/rules.d/99-com.rules

save_original /etc/udev/rules.d/99-input.rules
exc cat  << EOT | sudo -S tee -a /etc/udev/rules.d/99-input.rules
SUBSYSTEM=="input", GROUP="input", MODE="0660"
KERNEL=="input[0-9]*", RUN+="/usr/local/bin/bluez-udev"
EOT

fi

sudo -S chmod 644 /etc/udev/rules.d/99-com.rules

save_original /etc/bluetooth/main.conf
sudo -S patch /etc/bluetooth/main.conf << EOT
***************
*** 7,8 ****
--- 7,9 ----
  #Name = %h-%d
+ Name = ${BT_NAME}
***************
*** 11,12 ****
--- 12,14 ----
  #Class = 0x000100
+ Class = 0x200414
***************
*** 15,17 ****
  # 0 = disable timer, i.e. stay discoverable forever
! #DiscoverableTimeout = 0
--- 17,19 ----
  # 0 = disable timer, i.e. stay discoverable forever
! DiscoverableTimeout = 0
EOT

save_original /etc/pulse/system.pa
sudo -S patch /etc/pulse/system.pa << EOT
***************
*** 23,25 ****
  .ifexists module-udev-detect.so
! load-module module-udev-detect
  .else
--- 23,26 ----
  .ifexists module-udev-detect.so
! #load-module module-udev-detect
! load-module module-udev-detect tsched=0
  .else
***************
*** 57 ****
--- 58,63 ----
  load-module module-position-event-sounds
+
+ ### Automatically load driver modules for Bluetooth hardware
+ .ifexists module-bluetooth-discover.so
+     load-module module-bluetooth-discover
+ .endif
EOT


#sudo -S service bluetooth start &
#sudo -S service pulseaudio start &
#sudo -S service bluetooth-agent start &
# BT FIX

exc remove_dir /etc/pulsebackup
sudo -S mkdir /etc/pulsebackup
sudo -S cp /etc/pulse/* /etc/pulsebackup/

exc cd ~
exc remove_dir pulseaudio
exc git clone --branch v6.0 https://github.com/pulseaudio/pulseaudio

exc cd ~
exc remove_dir json-c
exc git clone https://github.com/json-c/json-c.git
exc cd json-c
exc sh autogen.sh
exc ./configure 
exc make
sudo -S make install
exc cd ~
exc remove_dir libsndfile
exc git clone git://github.com/erikd/libsndfile.git
exc cd libsndfile
exc ./autogen.sh
exc ./configure --enable-werror
exc make
sudo -S make install
exc cd ~
exc cd pulseaudio
sudo -S ./bootstrap.sh
sudo -S make
sudo -S make install
sudo -S ldconfig
sudo -S cp /etc/pulsebackup/* /etc/pulse
