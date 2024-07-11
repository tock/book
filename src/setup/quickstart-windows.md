# Quickstart: Windows

> Note: This is a work in progress. Any contributions are welcome!

We use WSL on Windows for Tock.

## Install Tools

## Configure WSL To Use USB

## On Windows Subsystem for Linux (WSL)

Programming JLink devices with Tock in WSL:

Trying to program an nRF52840DK with WSL can be a little tricky because WSL
abstracts away low level access for USB devices. WSL1 does not offer access to
physical hardware, just an environment to use linux on microsoft. WSL2 on the
other hand is unable to find JLink devices even if you have JLink installed
because of the USB abstraction. To get around this limitation, we use USBIP - a
tool that connects the USB device over a TCP tunnel.

This guide might apply for any device programmed via JLink.

Steps to connect to nRF52840DK with WSL:

1. Get Ubuntu 22.04 from Microsoft store. Install it as a WSL distro with
   `wsl --install -d Ubuntu-22.04` using Windows Powershell or Cmd prompt with
   admin privileges.

2. Once Ubuntu 22.04 is installed, the Ubuntu 20.04 distro that ships as default
   with WSL must be uninstalled. Set the 22.04 distro as the WSL default by with
   the `wsl --setdefault Ubuntu-22.04` command.

3. Install JLink's linux package from their website on your WSL linux distro.
   You may need to modify jlink rules to allow JLink to access the nRF52840DK.
   This can be done with `sudo nano /etc/udev/rules.d/99-jlink.rules` and adding
   `SUBSYSTEM=="tty", ATTRS{idVendor}=="1051", MODE="0666", GROUP="dialout"` to
   the file.

4. Next, the udev rules have to be reloaded and triggered with
   `sudo udevadm control --reload-rules && udevadm trigger`. Doing this should
   apply the new rules.

5. On the windows platform, make sure WSL is set to version 2. Check the WSL
   version with `wsl -l -v`. If it is version 1, change it to WSL2 with
   `wsl --set-version Ubuntu-22.04 2` (USBIP works with WSL2).

6. Install USBIP from
   [here](https://github.com/dorssel/usbipd-win/releases/tag/v4.1.0). Version
   4.x onwards removes USBIP tooling requirement from the client side, so you
   don't have to install anything on the linux subsystem.

7. On windows, open powershell/cmd in admin mode and run `usbipd wsl list`. That
   should give you the list of devices. Note the Bus ID of your J-Link device.

8. For the first time that you want to attach your device, you need to bind the
   bus between the host OS and the WSL using `usbipd bind -b <bus-id>`.

9. Once bound, you can attach your device to WSL by running
   `usbipd attach --wsl -b <busid>` on powershell/cmd (When attaching a device
   for the first time, it has to be done with admin privileges).

10. To check if the attach worked, run `lsusb` on WSL. If it worked, the device
    should be listed as `SEGGER JLink`.

11. The kernel can now be flashed with `make install` and other tockloader
    commands should work.

> #### Note:
>
> - A machine with an x64 processor is required. (x86 and Arm64 are currently
>   not supported with USBIP).
> - Make sure your firewall is not blocking port 3240 as USBIP uses that port to
>   interface windows and WSL. (Windows defender is usually the culprit if you
>   don't have a third party firewall).
> - Add an inbound rule to Windows defender/ your third party firewall allowing
>   USBIP to use port 3240 if you see a port blocked error.

> #### One-Time Fixups
>
> The serial device parameters stored in the FTDI chip do not seem to get passed
> to Ubuntu. Plus, WSL enumerates every possible serial device. Therefore,
> tockloader cannot automatically guess which serial port is the correct one,
> and there are a lot to choose from.
>
> You will need to open Device Manager on Windows, and find which `COM` port the
> tock board is using. It will likely be called "USB Serial Port" and be listed
> as an FTDI device. The COM number will match what is used in WSL. For example,
> `COM9` is `/dev/ttyS9` on WSL.
>
> To use tockloader you should be able to specify the port manually. For
> example: `tockloader --port /dev/ttyS9 list`.
