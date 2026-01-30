#!/bin/bash
#This script is designed to be called from an idle event trigger in hypridle or swayidle.  But it can be called manually or by any event or trigger you would like to use.
#It spawns swayimg fullscreen to run a slideshow of images, then forks processes to monitor input from the libinput(keyboard & mouse), jstest(joypad), and the Dbus for any new inhibit locks whiie the screensaver is already active.

#This file is used to indicate there is an input from one of the three listeners.  It does not matter if it already exists or has existing content - it will be overwritten each time.
TEMPFILE=/tmp/inputdetect
touch $TEMPFILE

#Start and fork swayimg.  This is the 'screensaver'.  Running it in systemd-inhibit stops the idle event that called this script from being triggered again while the screensaver is active.
#You could replace it with any process you want to use as a screensaver as long as it doesn't exit by itself without writing something to TEMPFILE.
systemd-inhibit swayimg --config-file=/home/steam/.config/swayimg/config --fullscreen --scale=fill --slideshow --order=random /home/steam/.config/wallpaper &

#Create and fork the listeners.  When one of them detects input it writes to the temporary file that inotifywait is watching.
#You need to add the user calling this script to the 'input' group, or to whatever group owns the '/dev/input/*' devices on your system is if it is not 'input'.
libinput debug-events | grep -m1 "KEY\|MOTION" > $TEMPFILE &
#This works for my controller.  If it doesn't for yours, run 'jstest --event /dev/input/js0' and press a few buttons to find out what event labels you need in the grep statement. 
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
pkill -f "swayimg" #As the systemd-inhibit/swayimg process has now closed, the idle timer can call this script again on the next idle timeout.
exit
