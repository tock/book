# Environment

The goal of this part of the course is to make sure you have a working
development environment for Tock.

During this portion of the course you will:

- Get a high-level overview of how Tock works.
- Learn how to compile and flash the kernel onto an Imix board.

## Compile and program the kernel

All of the hands-on exercises will be done within the source code for this
book. So pop open a terminal, and navigate to the repository. If you're using
the VM, that'll be:

    $ cd ~/book

### Make sure your Tock repository is up to date

    $ git pull

### Build the kernel

To build the kernel, just type make in the `imix/` subdirectory.

    $ cd imix/
    $ make

If this is the first time you are trying to make the kernel, the build system
will use cargo and rustup to install various Tock dependencies.

If this is your first time building a Tock kernel for this particular
architecture, you may get an error complaining that you don't have the proper
the `cargo` target installed. We can use `rustup` to fix that:

    $ rustup target add thumbv7em-none-eabi 

> `imix` is based around an ARM Cortex-M4 microcontroller, which uses the
> thumbv7em instruction set. The rustup command above just downloads Rust core
> libraries for this architecture.

### Connect to an imix board

> #### One-Time Fixups
>
> * On Linux, you might need to give your user access to the imix's serial port.
>   If you are using the VM, this is already done for you.
>   You can do this by adding a udev rule:
>
>       $ sudo bash -c "echo 'ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6015\", MODE=\"0666\"' > /etc/udev/rules.d/99-imix"
>
>   Afterwards, detach and re-attach the imix to reload the rule.
>
> * With the virtual machine, you might need to attach the USB device to the
>   VM. To do so, after plugging in imix, select in the VirtualBox/VMWare menu bar:
>
>       Devices -> USB Devices -> imix IoT Module - TockOS
>
>   If this generates an error, often unplugging/replugging fixes it. You can also
>   create a rule in the VM USB settings which will auto-attach the imix to the VM.

To connect your development machine to the imix, connect them with a micro-USB
cable. Any cable will do, but notice that there are two USB ports on the imix.
Make sure you connect to the micro-USB port labeled 'debug' on the imix.

The imix board should appear as a regular serial device (e.g.
`/dev/tty.usbserial-c098e5130006` on my Mac and `/dev/ttyUSB0` on my Linux box).
While you can connect with any standard serial program (set to 115200 baud),
tockloader makes this easier. Tockloader can read attributes from connected
serial devices, and will automatically find your connected imix. Simply run:

    $ tockloader listen
    No device name specified. Using default "tock"
    Using "/dev/ttyUSB0 - Imix - TockOS"

    Listening for serial output.
    Initialization complete. Entering main loop
    Hello World!

### Flash the kernel

Now that the imix board is connected and you have verified that the kernel
compiles, we can flash the imix board with the latest Tock kernel:

    $ cd imix/
    $ make program

This command will compile the kernel if needed, and then use `tockloader` to
flash it onto the imix.

### Install some applications

We have the kernel flashed, but the kernel doesn't actually _do_ anything.
Applications do! We're going to install some pre-built applications, but first,
let's make sure we're in a clean state, in case your imix already had some
applications installed.

    $ tockloader erase-apps

This command removes any processes that may have already been installed.

Now, let's install two pre-compiled example apps.

    $ tockloader install https://www.tockos.org/assets/tabs/blink.tab

The board should restart and the user LED should start blinking. Let's also
install a simple "Hello World" application:

    $ tockloader install https://www.tockos.org/assets/tabs/c_hello.tab

> The `install` subcommand takes a path or URL to an TAB (Tock Application Binary) file to install.

### Clear out the applications and re-flash the test app.

Lets check what's on the board right now:

    $ tockloader list
    ...
    [App 0]
      Name:                  blink
      Enabled:               True
      Sticky:                False
      Total Size in Flash:   2048 bytes

    [App 1]
      Name:                  c_hello
      Enabled:               True
      Sticky:                False
      Total Size in Flash:   1024 bytes


As you can see, the old apps are still installed on the board.
This also nicely demonstrates that user applications are isolated from the
kernel: it is possible to update one independently of the other.
We can remove apps with the following command:

    $ tockloader uninstall

Following the prompt, if you remove the `blink` app, the LED will stop
blinking, however the console will still print `Hello World`.

Now let's try adding a more interesting app:

    $ tockloader install https://www.tockos.org/assets/tabs/sensors.tab

The `sensors` app will automatically discover all available sensors,
sample them once a second, and print the results.

    Listening for serial output.
    Starting process console
    Initialization complete. Entering main loop
    [Sensors] Starting Sensors App.
    Hello World!
    [Sensors] All available sensors on the platform will be sampled.
    ISL29035:   Light Intensity: 453
    Temperature:                 24 deg C
    Humidity:                    63%

    ISL29035:   Light Intensity: 453
    Temperature:                 24 deg C
    Humidity:                    63%


## Familiarize yourself with `tockloader` commands
The `tockloader` tool is a useful and versatile tool for managing and installing
applications on Tock. It supports a number of commands, and a more complete
list can be found in the tockloader repository, located at
[github.com/tock/tockloader](https://github.com/tock/tockloader#usage).
Below is a list of the more useful and important commands for programming and
querying a board.

### `tockloader install`

This is the main tockloader command, used to load Tock applications onto a
board.  By default, `tockloader install` adds the new application, but does not
erase any others, replacing any already existing application with the same
name.  Use the `--no-replace` flag to install multiple copies of the same app.
In order to install an app, either specify the `tab` file as an argument, or
navigate to the app's source directory, build it (probably using `make`), then
issue the install command:

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

## Explore other example applications

Other applications can be found in the `examples` subdirectory of the libtock-c repository:

    $ git clone https://github.com/tock/libtock-c

Try loading them on your imix and then try modifying them. By default,
`tockloader install` adds the new application, but does not erase any others.
Be aware, not all applications will work well together if they need the same
resources (Tock is in active development to add virtualization to all resources
to remove this issue!).

**Note:** By default, the imix platform is limited to only running four
concurrent processes at once. Tockloader is (currently) unaware of this
limitation, and will allow to you to load additional apps. However the kernel
will only load the first four apps. One option for the free-form section at the
end of the tutorial will be to explore this limitation and allow more apps.
