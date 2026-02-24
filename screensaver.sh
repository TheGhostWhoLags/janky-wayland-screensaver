#!/bin/bash
#This script is designed to be called from an idle event trigger in hypridle or swayidle.  But it can be called manually or by any event or trigger you would like to use.
#It spawns swayimg fullscreen to run a slideshow of images, then forks processes to monitor input from the libinput(keyboard & mouse), jstest(joypad), and the Dbus for new inhibit events while the screensaver is active.

#This file is used to indicate there is an input from one of the three listeners.
TEMPFILE=/tmp/inputdetect

#TEMPFILE is also used as a lock file.  If it already exists we will assume a copy of this script is currently running and exit.
if [ -f $TEMPFILE ]; then
  exit 1
fi

#Create the TEMPFILE to act as a lockfile and ready for results from the input detection processes.
touch $TEMPFILE

#This causes any forked child processes to be killed when this script exits.  Since the screensaver app and input detectors are all forked, they all get cleaned up automatically. 
trap 'pkill --signal SIGTERM --parent $$' EXIT

#Start and fork swayimg.  This is the 'screensaver'.
#You could replace it with any process you want to use as a screensaver, as long as it doesn't exit by itself without writing something to TEMPFILE.
swayimg --fullscreen --scale=fill --slideshow --order=random /home/steam/.config/wallpaper &

#Create and fork the listeners.  When one of them detects input it writes to the TEMPFILE that inotifywait will be watching.
#You need to add the user calling this script to the 'input' group, or to whatever group owns the '/dev/input/*' devices on your system is if that is not 'input'.
libinput debug-events | grep -m1 "KEY\|MOTION" > $TEMPFILE &
#This works for my controller.  If it doesn't for yours, run 'jstest --event /dev/input/js0' and press a few buttons to find out what event labels you need in the grep statement. 
jstest --event /dev/input/js0 | grep -m1 "type 1,\|type 2," > $TEMPFILE &
#Listen for D-Bus events triggered behind the scenes while the screensaver is already running.  In my case, videos started on Vacuumtube via chromecast.
#The 'org.freedesktop.ScreenSaver' string might be different in your Window Manager/Desktop Environment.  Run dbus-monitor, start playing a video, and find your needed string in the output.
dbus-monitor | grep -m1 "interface=org.freedesktop.ScreenSaver; member=Inhibit" > $TEMPFILE &

#inotifywait will block and wait until one of the listeners writes output to the temporary file.
#'systemd-inhibit --what=idle' stops the idle event that called this script from being triggered again while the screensaver is active.  It will probably block other idle triggers you have set from firing as well.  You don't need it if you depend on the conditional check for the existance of TEMPFILE at the start of this script.
systemd-inhibit --what=idle inotifywait -e modify $TEMPFILE
rm $TEMPFILE #TEMPFILE must be deleted or the conditional check at the start of this script will prevent it from running again.
exit
