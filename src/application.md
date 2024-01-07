# Write an Environmental Sensing Application

To start we will focus on creating a sensing application that can collect data
by reading sensors.

## Setup

You will need the `libtock` library to provide the library functions for calling
system calls provided by the Tock kernel. We will use `libtock-c`, which you can
clone:

```
git clone https://github.com/tock/libtock-c
```

Make sure you can compile an application:

```
cd libtock-c/examples/blink
make
```

## Create a `Hello World` Application

Create a new folder in the `libtock-c/examples` folder called `simsense`. Copy
the `Makefile` from the blink app.

```
cd examples
mkdir simsense
cp blink/Makefile simsense
```

Now create `main.c` in `simsense/` and create a basic hello world application:

```c
#include <stdio.h>

int main(void) {
  printf("Hello, World!\n");
}
```

> ### Background on `printf()`
>
> The code uses the standard C library routine `printf` to compose a message
> using a format string and print it to the console. Let's break down what the
> code layers are here:
>
> 1. `printf()` is provided by the C standard library (implemented by
>    [newlib](https://sourceware.org/newlib/)). It takes the format string and
>    arguments, and generates an output string from them. To actually write the
>    string to standard out, `printf` calls `_write`.
> 2. `_write` (in `libtock-c`'s
>    [`sys.c`](https://github.com/tock/libtock-c/tree/master/libtock/sys.c)) is
>    a wrapper for actually writing to output streams (in this case, standard
>    out a.k.a. the console). It calls the Tock-specific console writing
>    function `putnstr`.
> 3. `putnstr`(in `libtock-c`'s
>    [`console.c`](https://github.com/tock/libtock-c/tree/master/libtock/console.c))
>    is a buffers data to be written, calls `putnstr_async`, and acts as a
>    synchronous wrapper, yielding until the operation is complete.
> 4. Finally, `putnstr_async` (in `libtock-c`'s
>    [`console.c`](https://github.com/tock/libtock-c/tree/master/libtock/console.c))
>    performs the actual system calls, calling to `allow`, `subscribe`, and
>    `command` to enable the kernel to access the buffer, request a callback
>    when the write is complete, and begin the write operation respectively.
>
> The application could accomplish all of this by invoking Tock system calls
> directly, but using libraries makes for a much cleaner interface and allows
> users to not need to know the inner workings of the OS.

### Loading the Application

Okay, let's build and load this simple program.

1. Erase all other applications from the development board:

   ```
   tockloader erase-apps
   ```

2. Build the application and load it (Note: `tockloader install` automatically
   searches the current working directory and its subdirectories for Tock
   binaries.)

   ```
   make
   tockloader install
   ```

3. Check that it worked with a separate terminal:

   ```
   tockloader listen
   ```

   The output should look something like:

   ```
   $ tockloader listen
   No device name specified. Using default "tock"
   Using "/dev/cu.usbserial-c098e5130012 - Hail IoT Module - TockOS"

   Listening for serial output.
   Hello, World!
   ```

> **Checkpoint:** You can compile and run your own Hello World app.

## Discovering Sensors

Now we want to go beyond printing fixed strings and sample onboard sensors.
Because Tock separates apps from the kernel, an application doesn't necessarily
know which sensors are available. To start, we will test for various sensors and
see which are available.

> ### Background
>
> Tock apps use system calls to communicate with the kernel. Drivers for various
> kernel drivers (e.g. accessing sensors, controlling LEDs, or printing serial
> messages) are identified by a `DRIVER_NUM`. Apps can then call `Command`s for
> each driver, where commands are identified by a `COMMAND_NUM`.
>
> To aid with discovery, `COMMAND_NUM == 0` is reserved as an existence check.
> Userspace apps can call a `Command` syscall with the `COMMAND_NUM` of 0 and
> check the return value. If `SUCCESS`, that driver exists.

### Check for Ambient Light Sensor

Let's start by checking if our board has an ambient light sensor. The library
interface for
[ambient light](https://github.com/tock/libtock-c/blob/master/libtock/ambient_light.h)
is in the `libtock-c/libtock` folder.

We can use the `ambient_light_exists()` function. In main.c of our simsense app:

```c
#include <stdio.h>
#include <ambient_light.h>

int main(void) {
  printf("Checking for ambient light sensor.\n");

  printf("Ambient Light: ");
  if (ambient_light_exists()) {
    printf("Exists!\n");
  } else {
    printf("Does not exist.\n");
  }
}
```

Compile and run your updated app.

> **Tip:** To see which apps are loaded on a board, run `tockloader list`.

> **Checkpoint:** You can check if you have an ambient light sensor. What is the
> result for your hardware?

### Check for Additional Sensors

The next step is to check for other sensor types (you might not have a light
sensor). Expand your application to check for other sensors. Some you might use:

- [Temperature](https://github.com/tock/libtock-c/blob/master/libtock/temperature.h)
- [Humidity](https://github.com/tock/libtock-c/blob/master/libtock/humidity.h)
- [Sound Pressure](https://github.com/tock/libtock-c/blob/master/libtock/sound_pressure.h)
- [Pressure](https://github.com/tock/libtock-c/blob/master/libtock/pressure.h)

> **Checkpoint:** Your app now checks for the presence of several sensors. Which
> are available on your board?

## Sampling Data from Available Sensors

Now that we know which sensors are available, we want to get data from the
sensors that exist.

Use the libtock libraries to sample the sensors. For simplicity, you want to use
the functions which end in `_sync` so you can avoid writing the asynchronous
code.

Print the readings to the serial console. As a starting point, consider the
following code:

```c
int take_measurement(void) {
  int val;
  int ret;

  ret = sensor_sample_sync(&val);
  if (ret == RETURNCODE_SUCCESS) {
    printf("Sensor Reading: %d\n", val);
  }
}
```

### Example: Ambient Light

The interface in `libtock/ambient_light.h` is used to measure ambient light
conditions in [lux](https://en.wikipedia.org/wiki/Lux). imix uses the
[ISL29035](https://www.intersil.com/en/products/optoelectronics/ambient-light-sensors/light-to-digital-sensors/ISL29035.html)
sensor, but the userland library is abstracted from the details of particular
sensors. It contains the function:

```c
#include <ambient_light.h>
int ambient_light_read_intensity_sync(int* lux);
```

Note that the light reading is written to the location passed as an argument,
and the function returns non-zero in the case of an error.

### Example: Temperature

The interface in `libtock/temperature.h` is used to measure ambient temperature
in degrees Celsius, times 100. imix uses the
[SI7021](https://www.silabs.com/products/sensors/humidity-sensors/Pages/si7013-20-21.aspx)
sensor. It contains the function:

```c
#include <temperature.h>
int temperature_read_sync(int* temperature);
```

Again, this function returns non-zero in the case of an error.

> **Checkpoint:** Your app prints readings from all available sensors.

## Take Multiple Readings

Finally to complete our sensor we want to take multiple sensor readings. Put
your sampling code in a loop. Use the `delay_ms()` function to sample only
periodically.

You'll find the interface for timers in `libtock/timer.h`. The function you'll
find useful today is:

```c
#include <timer.h>
void delay_ms(uint32_t ms);
```

This function sleeps until the specified number of milliseconds have passed, and
then returns. So we call this function "synchronous": no further code will run
until the delay is complete.

An example loop structure:

```c
int main(void) {
  while (1) {
    take_measurement();
    delay_ms(2000);
  }
}
```

> **Checkpoint:** You app prints readings from each sensors multiple times.

## Blink the LED on Samples

To be able to see if our device is sampling periodically without observing the
console output, we will add an LED toggle on each sample. This is
straightforward in Tock:

```c
#include <led.h>

int main(void) {
  while (1) {
    take_measurement();
    led_toggle(0);
    delay_ms(2000);
  }
}
```

> **Checkpoint:** You have an environmental sensing application!
