# Tock Course

The Tock course includes several different modules that guide you through
various aspects of Tock and Tock applications. Each module is designed to be
fairly standalone such that a full course can be composed of different modules
depending on the interests and backgrounds of those doing the course. You should
be able to do the lessons that are of interest to you.

Each module begins with a description of the lesson, and then includes steps to
follow. The modules cover both programming in the kernel as well as
applications.

## Setup and Preparation

You should follow the [getting started guide](getting_started.html) to get your
development setup and ensure you can communicate with the hardware.

### Compile the Kernel

All of the hands-on exercises will be done within the main Tock repository and
the `libtock-c` or `libtock-rs` userspace repositories. To work on the kernel,
pop open a terminal, and navigate to the repository. If you're using the VM,
that'll be:

    $ cd ~/tock

#### Make sure your Tock repository is up to date

    $ git pull

This will fetch the lastest commit from the Tock kernel repository. Individual
modules may ask you to check out specific commits or branches. In this case, be
sure to have those revisions checked out instead.

#### Build the kernel

To build the kernel for your board, navigate to the `boards/$YOUR_BOARD`
subdirectory. From within this subdirectory, a simple `make` should be
sufficient to build a kernel. For instance, for the Nordic nRF52840DK board, run
the following:

    $ cd boards/nordic/nrf52840dk
    $ make
       Compiling nrf52840 v0.1.0 (/home/tock/tock/chips/nrf52840)
       Compiling components v0.1.0 (/home/tock/tock/boards/components)
       Compiling nrf52_components v0.1.0 (/home/tock/tock/boards/nordic/nrf52_components)
        Finished release [optimized + debuginfo] target(s) in 24.07s
       text    data     bss     dec     hex filename
     167940       4   28592  196536   2ffb8 /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk
    88302039a5698ab37d159ec494524cc466a0da2e9938940d2930d582404dc67a  /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk.bin

If this is the first time you are trying to make the kernel, the build system
will use cargo and rustup to install various Tock dependencies.

### Programming the kernel and interfacing with your board

Boards may require slightly different procedures for programming the Tock
kernel.

If you are following along with the provided VM, do not forget to pass your
board's USB interface(s) to the VM. In VirtualBox, this should work by selecting
"Devices > USB" and then enabling the respective device (for example
`SEGGER J-Link [0001]`).

#### Nordic nRF52840DK

The Nordic nRF52840DK development board contains an integrated SEGGER J-Link
JTAG debugger, which can be used to program and debug the nRF52840
microcontroller. It is also connected to the nRF's UART console and exposes this
as a console device.

To flash the Tock kernel and applications through this interface, you will need
to have the SEGGER J-Link tools installed. If you are using a VM, we provide a
script you can execute to install these tools. **TODO!**

With the J-Link software installed, we can use Tockloader to flash the Tock
kernel onto this board.

    $ make install
    [INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
    [STATUS ] Flashing binary to board...
    [INFO   ] Finished in 7.645 seconds

Congrats! Tock should be running on your board now.

To verify that Tock runs, try to connect to your nRF's serial console.
Tockloader provides a `tockloader listen` command for opening a serial
connection. In case you have multiple serial devices attached to your computer,
you may need to select the appropriate J-Link device:

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

In this case, the nRF's serial console can be accessed as `/dev/ttyACM1`.
