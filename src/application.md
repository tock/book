# Write an environment sensing application

## Process overview, relocation model and system call API

In this section, we're going to learn about processes (a.k.a applications) in
Tock, and build our own applications in C.

## Get a C application running on your board

You'll find the outline of a C application in the directory
`exercises/app`.

Take a look at the code in `main.c`. So far, this application merely prints
"Hello, World!".

The code uses the standard C library routine `printf` to compose a message
using a format string and print it to the console. Let's break down what the
code layers are here:

1. `printf` is provided by the C standard library (implemented by
   [newlib](https://sourceware.org/newlib/)). It takes the format string and
   arguments, and generates an output string from them. To actually write the
   string to standard out, `printf` calls `_write`.

2. `_write` (in `libtock-c`'s
   [`sys.c`](https://github.com/tock/libtock-c/tree/master/libtock/sys.c)) is a
   wrapper for actually writing to output streams (in this case, standard out
   a.k.a. the console). It calls the Tock-specific console writing function
   `putnstr`.

3. `putnstr`(in `libtock-c`'s
   [`console.c`](https://github.com/tock/libtock-c/tree/master/libtock/console.c))
   is a buffers data to be written, calls `putnstr_async`, and acts as a
   synchronous wrapper, yielding until the operation is complete.

4. Finally, `putnstr_async` (in `libtock-c`'s
   [`console.c`](https://github.com/tock/libtock-c/tree/master/libtock/console.c))
  performs the actual system calls, calling to `allow`, `subscribe`, and
  `command` to enable the kernel to access the buffer, request a callback when
  the write is complete, and begin the write operation respectively.


The application could accomplish all of this by invoking Tock system calls
directly, but using libraries makes for a much cleaner interface and allows
users to not need to know the inner workings of the OS.


### Loading an application

Okay, let's build and load this simple program.

1. Erase all other applications from the development board:

        $ tockloader erase-apps

3. Build the application and load it (Note: `tockloader install` automatically searches the
   current working directory and its subdirectories for Tock binaries.)

        $ tockloader install --make

4. Check that it worked:

        $ tockloader listen

The output should look something like:

```
$ tockloader listen
No device name specified. Using default "tock"
Using "/dev/cu.usbserial-c098e5130012 - Hail IoT Module - TockOS"

Listening for serial output.
Hello, World!
```

## Creating your own application

Now that you've got a basic app working, modify it so that it continuously
prints out `Hello World` twice per second.  You'll want to use the user
library's timer facilities to manage this:

### Timer

You'll find the interface for timers in `libtock/timer.h`. The
function you'll find useful today is:

```c
#include <timer.h>
void delay_ms(uint32_t ms);
```

This function sleeps until the specified number of milliseconds have passed, and
then returns.  So we call this function "synchronous": no further code will run
until the delay is complete.

## Write an app that periodically samples the on-board sensors

Now that we have the ability to write applications, let's do something a little
more complex. The development board you are using has several sensors on it.
These sensors include a light sensor, a humidity sensor, and a temperature
sensor. Each sensing medium can be accessed separately via the Tock user
library. We'll just be using the light and temperature for this excercise.

#### Light

The interface in `libtock/ambient_light.h` is used to measure ambient
light conditions in [lux](https://en.wikipedia.org/wiki/Lux). imix uses the
[ISL29035](https://www.intersil.com/en/products/optoelectronics/ambient-light-sensors/light-to-digital-sensors/ISL29035.html)
sensor, but the userland library is abstracted from the details of particular
sensors.  It contains the function:

```c
#include <ambient_light.h>
int ambient_light_read_intensity_sync(int* lux);
```

Note that the light reading is written to the location passed as an
argument, and the function returns non-zero in the case of an error.

#### Temperature

The interface in `libtock/temperature.h` is used to measure ambient
temperature in degrees Celsius, times 100. imix uses the
[SI7021](https://www.silabs.com/products/sensors/humidity-sensors/Pages/si7013-20-21.aspx)
sensor. It contains the function:

```c
#include <temperature.h>
int temperature_read_sync(int* temperature);
```

Again, this function returns non-zero in the case of an error.

### Read sensors in a Tock application

Using the example program you're working on, write an application that reads
all of the sensors on your development board and reports their readings over
the serial port.

As a bonus, experiment with toggling an LED when readings are above or below a
certain threshold:

#### LED

The interface in `libtock/led.h` is used to control lights on Tock boards. On the Hail
board, there are three LEDs which can be controlled: Red, Blue, and Green. The
functions in the LED module are:

```c
#include <led.h>
int led_count(void);
```

Which returns the number of LEDs available on the board.

```c
int led_on(int led_num);
```

Which turns an LED on, accessed by its number.

```c
int led_off(int led_num);
```

Which turns an LED off, accessed by its number.

```c
int led_toggle(int led_num);
```

Which toggles the state of an LED, accessed by its number.

