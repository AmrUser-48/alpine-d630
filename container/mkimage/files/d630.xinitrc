#!/bin/sh
[ -r "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
exec dwm
