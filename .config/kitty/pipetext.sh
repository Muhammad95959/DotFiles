#!/bin/sh

[ -n "$TMUX" ] && tmux capture-pane -J -p -S - >/tmp/kitty_content.txt

nvim /tmp/kitty_content.txt
