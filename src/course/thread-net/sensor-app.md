# Writing a Temperature-Sensor App on Tock

In this stage, we write a simple application that will ask the Tock
kernel for our chip's current temperature, and then print it out on
the serial console. This demonstrates how you can compile and flash
the Tock kernel, a `libtock-c` application, alongside some important
Tock concepts.

## Compiling and Installing the Kernel

For this tutorial, we provide a Tock kernel *configuration* that
exposes all required peripherals to userspace applications. It is
based on the
[`nrf52840dk`](https://github.com/tock/tock/tree/master/boards/nordic/nrf52840dk)
base board defition and adds an additional driver instantiation for
the Ssd1306 1.3" OLED screen we are using in this tutorial.

You can compile this configuration board by entering into its
respective directory and typing `make`:

```
$ cd tock/configurations/nrf52840dk/nrf52840dk-thread-tutorial
$ make
TODO EXPECTED OUTPUT HERE
```

To flash the kernel onto your nRF52840DK development board, make sure
that you use the debug USB port (top-side, not "nRF USB"). Then type

```
$ make install
TODO EXPECTED OUTPUT HERE
```

If these commands fail, ensure that you have all of `rustup`,
`tockloader`, and the SEGGER J-Link software installed. You can test
your connection with the integrated J-Link debug probe by running:

```
$ JLinkExe
TODO EXPECTED OUTPUT HERE!
```

## Connecting to the Tock Kernel

You can connect to your board's serial console using `tockloader` or
any other serial console application. If your development board
presents two console devices, the lower-numbered one is usually
correct. Select 115200 baud, 1 stop bit, no partity, no flow
control. The following command should also do the trick:

```
tockloader listen
```

By default, a Tock board without any applications will respond with a
message similar to:

```
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$
```

If you don't see this prompt, try hitting ENTER or pressing the
`RESET` button on your board (near the left-hand side USB port). In
case you see the following selection dialog, the nRF52840DK exposes
the chip's serial console on the first UART port (e.g., `ttyACM0`
instead of `ttyACM1`). If that does not work, simply try the available
ports:

```
> tockloader listen
[INFO   ] No device name specified. Using default name "tock".
[INFO   ] No serial port with device name "tock" found.
[INFO   ] Found 2 serial ports.
Multiple serial port options found. Which would you like to use?
[0]     /dev/ttyACM1 - J-Link - CDC
[1]     /dev/ttyACM0 - J-Link - CDC

Which option? [0] 1
[INFO   ] Using "/dev/ttyACM0 - J-Link - CDC".
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$

```

The small shell above is called the "process console". It allows you
to start and stop applications, and control other parts of the tock
kernel. For instance, `reset` will completely reset your chip,
re-printing the above greeting. Use `help` to obtain a list of
commands.

> **Checkpoint:** You can interact with the process console.

## Compiling and Installing an Application

With the kernel running we can now load applications onto our
board. Tock applications are compiled and loaded separately from the
kernel. For this tutorial we will use the `libtock-c` userspace
library, whose source is located outside of the kernel repository
[here](https://github.com/tock/libtock-c).

We provide some scaffolding for this tutorial. Make sure to enter the
following directory:

```
$ cd libtock-c/examples/tutorials/thread_network
$ ls
00_sensor_hello
01_sensor_ipc
[...] TODO update directory listing!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
```

These applications represent checkpoints for different milestones of
this tutorial. If you are ever stuck on something, you can try running
or looking at the subsequent checkpoint. We'll start the tutorial off
at checkpoint `00_sensor_hello`. Whenever we reach a checkpoint, we
indicate this through a message like the following:

> **CHECKPOINT:** `00_sensor_hello`

To compile and flash this application, we enter into its directory and
run the following command:

```
$ cd 00_sensor_hello
$ make -j4 install
[...]
Application size report for arch family cortex-m:
Application size report for arch family rv32i:
   text    data     bss     dec     hex filename
   3708     204    2716    6628    19e4 build/cortex-m0/cortex-m0.elf
[...]
  13944     816   10864   25624    6418 (TOTALS)
   text    data     bss     dec     hex filename
   4248     100    2716    7064    1b98 build/rv32imac/rv32imac.0x20040080.0x80002800.elf
[...]
  51432    1000   27160   79592   136e8 (TOTALS)
[INFO   ] Using openocd channel to communicate with the board.
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[STATUS ] Installing app on the board...
[INFO   ] Flashing app org.tockos.thread-tutorial.sensor binary to board.
[INFO   ] Finished in 1.737 seconds
```

Once the binary is flashed to the board, you can connect to its serial
port using `tockloader listen`. Upon reset, the board should now greet
you:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$
TODO 00_sensor_hello_message!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
```

Congratulations, you have successfully installed and run your first
Tock application! You can manage apps installed on a board with
Tockloader. For instance, use the following commands to install, list,
and erase applications:

```
$ tockloader install            # Installs an app
$ tockloader list               # Lists installed apps
$ tockloader erase-apps         # Erases all apps
```

## Making Your First System Call

The goal of the *sensor application* is to sample this chip's internal
temperature sensor, and to provide this value to other applications
using Tock's Inter-Process Communcation facility.

However, an application in Tock runs as an unprivileged process, and
as such it does not have direct access to any chip
peripherals. Instead, the application needs to ask the Tock kernel to
perform this operation. For this, `libtock-c` provides some system
call wrappers that our application can use. These are defined in the
`libtock` folder of the `libtock-c repository`. For this particular
application, we are mainly interested in talking to Tock's sensor
driver subsystem. For this, `libtock-c/libtock/temperature.h` provides
convenient userspace wrapper functions, such as
`temperature_read_sync`:

```c
/** Initiate a synchronous ambient temperature measurement:
 *
 * temperature  - pointer/address where the result of the temperature
 *                reading should be stored
 */
int temperature_read_sync(int *temperature);
```


For now, let's focus on using the API to make a system call to read
the temperature. For this, we can extend the provided
`00_sensor_hello` application's `main.c` file with a call to that
function. Your code should invoke this function and pass it a
reference into which the temperature value will be written. You can
then extend the `printf` call to print this number.

With these changes, compile and re-install your application by running
`make install` again. Once that is done, you should see output similar
to the following:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$
TODO output !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
```

> **CHECKPOINT:** `00_sensor_ipc`

