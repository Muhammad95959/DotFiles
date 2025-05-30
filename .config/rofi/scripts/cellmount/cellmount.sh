#!/bin/sh

# merged and modified luke smith's mount and unmount script and imported to rofi

# ┌─┐┌─┐┌┐┌┌─┐┬┌─┐┬ ┬┬─┐┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
# │  │ ││││├┤ ││ ┬│ │├┬┘├─┤ │ ││ ││││└─┐
# └─┘└─┘┘└┘└  ┴└─┘└─┘┴└─┴ ┴ ┴ ┴└─┘┘└┘└─┘

# rofi sconfig
roficonfig=~/DotFiles/.config/rofi/scripts/cellmount/prompt.rasi
# Always mount your phone here 
mountpoint=$HOME/Cell

# ┬─┐┌─┐┌─┐┬
# ├┬┘│ │├┤ │
# ┴└─└─┘└  ┴

androiddevices=$(simple-mtpfs -l 2>/dev/null)
[ -z "$androiddevices" ] && printf "exit" | rofi -config $roficonfig -dmenu -i -only-match -p "No Android Device Found" && exit

chk=$(printf "Mount\nUnmount" | rofi -config $roficonfig -dmenu -i -hover-select -p "Android Device: ")

case $chk in
	Unmount)
	unmountable=$(grep simple-mtpfs /etc/mtab 2>/dev/null)
	if [ -z "$unmountable" ]; then
	printf "exit" | rofi -config $roficonfig -dmenu -i -only-match -p "Nothing to Unmount" && exit
	else
	devices="$(awk '/simple-mtpfs/ {print $2}' /etc/mtab | rofi -config $roficonfig -dmenu -fuzzy -hover-select -i -p "Choose Device to Unmount")"
	fusermount -u $devices && printf "exit" | rofi -config $roficonfig -dmenu -i -only-match -p "Unmounted Successfully"
	fi
  rm -r "$HOME/Cell"
	;;
	Mount)
  [ -d "$mountpoint" ] || mkdir -pv "$mountpoint"
	device="$(echo "$androiddevices" | rofi -config $roficonfig -dmenu -i -hover-select -p "Choose Device")"
	simple-mtpfs --device "$device" "$mountpoint" && echo "exit" | rofi -config $roficonfig -dmenu -i -only-match -p "Mounted Successfully" && exit
	echo "Ok" | rofi -config $roficonfig -dmenu -i -p "Tap Allow on your phone, after that Enter."
	simple-mtpfs --device "$device" "$mountpoint" &&  echo "exit" | rofi -config $roficonfig -dmenu -only-match -i -p "Mounted Successfully" || echo "exit" | rofi -config $roficonfig -only-match -dmenu -i -p "Not mounted"
esac 2>/dev/null
