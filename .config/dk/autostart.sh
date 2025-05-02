#!/bin/bash

/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
amixer set Capture 80% &
copyq --start-server &
cp ~/.config/BraveSoftware/Brave-Browser/Default/History /tmp/BraveHistory &
deadd-notificatoin-center &
gpaste-client start &
killall polybar; polybar dk-main -r &
killall volume_subscribe.sh ; sleep 1 ; ~/Scripts/volume_subscribe.sh &
feh --bg-fill ~/.cache/x11wall &
picom --config ~/.config/dk/picom.conf &
sudo chown "$USER":"$USER" /sys/class/backlight/intel_backlight/brightness &
sudo virsh net-start default &
udiskie &
unclutter &
volnoti -t 2 &
xfce4-screensaver &
xhost +si:localuser:"$USER" &
xinput set-prop '2.4G Mouse' 'libinput Accel Speed' 0.5 &
xinput set-prop 'PixArt Lenovo USB Optical Mouse' 'libinput Accel Speed' 0.3 &
xinput set-prop 'Synaptics TM3336-004' 'libinput Accel Speed' 0.5 &
xinput set-prop 'Synaptics TM3336-004' 'libinput Natural Scrolling Enabled' 1 &
xinput set-prop 'Synaptics TM3336-004' 'libinput Tapping Enabled' 1 &
xinput set-prop 'YICHIP Wireless Device Mouse' 'libinput Accel Speed' 1 &
xset s off -dpms &
xss-lock --transfer-sleep-lock -- xfce4-screensaver-command -l &
~/Scripts/backup_zsh_history.sh &
~/Scripts/keyboard_config.sh &
~/Scripts/layout_handler.sh &
