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

## Connecting to the Tock kernel

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
OUTPUT
```

If you don't see this prompt, try hitting ENTER. This small shell is
called the "process console". It allows you to start and stop
applications, and control other parts of the tock kernel. For
instance, `reset` will completely reset your chip, re-printing the
above greeting.

> **Checkpoint:** You can interact with the process console.
