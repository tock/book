# Installing Tock Applications

We have the kernel flashed, but the kernel doesn't actually _do_ anything.
Applications do! To load applications, we are going to use tockloader.

## Loading Pre-built Applications

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

## Uninstalling and Installing More Apps

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

## Compiling and Loading Applications

There are many more example applications in the `libtock-c` repository that you
can use. Let's try installing the ROT13 cipher pair. These two applications use
inter-process communication (IPC) to implement a
[ROT13 cipher](https://en.wikipedia.org/wiki/ROT13).

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

## Note about Identifying Boards

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

To see a list of boards that tockloader supports, you can run
`tockloader list-known-boards`. If you have an imix or Hail board, you should
not need to specify the board.

> Note, a board listed in `tockloader list-known-boards` means there are default
> settings hardcoded into tockloader's source on how to support those boards.
> However, all of those settings can be passed in via command-line parameters
> for boards that tockloader does not know about. See `tockloader --help` for
> more information.
