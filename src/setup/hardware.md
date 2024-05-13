# Getting the Hardware Connected and Setup

Plug your hardware board into your computer. Generally this requires a micro USB
cable, but your board may be different.

> #### Note! Some boards have multiple USB ports.
>
> Some boards have two USB ports, where one is generally for debugging, and the
> other allows the board to act as any USB peripheral. You will want to connect
> using the "debug" port.
>
> Some example boards:
>
> - imix: Use the port labeled `DEBUG`.
> - nRF52 development boards: Use the port on the skinny side of the board (do
>   NOT use the port labeled "nRF USB").

The board should appear as a regular serial device (e.g.
`/dev/tty.usbserial-c098e5130006` on my Mac or `/dev/ttyUSB0` on my Linux box).
This may require some setup, see the "one-time fixups" box.

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
> - On Linux, you might need to give your user access to the serial port used by
>   the board. If you get permission errors or you cannot access the serial
>   port, this is likely the issue.
>
>   You can fix this by setting up a udev rule to set the permissions correctly
>   for the serial device when it is attached. You only need to run the command
>   below for your specific board, but if you don't know which one to use,
>   running both is totally fine, and will set things up in case you get a
>   different hardware board!
>
>       $ sudo bash -c "echo 'ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6015\", MODE=\"0666\"' > /etc/udev/rules.d/99-ftdi.rules"
>       $ sudo bash -c "echo 'ATTRS{idVendor}==\"2341\", ATTRS{idProduct}==\"005a\", MODE=\"0666\"' > /etc/udev/rules.d/98-arduino.rules"
>
>   Afterwards, detach and re-attach the board to reload the rule.
>
> - With a virtual machine, you might need to attach the USB device to the VM.
>   To do so, after plugging in the board, select in the VirtualBox/VMWare menu
>   bar:
>
>       Devices -> USB Devices -> [The name of your board]
>
>   If you aren't sure which board to select, it is often easiest to unplug and
>   re-plug the board and see which entry is removed and then added.
>
>   If this generates an error, often unplugging/replugging fixes it. You can
>   also create a rule in the VM USB settings which will auto-attach the board
>   to the VM.
>
> - With Windows Subsystem for Linux (WSL), the serial device parameters stored
>   in the FTDI chip do not seem to get passed to Ubuntu. Plus, WSL enumerates
>   every possible serial device. Therefore, tockloader cannot automatically
>   guess which serial port is the correct one, and there are a lot to choose
>   from.
>
>   You will need to open Device Manager on Windows, and find which `COM` port
>   the tock board is using. It will likely be called "USB Serial Port" and be
>   listed as an FTDI device. The COM number will match what is used in WSL. For
>   example, `COM9` is `/dev/ttyS9` on WSL.
>
>   To use tockloader you should be able to specify the port manually. For
>   example: `tockloader --port /dev/ttyS9 list`.

## One Time Board Setup

If you have a **Hail**, **imix**, or **nRF52840dk** please skip to the next
section.

If you have an **Arduino Nano 33 BLE** (sense or regular), you need to update
the bootloader on the board to the Tock bootloader. Please follow the
[bootloader update instructions](https://github.com/tock/tock/tree/master/boards/nano33ble#getting-started).

If you have a **Micro:bit v2** then you need to load the Tock bootloader. Please
follow the
[bootloader installation instructions](https://github.com/tock/tock/tree/master/boards/microbit_v2).

## Test The Board

With the board connected, you should be able to use tockloader to interact with
the board. For example, to retrieve serial UART data from the board, run
`tockloader listen`, and you should see something like:

    $ tockloader listen
    No device name specified. Using default "tock"
    Using "/dev/ttyUSB0 - Imix - TockOS"

    Listening for serial output.
    Initialization complete. Entering main loop

You may also need to reset (by pressing the reset button on the board) the board
to see the message. You may also not see any output if the Tock kernel has not
been flashed yet.

In case you have multiple serial devices attached to your computer, you may need
to select the appropriate J-Link device:

    $ tockloader listen
    [INFO   ] No device name specified. Using default name "tock".
    [INFO   ] No serial port with device name "tock" found.
    [INFO   ] Found 2 serial ports.
    Multiple serial port options found. Which would you like to use?
    [0]     /dev/ttyACM1 - J-Link - CDC
    [1]     /dev/ttyACM0 - L830-EB - Fibocom L830-EB

    Which option? [0] 0
    [INFO   ] Using "/dev/ttyACM1 - J-Link - CDC".
    [INFO   ] Listening for serial output.
    Initialization complete. Entering main loop
    NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
    tock$

In case you don't see any text printed after "Listening for serial output", try
hitting `[ENTER]` a few times. You should be greeted with a `tock$` shell
prompt. You can use the `reset` command to restart your nRF chip and see the
above greeting.

In case you want to use a different serial console monitor, you may need to
identify the serial console device created for your board. On Linux, you can
identify the J-Link debugger's serial port by running:

    $ dmesg -Hw | grep tty
    < ... some output ... >
    < plug in the nRF52840DKs front USB (not "nRF USB") >
    [  +0.003233] cdc_acm 1-3:1.0: ttyACM1: USB ACM device

In this case, the serial console can be accessed as `/dev/ttyACM1`.

You can also see if any applications are installed with `tockloader list`:

    $ tockloader list
    [INFO   ] No device name specified. Using default name "tock".
    [INFO   ] Using "/dev/cu.usbmodem14101 - Nano 33 BLE - TockOS".
    [INFO   ] Paused an active tockloader listen in another session.
    [INFO   ] Waiting for the bootloader to start
    [INFO   ] No found apps.
    [INFO   ] Finished in 2.928 seconds
    [INFO   ] Resumed other tockloader listen session

If these commands fail you may not have installed Tockloader, or you may need to
update to a later version of Tockloader. There may be other issues as well, and
you can ask on
[Slack](https://join.slack.com/t/tockos/shared_invite/enQtNDE5ODQyNDU4NTE1LWVjNTgzMTMwYzA1NDI1MjExZjljMjFmOTMxMGIwOGJlMjk0ZTI4YzY0NTYzNWM0ZmJmZGFjYmY5MTJiMDBlOTk)
if you need help.
