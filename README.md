A screensaver for my 'steambox'; a minimal hyprland setup that automatically runs Steam from hyprland.conf on login.

It launches swayimg pointed at a directory of images that are displayed as a slideshow (you can replace this with anything you like), spawns processes to listen for input (keyboard, mouse, gamepad, and DBus), and then kills all the child processes as the script exits after input is detected.

The script is launched by an idle timeout in my setup.
