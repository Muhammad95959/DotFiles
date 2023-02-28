#!/usr/bin/env bash

# toggle_gaps [on|off|toggle]

INNER=10
HORIZONTAL=0

mode=$1

if [[ -z "$mode" || "$mode" == "toggle" ]]; then

	# Get current workspace.
	workspace=$(i3-msg -t get_workspaces \
			| jq -r '.[] | if .["focused"] then .["name"] else empty end')
	# Get current inner gap size. (0 means default)
	inner_gaps=$(i3-msg -t get_tree \
			| jq -r 'recurse(.nodes[]) | if .type == "workspace" and .name == "'"$workspace"'" then .gaps.inner else empty end')

	if [[	"$inner_gaps" == 0 ]]; then
		mode="off"
	else
		mode="on"
	fi
fi

if [[ "$mode" == "on" ]]; then
	i3-msg "gaps inner current set $INNER; gaps horizontal current set $HORIZONTAL"
    # killall xborders; xborders --border-rgba 61afefff --border-radius 14 --border-width 2 --disable-version-warning --border-mode inside
else
	i3-msg "gaps inner current set 0; gaps horizontal current set 0"
    # killall xborders
fi
