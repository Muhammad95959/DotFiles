#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Power Menu
#
## Available Styles
#
## style-1   style-2   style-3   style-4   style-5

# Current Theme
dir="$HOME/.config/rofi/scripts/powermenu/type-4"
theme='style-3'

# CMDs
uptime="$(uptime -p | sed -e 's/up //g')"

# Options
shutdown=''
reboot=''
lock=''
suspend=''
logout=''

# Rofi CMD
rofi_cmd() {
  rofi -dmenu \
    -p "Goodbye ${USER}" \
    -mesg "Uptime: $uptime" \
    -theme "${dir}"/${theme}.rasi
}

# Confirmation CMD
confirm_cmd() {
  rofi -dmenu \
    -p 'Confirmation' \
    -mesg 'Are you Sure?' \
    -theme "${dir}"/shared/confirm.rasi
}

# Pass variables to rofi dmenu
run_rofi() {
  echo -e "$lock\n$suspend\n$logout\n$reboot\n$shutdown" | rofi_cmd
}

# Execute Command
run_cmd() {
  if [[ $1 == '--shutdown' ]]; then
    systemctl poweroff
  elif [[ $1 == '--reboot' ]]; then
    systemctl reboot
  elif [[ $1 == '--suspend' ]]; then
    mpc -q pause
    amixer set Master mute
    systemctl suspend
  elif [[ $1 == '--logout' ]]; then
    if [[ "$DESKTOP_SESSION" == 'openbox' ]]; then
      openbox --exit
    elif [[ "$DESKTOP_SESSION" == 'bspwm' ]]; then
      bspc quit
    elif [[ "$DESKTOP_SESSION" == 'i3' ]]; then
      i3-msg exit
    elif [[ "$DESKTOP_SESSION" == 'dk' ]]; then
      dkcmd exit
    elif [[ "$DESKTOP_SESSION" == 'qtile' ]]; then
      qtile cmd-obj -o cmd -f shutdown
    elif [[ "$DESKTOP_SESSION" == 'plasma' ]]; then
      qdbus org.kde.ksmserver /KSMServer logout 0 0 0
    elif [[ "$DESKTOP_SESSION" == 'hyprland' ]]; then
      hyprctl dispatch exit
    else
      pkill -KILL -u "$USER"
    fi
  fi
}

# Actions
chosen="$(run_rofi)"
case ${chosen} in
"$shutdown")
  run_cmd --shutdown
  ;;
"$reboot")
  run_cmd --reboot
  ;;
"$lock")
  if [[ -x '/usr/bin/betterlockscreen' && "$XDG_SESSION_TYPE" = "x11" ]]; then
    betterlockscreen -l
  elif [[ -x '/usr/bin/i3lock' && "$XDG_SESSION_TYPE" = "x11" ]]; then
    i3lock -n -e -i /mnt/Disk_D/Backgrounds/locks/catlock.png
  elif [[ -x '/usr/bin/xfce4-screensaver' && "$XDG_SESSION_TYPE" = "x11" ]]; then
    xfce4-screensaver-command -l
  elif [[ -x '/usr/bin/hyprlock' && "$XDG_SESSION_TYPE" = "wayland" ]]; then
    hyprlock
  fi
  ;;
"$suspend")
  run_cmd --suspend
  ;;
"$logout")
  run_cmd --logout
  ;;
esac
