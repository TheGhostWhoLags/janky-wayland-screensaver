#!/bin/bash
#This script is designed to be called from an idle event trigger in hypridle or swayidle.  But it can be called manually by any event or trigger you would like to use.
#It spawns swayimg fullscreen to run a slideshow of images, then forks processes to monitor input from the libinput(keyboard & mouse), jstest(joypad), and the Dbus for when starting a video that puts a D-Bus inhibit lock in place (such as vacuumtube) whiie the screensaver is active.

#This file is used to indicate there is an input from one of the three listeners.  It does not matter if it already exists or has existing content - it will be overwritten each time.
TEMPFILE=/tmp/inputdetect
touch $TEMPFILE

#Start and fork swayimg.  This is the 'screensaver'.  Running it as a systemd-inhibit process stops the idle event that called this script from being triggered again while the screensaver is active.
systemd-inhibit swayimg --config-file=/home/steam/.config/swayimg/config --fullscreen --scale=fill --slideshow --order=random /home/steam/.config/wallpaper &
#I also run other applications after a 'systemd-idle' command when I don't want the screensaver to activate (i.e. Kodi which has it's own builtin screensaver for when movies aren't being played).
#You could replace it with any process you want to use as a screensaver, as long as it doesn't exit by itself without writing something to TEMPFILE when it does.

#Fork the three listeners.  When one of them detects input it writes to the temporary file, this is our trigger to cleanup and exit.
#You need to add the user calling this script to the 'input' group, or to whatever group owns the '/dev/input/*' devices on your system is if it is not 'input'
libinput debug-events | grep -m1 "KEY\|MOTION" > $TEMPFILE &
#This works for my controller.  If it doesn't for yours, run 'jstest --event /dev/input/js0' and press a few buttons to find out what event values you need in the grep statement. 
jstest --event /dev/input/js0 | grep -m1 "type 1,\|type 2," > $TEMPFILE &

#This listens to D-Bus events that might be triggered behind the scenes while the screensaver is already running.  In my case, videos started on Vacuumtube via chromecast.
#The 'org.freedesktop.ScreenSaver' string might be different in your Window Manager/Desktop Environment.  Run dbus-monitor, start playing a video, and find your needed string in the output.
dbus-monitor | grep -m1 "interface=org.freedesktop.ScreenSaver; member=Inhibit" > $TEMPFILE &

#inotifywait will block and wait until one of the listeners writes output to the temporary file.
inotifywait -e modify $TEMPFILE
sleep 0.2

#Input has been detected, it's time to clean up any forked processes still running and then kill the swayimg 'screensaver'.
pkill -f "jstest"
pkill -f "libinput"
pkill -f "dbus-monitor"
pkill -f "swayimg"
exit

#As the 'systemd-inhibit swayimg' process has now closed, there is nothing stopping the idle timer from trigging this script again on the next idle tieout.
