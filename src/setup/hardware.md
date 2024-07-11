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
On Linux, this may require some setup, see the "one-time fixups" box on the
quickstart page for your platform ([Linux](quickstart-linux.md) or
[Windows](quickstart-windows.md)].

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
