# Writing a Temperature-Sensor App on Tock

In this stage, we write a simple application that will ask the Tock kernel for
our chip's current temperature and then print this value to the serial console.
By the end of this submodule, you will know how to:

1. Compile and flash the Tock kernel.
2. Compile and flash a `libtock-c` application.
3. Interact with the tock process console.
4. Interact with Tock syscalls.

## Compiling and Installing the Kernel

For this tutorial, we provide a Tock kernel _configuration_ that exposes all
required peripherals to userspace applications. It is based on the
[`nrf52840dk`](https://github.com/tock/tock/tree/master/boards/nordic/nrf52840dk)
base board defition and adds an additional driver instantiation for the Ssd1306
1.3" OLED screen we are using in this tutorial.

You can compile this configuration board by entering into its respective
directory and typing `make`:

```
$ cd tock/boards/tutorials/nrf52840dk-thread-tutorial
$ make
   [...]
   Compiling nrf52_components v0.1.0 (/home/leons/proj/tock/kernel/boards/nordic/nrf52_components)
   Compiling nrf52840dk v0.1.0 (/home/leons/proj/tock/kernel/boards/nordic/nrf52840dk)
    Finished `release` profile [optimized + debuginfo] target(s) in 11.09s
   text    data     bss     dec     hex filename
 233474      36   41448  274958   4320e tock/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial
cb0df7abb1...d47b383aaf  tock/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial.bin
```

To flash the kernel onto your nRF52840DK development board, make sure that you
use the debug USB port (top-side, not "nRF USB"). Then type

```
$ make install
tockloader  flash --address 0x00000 --board nrf52dk --jlink tock/kernel/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial.bin
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[STATUS ] Flashing binary to board...
[INFO   ] Finished in 9.901 seconds
```

If these commands fail, ensure that you have all of `rustup`, `tockloader`, and
the SEGGER J-Link software installed. You can test your connection with the
integrated J-Link debug probe by running:

```
$ JLinkExe
SEGGER J-Link Commander V7.94a (Compiled Dec  6 2023 16:07:30)
DLL version V7.94a, compiled Dec  6 2023 16:07:07

Connecting to J-Link via USB...O.K.
Firmware: J-Link OB-SAM3U128-V2-NordicSemi compiled Oct 30 2023 12:12:17
Hardware version: V1.00
J-Link uptime (since boot): 0d 00h 39m 40s
S/N: 683487279
License(s): RDI, FlashBP, FlashDL, JFlash, GDB
USB speed mode: High speed (480 MBit/s)
VTref=3.300V
```

## Connecting to the Tock Kernel

You can connect to your board's serial console using `tockloader` or any other
serial console application. If your development board presents two console
devices, the lower-numbered one is usually correct. Select 115200 baud, 1 stop
bit, no partity, no flow control. The following command should also do the
trick:

```
$ tockloader listen
```

By default, a Tock board without any applications will respond with a message
similar to:

```
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$
```

If you don't see this prompt, try hitting ENTER or pressing the `RESET` button
on your board (near the left-hand side USB port). In case you see the following
selection dialog, the nRF52840DK exposes the chip's serial console on the first
UART port (e.g., `ttyACM0` instead of `ttyACM1`). If that does not work, simply
try the available ports:

```
$ tockloader listen
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

The small shell above is called the "process console". It allows you to start
and stop applications, and control other parts of the tock kernel. For instance,
`reset` will completely reset your chip, re-printing the above greeting. Use
`help` to obtain a list of commands.

> **CHECKPOINT:** You can interact with the process console.

## Compiling and Installing an Application

With the kernel running we can now load applications onto our board. Tock
applications are compiled and loaded separately from the kernel. For this
tutorial we will use the `libtock-c` userspace library, whose source is located
outside of the kernel repository [here](https://github.com/tock/libtock-c).

We provide some scaffolding for this tutorial. Make sure to enter the following
directory:

```
$ cd libtock-c/examples/tutorials/thread_network
$ ls
00_sensor_hello
01_sensor_final
[...]
```

These applications represent checkpoints for different milestones of this
tutorial. If you are ever stuck on something, you can try running or looking at
the subsequent checkpoint. We'll start the tutorial off at checkpoint
`00_sensor_hello`. Whenever we reach a checkpoint, we indicate this through a
message like the following:

> **CHECKPOINT:** `00_sensor_hello`

To compile and flash this application, we enter into its directory and run the
following command:

```
$ cd 00_sensor_hello
$ make -j install
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

Once the binary is flashed to the board, you can connect to its serial port
using `tockloader listen`. Upon reset, the board should now greet you:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
Hello World!
tock$
```

Congratulations, you have successfully installed and run your first Tock
application! You can manage apps installed on a board with Tockloader. For
instance, use the following commands to install, list, and erase applications:

```
$ tockloader install            # Installs an app
$ tockloader list               # Lists installed apps
$ tockloader erase-apps         # Erases all apps
```

## Making Your First System Call

The goal of the _sensor application_ is to sample this chip's internal
temperature sensor.

However, an application in Tock runs as an unprivileged process, and as such it
does not have direct access to any chip peripherals. Instead, the application
needs to ask the Tock kernel to perform this operation. For this, `libtock-c`
provides some system call wrappers that our application can use. These are
defined in the `libtock` folder of the `libtock-c repository`. For this
particular application, we are mainly interested in talking to Tock's sensor
driver subsystem. For this, `libtock-c/libtock-sync/sensors/temperature.h`
provides convenient userspace wrapper functions, such as
`libtocksync_temperature_read`:

```c
#include <libtock-sync/sensors/temperature.h>

// Read the temperature sensor synchronously.
//
// ## Arguments
//
// - `temperature`: Set to the temperature value in hundredths of degrees
//   centigrade.
//
// ## Return Value
//
// A returncode indicating whether the temperature read was completed
// successfully.
returncode_t libtocksync_temperature_read(int* temperature);
```

For now, let's focus on using the API to make a system call to read the
temperature. For this, we can extend the provided `00_sensor_hello`
application's `main.c` file with a call to that function. Your code should
invoke this function and pass it a reference into which the temperature value
will be written. You can then extend the `printf` call to print this number.
Note, the temperature sensor syscall returns a value of the form 2200 for a
temperature of 22C. You will need to format your temperature reading
appropriately.

With these changes, compile and re-install your application by running
`make install` again. Once that is done, you should see output similar to the
following:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAC0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
Hello World, the temperature is: 22.00
tock$
```

> **CHECKPOINT:** `01_sensor_temperature`

Congratulations! We now have a `libtock-c` application that is able to read the
nRF52840 internal temperature sensor. Now, we expand this to read the
temperature sensor continuously.

Given that temperatures change gradually, it is reasonable to read our
temperature sensor once per second. `libtock-c` provides a convient method to
delay for a specified duration in `libtock-c/libtock-sync/services/alarm.h`:

```
/** \brief Blocks for the given amount of time in milliseconds.
 *
 * This is a blocking version of `libtock_alarm_in_ms`. Instead of calling a user
 * specified callback, it blocks the current call-stack.
 *
 * \param ms the number of milliseconds to delay for.
 * \return An error code. Either RETURNCODE_SUCCESS or RETURNCODE_FAIL.
 */
int libtocksync_alarm_delay_ms(uint32_t ms);
```

> **EXERCISE** Read the temperature sensor once per second and print the
> temperature value.

If you have implemented this correctly, you should see the following output:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
Current temperature: 22.25
tock$ Current temperature: 22.25
Current temperature: 22.25
Current temperature: 22.25

```

To confirm that your sensor is working, try placing your finger on the nRF52840
SoC (this is located above the 4 buttons and in the center of the white box on
the nRF52840dk). You should see the temperature change as the temperature sensor
we are using is the "on-dye" temperature sensor.

> **CHECKPOINT:** `02_sensor_final`

This concludes the sensor module. Before continuing, please uninstall the sensor
app using the following tockloader command:

```
$ tockloader erase-apps
```

Now that we are able to read the temperature, we now continue on to network our
mote using Tock's supported OpenThread stack [here](comms-app.md).
