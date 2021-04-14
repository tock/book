# Getting Started

This getting started guide covers how to get started using Tock.

## Hardware

To really be able to use Tock and get a feel for the operating system, you will
need a hardware platform that tock supports. The [TockOs
Hardware](https://www.tockos.org/hardware/) includes a list of supported
hardware boards. You can also view the [boards
folder](https://github.com/tock/tock/tree/master/boards) to see what platforms
are supported.

As of February 2021, this getting started guide is based around five hardware
platforms. Steps for each of these platforms are explicitly described here.
Other platforms will work for Tock, but you may need to reference the README
files in `tock/boards/` for specific setup information. The five boards are:

- Hail
- imix
- nRF52840dk (PCA10056)
- Arduino Nano 33 BLE (regular or Sense version)
- BBC Micro:bit v2

These boards are reasonably well supported, but note that others in Tock may
have some "quirks" around what is implemented (or not), and exactly how to load
code and test that it is working. This guides tries to be general, and Tock
generally tries to follow a certain convention, but the project is under active
development and new boards are added rapidly. You should definitely consult the
board-specific README to see if there are any board-specific details you should
be aware of.

## Host Machine Setup

You can either download a [virtual machine](#virtual-machine) with the
development environment pre-installed, or, if you have a Linux or OS X
workstation, you may install the development environment
[natively](#native-installation). Using a virtual machine is quicker and easier
to set up, while installing natively will yield the most comfortable development
environment and is better for long term use.

### Virtual Machine

If you're comfortable working inside a Debian virtual machine, you can download
an image with all of the dependencies already installed
[here](https://praxis.princeton.edu/~alevy/Tock.ova) or
[here](https://www.cs.virginia.edu/~bjc8c/archive/Tock.ova). Using `curl` to
download the image is recommended, but your browser should be able to download
it as well:

    $ curl -O <url>

With the virtual machine image downloaded, you can run it with VirtualBox or
VMWare:

 * VirtualBox users: [File → Import Appliance...](https://docs.oracle.com/cd/E26217_01/E26796/html/qs-import-vm.html),
 * VMWare users: [File → Open...](https://pubs.vmware.com/workstation-9/index.jsp?topic=%2Fcom.vmware.ws.using.doc%2FGUID-DDCBE9C0-0EC9-4D09-8042-18436DA62F7A.html)

The VM account is "tock" with password "tock". Feel free to customize it with
whichever editors, window managers, etc. you like before the training starts.

> If the Host OS is Linux, you may need to add your user to the `vboxusers`
> group on your machine in order to connect the hardware boards to the virtual
> machine.

### Native Installation

If you choose to install the development environment natively on an existing
operating system install, you will need the following software:

1. Command line utilities: `curl`, `make`, `git`, `python` (version 3) and `pip3`.

1. Clone the Tock kernel repository.

        $ git clone https://github.com/tock/tock

1. [rustup](http://rustup.rs/). This tool helps manage installations of the
   Rust compiler and related tools.

        $ curl https://sh.rustup.rs -sSf | sh

1. [arm-none-eabi
   toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads)
   (version >= 5.2). This enables you to compile apps written in C for Cortex-M
   boards.

        # mac
        $ brew tap ARMmbed/homebrew-formulae && brew update && brew install arm-none-eabi-gcc

        # linux
        $ sudo apt install gcc-arm-none-eabi

1. [riscv64-unknown-elf toolchain](https://www.sifive.com/boards) (version >=
   v2019.08.0). Scroll down to the "Prebuilt RISC‑V GCC Toolchain" section. This
   enables you to compile apps written in C for RISC-V boards.

        # mac
        $ brew tap riscv/riscv && brew install riscv-gnu-toolchain --with-multilib

1. [tockloader](https://github.com/tock/tockloader). This is an all-in-one tool
   for programming boards and using Tock.

        $ pip3 install -U --user tockloader

    > Note: On MacOS, you may need to add `tockloader` to your path. If you
    > cannot run it after installation, run the following:

        $ export PATH=$HOME/Library/Python/3.6/bin/:$PATH

    > Similarly, on Linux distributions, this will typically install to
    > `$HOME/.local/bin`, and you may need to add that to your `$PATH` if not
    > already present:

        $ PATH=$HOME/.local/bin:$PATH


### Testing You Can Compile the Kernel

To test if your environment is working enough to compile Tock, go to the
`tock/boards/` directory and then to the board folder for the hardware you have
(e.g. `tock/boards/imix` for imix). Then run `make` in that directory. This
should compile the kernel. It may need to compile several supporting libraries
first (so may take 30 seconds or so the first time). You should see output like
this:

```
$ cd tock/boards/imix
$ make
   Compiling tock-cells v0.1.0 (/Users/bradjc/git/tock/libraries/tock-cells)
   Compiling tock-registers v0.5.0 (/Users/bradjc/git/tock/libraries/tock-register-interface)
   Compiling enum_primitive v0.1.0 (/Users/bradjc/git/tock/libraries/enum_primitive)
   Compiling tock-rt0 v0.1.0 (/Users/bradjc/git/tock/libraries/tock-rt0)
   Compiling imix v0.1.0 (/Users/bradjc/git/tock/boards/imix)
   Compiling kernel v0.1.0 (/Users/bradjc/git/tock/kernel)
   Compiling cortexm v0.1.0 (/Users/bradjc/git/tock/arch/cortex-m)
   Compiling capsules v0.1.0 (/Users/bradjc/git/tock/capsules)
   Compiling cortexm4 v0.1.0 (/Users/bradjc/git/tock/arch/cortex-m4)
   Compiling sam4l v0.1.0 (/Users/bradjc/git/tock/chips/sam4l)
   Compiling components v0.1.0 (/Users/bradjc/git/tock/boards/components)
    Finished release [optimized + debuginfo] target(s) in 28.67s
   text    data     bss     dec     hex filename
 165376    3272   54072  222720   36600 /Users/bradjc/git/tock/target/thumbv7em-none-eabi/release/imix
   Compiling typenum v1.11.2
   Compiling byteorder v1.3.4
   Compiling byte-tools v0.3.1
   Compiling fake-simd v0.1.2
   Compiling opaque-debug v0.2.3
   Compiling block-padding v0.1.5
   Compiling generic-array v0.12.3
   Compiling block-buffer v0.7.3
   Compiling digest v0.8.1
   Compiling sha2 v0.8.1
   Compiling sha256sum v0.1.0 (/Users/bradjc/git/tock/tools/sha256sum)
6fa1b0d8e224e775d08e8b58c6c521c7b51fb0332b0ab5031fdec2bd612c907f  /Users/bradjc/git/tock/target/thumbv7em-none-eabi/release/imix.bin
```

You can check that tockloader is installed by running:

```
$ tockloader --help
```

If either of these steps fail, please double check that you followed the
environment setup instructions above.

## Getting the Hardware Connected and Setup

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
> - nRF52 development boards: Use the port of the left, on the skinny side of
>   the board.

The board should appear as a regular serial device (e.g.
`/dev/tty.usbserial-c098e5130006` on my Mac or `/dev/ttyUSB0` on my Linux box).
This may require some setup, see the "one-time fixups" box.

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
> - With a virtual machine, you might need to attach the USB device to the
>   VM. To do so, after plugging in the board, select in the VirtualBox/VMWare
>   menu bar:
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
> - With Windows Subsystem for Linux (WSL), the serial device parameters stored in
>   the FTDI chip do not seem to get passed to Ubuntu. Plus, WSL enumerates
>   every possible serial device. Therefore, tockloader cannot automatically
>   guess which serial port is the correct one, and there are a lot to choose
>   from.
>
>   You will need to open Device Manager on Windows, and find which `COM` port
>   the tock board is using. It will likely be called "USB Serial Port" and be
>   listed as an FTDI device. The COM number will match what is used in WSL.
>   For example, `COM9` is `/dev/ttyS9` on WSL.
>
>   To use tockloader you should be able to specify the port manually. For example:
>   `tockloader --port /dev/ttyS9 list`.


### One Time Board Setup

If you have a **Hail**, **imix**, or **nRF52840dk** please skip to the next
section.

If you have an **Arduino Nano 33 BLE** (sense or regular), you need to update
the bootloader on the board to the Tock bootloader. Please follow the
[bootloader update
instructions](https://github.com/tock/tock/tree/master/boards/nano33ble#getting-started).

If you have a **Micro:bit v2** then you need to load the Tock booloader. Please
follow the [bootloader installation
instructions](https://github.com/tock/tock/tree/master/boards/microbit_v2).


### Test The Board

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


### Flash the kernel

Now that the board is connected and you have verified that the kernel compiles
(from the steps above), we can flash the board with the latest Tock kernel:

    $ cd boards/<your board>
    $ make

Generally boards are programmed with either `make program` or `make flash`. Try
`make program` first:

    $ make program

If that is not available, you can use `make flash`:

    $ make flash

You can also look at the board's README for more details.

> #### Why both `make program` and `make flash`?
>
> While these commands do the same thing, the way they go about it is very
> different.
>
> The `make program` version communicates with the board via a serial connection
> and a bootloader running on the board. You may need to manually enter the
> bootloader when using `make program`.
>
> The `make flash` version uses a JTAG debugger to communicate with the chip and
> flash the kernel binary directly to the chip.


### Install Some Applications

We have the kernel flashed, but the kernel doesn't actually _do_ anything.
Applications do! To load applications, we are going to use tockloader.

#### Loading Pre-built Applications

We're going to install some pre-built applications, but first, let's make sure
we're in a clean state, in case your board already has some applications
installed. This command removes any processes that may have already been
installed.

    $ tockloader erase-apps

Now, let's install two pre-compiled example apps. Remember, you may need to
specify which board you are using and how to communicate with it for all of
these commands. If you are using Hail or imix you will not have to.

    $ tockloader install https://www.tockos.org/assets/tabs/blink.tab

> The `install` subcommand takes a path or URL to an TAB (Tock Application
> Binary) file to install.

The board should restart and the user LED should start blinking. Let's also
install a simple "Hello World" application:

    $ tockloader install https://www.tockos.org/assets/tabs/c_hello.tab

If you now run `tockloader listen` you should be able to see the output of the
Hello World! application. You may need to manually reset the board for this to
happen.

    $ tockloader listen
    [INFO   ] No device name specified. Using default name "tock".
    [INFO   ] Using "/dev/cu.usbserial-c098e513000a - Hail IoT Module - TockOS".

    [INFO   ] Listening for serial output.
    Initialization complete. Entering main loop.
    Hello World!
    ␀


#### Uninstalling and Installing More Apps

Lets check what's on the board right now:

    $ tockloader list
    ...
    ┌──────────────────────────────────────────────────┐
    │ App 0                                            |
    └──────────────────────────────────────────────────┘
      Name:                  blink
      Enabled:               True
      Sticky:                False
      Total Size in Flash:   2048 bytes


    ┌──────────────────────────────────────────────────┐
    │ App 1                                            |
    └──────────────────────────────────────────────────┘
      Name:                  c_hello
      Enabled:               True
      Sticky:                False
      Total Size in Flash:   1024 bytes


    [INFO   ] Finished in 2.939 seconds


As you can see, the apps are still installed on the board. We can remove apps
with the following command:

    $ tockloader uninstall

Following the prompt, if you remove the `blink` app, the LED will stop blinking,
however the console will still print `Hello World`.

Now let's try adding a more interesting app:

    $ tockloader install https://www.tockos.org/assets/tabs/sensors.tab

The `sensors` app will automatically discover all available sensors, sample them
once a second, and print the results.

    $ tockloader listen
    [INFO   ] No device name specified. Using default name "tock".
    [INFO   ] Using "/dev/cu.usbserial-c098e513000a - Hail IoT Module - TockOS".

    [INFO   ] Listening for serial output.
    Initialization complete. Entering main loop.
    [Sensors] Starting Sensors App.
    Hello World!
    ␀[Sensors] All available sensors on the platform will be sampled.
    ISL29035:   Light Intensity: 218
    Temperature:                 28 deg C
    Humidity:                    42%
    FXOS8700CQ: X:               -112
    FXOS8700CQ: Y:               23
    FXOS8700CQ: Z:               987



#### Compiling and Loading Applications

There are many more example applications in the `libtock-c` repository that you
can use. Let's try installing the ROT13 cipher pair. These two applications use
inter-process communication (IPC) to implement a [ROT13
cipher](https://en.wikipedia.org/wiki/ROT13).

Start by uninstalling any applications:

    $ tockloader uninstall

Get the libtock-c repository:

    $ git clone https://github.com/tock/libtock-c

Build the rot13_client application and install it:

    $ cd libtock-c/examples/rot13_client
    $ make
    $ tockloader install

Then make and install the rot13_service application:

    $ cd ../rot13_service
    $ tockloader install --make

Then you should be able to see the output:

    $ tockloader listen
    [INFO   ] No device name specified. Using default name "tock".
    [INFO   ] Using "/dev/cu.usbserial-c098e5130152 - Hail IoT Module - TockOS".
    [INFO   ] Listening for serial output.
    Initialization complete. Entering main loop.
    12: Uryyb Jbeyq!
    12: Hello World!
    12: Uryyb Jbeyq!
    12: Hello World!
    12: Uryyb Jbeyq!
    12: Hello World!
    12: Uryyb Jbeyq!
    12: Hello World!

> Note: Tock platforms are limited in the number of apps they can load and run.
> However, it is possible to install more apps than this limit, since tockloader
> is (currently) unaware of this limitation and will allow to you to load
> additional apps. However the kernel will only load the first apps until the
> limit is reached.

#### Note about Identifying Boards

Tockloader tries to automatically identify which board is attached to make this
process simple. This means for many boards (particularly the ones listed at the
top of this guide) tockloader should "just work".

However, for some boards tockloader does not have a good way to identify which
board is attached, and requires that you manually specify which board you are
trying to program. This can be done with the `--board` argument. For example, if
you have an nrf52dk or nrf52840dk, you would run Tockloader like:

    $ tockloader <command> --board nrf52dk --jlink

The `--jlink` flag tells tockloader to use the JLink JTAG tool to communicate
with the board (this mirrors using `make flash` above). Some boards support
OpenOCD, in which case you would pass `--openocd` instead.

To see a list of boards that tockloader supports, you can run `tockloader
list-known-boards`. If you have an imix or Hail board, you should not need to
specify the board.

> Note, a board listed in `tockloader list-known-boards` means there are default
> settings hardcoded into tockloader's source on how to support those boards.
> However, all of those settings can be passed in via command-line parameters
> for boards that tockloader does not know about. See `tockloader --help` for
> more information.


## Familiarize Yourself with `tockloader` Commands

The `tockloader` tool is a useful and versatile tool for managing and installing
applications on Tock. It supports a number of commands, and a more complete list
can be found in the tockloader repository, located at
[github.com/tock/tockloader](https://github.com/tock/tockloader#usage). Below is
a list of the more useful and important commands for programming and querying a
board.

### `tockloader install`

This is the main tockloader command, used to load Tock applications onto a
board.  By default, `tockloader install` adds the new application, but does not
erase any others, replacing any already existing application with the same name.
Use the `--no-replace` flag to install multiple copies of the same app. To
install an app, either specify the `tab` file as an argument, or navigate to the
app's source directory, build it (probably using `make`), then issue the install
command:

    $ tockloader install

> *Tip:* You can add the `--make` flag to have tockloader automatically
> run make before installing, i.e. `tockloader install --make`

> *Tip:* You can add the `--erase` flag to have tockloader automatically
> remove other applications when installing a new one.

### `tockloader uninstall [application name(s)]`
Removes one or more applications from the board by name.

### `tockloader erase-apps`
Removes all applications from the board.

### `tockloader list`
Prints basic information about the apps currently loaded onto the board.

### `tockloader info`
Shows all properties of the board, including information about currently
loaded applications, their sizes and versions, and any set attributes.

### `tockloader listen`
This command prints output from Tock apps to the terminal. It listens via UART,
and will print out anything written to stdout/stderr from a board.

> *Tip:* As a long-running command, `listen` interacts with other tockloader
> sessions. You can leave a terminal window open and listening. If another
> tockloader process needs access to the board (e.g. to install an app update),
> tockloader will automatically pause and resume listening.

### `tockloader flash`
Loads binaries onto hardware platforms that are running a compatible bootloader.
This is used by the Tock Make system when kernel binaries are programmed to the
board with `make program`.
