# Reading Sensors From Scratch

> Note! This tutorial will only work on boards with a light sensor.

In this tutorial we will cover how to use the syscall interface from
applications to kernel drivers, and guide things based on reading a light sensor
and printing the readings over UART.

> **Note**: This example demonstrates using the low-level system call interface
> directly to read a sensor. In general, we would not write applications this
> way. However, this tutorial serves as an illustrative guide for learning more
> about the Tock system call interface. See the fourth step for the conventional
> approach.

OK, lets get started.

1. **Setup a generic app for handling asynchronous events**. As with most
   sensors, the light sensor is read asynchronously, and a callback is generated
   from the kernel to userspace when the reading is ready. Therefore, to use
   this sensor, our application needs to do two things: 1) setup a callback the
   kernel driver can call when the reading is ready, and 2) instruct the kernel
   driver to start the measurement. Lets first sketch this out:

   ```c
   #include <libtock/tock.h>

   #define DRIVER_NUM 0x60002

   // Callback when the light sensor has a light intensity measurement ready.
   static void light_callback(int intensity, int unused1, int unused2, void* ud) {

   }

   int main() {
       // Tell the kernel about the callback.

       // Instruct the light sensor driver to begin a reading.

       // Wait until the reading is complete.

       // Print the resulting value.

       return 0;
   }
   ```

2. **Fill in the application with syscalls**. The standard
   [Tock syscalls](../development/syscall.md) can be used to actually implement
   the sketch we made above. We first use the `subscribe` syscall to inform the
   kernel about the callback in our application. We then use the `command`
   syscall to start the measurement. To wait, we use the `yield` call to wait
   for the callback to actually fire. We do not need to use `allow` for this
   application, and typically it is not required for reading sensors.

   For all syscalls that interact with drivers, the major number is set by the
   platform. In the case of the light sensor, it is `0x60002`. The minor numbers
   are set by the driver and are specific to the particular driver.

   To save the value from the callback to use in the print statement, we will
   store it in a global variable.

   ```c
   #include <stdio.h>

   #include <libtock/tock.h>

   #define DRIVER_NUM 0x60002

   static int sensor_reading;

   // Callback when the light sensor has a light intensity measurement ready.
   static void light_callback(int intensity, int unused1, int unused2, void* ud) {
       // Save the reading when the callback fires.
       sensor_reading = intensity;
   }

   int main() {
       // Tell the kernel about the callback.
       subscribe(DRIVER_NUM, 0, light_callback, NULL);

       // Instruct the light sensor driver to begin a reading.
       command(DRIVER_NUM, 1, 0, 0);

       // Wait until the reading is complete.
       yield();

       // Print the resulting value.
       printf("Light sensor reading: %d\n", sensor_reading);

       return 0;
   }
   ```

3. **Be smarter about waiting for the callback**. While the above application
   works, it's really relying on the fact that we are only sampling a single
   sensor. In the current setup, if instead we had two sensors with outstanding
   commands, the first callback that fired would trigger the `yield()` call to
   return and then the `printf()` would execute. If, for example, sampling the
   light sensor takes 100 ms, and the new sensor only needs 10 ms, the new
   sensor's callback would fire first and the `printf()` would execute with an
   incorrect value.

   To handle this, we can instead use the `yield_for()` call, which takes a flag
   and only returns when that flag has been set. We can then set this flag in
   the callback to make sure that our `printf()` only occurs when the light
   reading has completed.

   ```c
   #include <stdio.h>
   #include <stdbool.h>

   #include <libtock/tock.h>

   #define DRIVER_NUM 0x60002

   static int sensor_reading;
   static bool sensor_done = false;

   // Callback when the light sensor has a light intensity measurement ready.
   static void light_callback(int intensity, int unused1, int unused2, void* ud) {
       // Save the reading when the callback fires.
       sensor_reading = intensity;

       // Mark our flag true so that the `yield_for()` returns.
       sensor_done = true;
   }

   int main() {
       // Tell the kernel about the callback.
       subscribe(DRIVER_NUM, 0, light_callback, NULL);

       // Instruct the light sensor driver to begin a reading.
       command(DRIVER_NUM, 1, 0, 0);

       // Wait until the reading is complete.
       yield_for(&sensor_done);

       // Print the resulting value.
       printf("Light sensor reading: %d\n", sensor_reading);

       return 0;
   }
   ```

4. **Use the `libtock` library functions**. Normally, applications don't use the
   bare `command` and `subscribe` syscalls. Typically, these are wrapped
   together into helpful commands inside of `libtock` and `libtock-sync` and
   come with a function that hides the `yield_for()` to a make a synchronous
   function which is useful for developing applications quickly. Lets port the
   light sensing app to use the Tock Standard Library:

   ```c
   #include <stdio.h>

   #include <libtock-sync/sensors/ambient_light.h>

   int main() {
       // Take the light sensor measurement synchronously.
       int sensor_reading;
       libtocksync_ambient_light_read_intensity(&sensor_reading);

       // Print the resulting value.
       printf("Light sensor reading: %d\n", sensor_reading);

       return 0;
   }
   ```

5. **Explore more sensors**. This tutorial highlights only one sensor. See the
   [sensors](https://github.com/tock/libtock-c/tree/master/examples/sensors) app
   for a more complete sensing application.
