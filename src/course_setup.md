# Prerequisites

You should follow the [getting started guide](../getting_started.html) to get
your development setup and ensure you can communicate with the hardware.

## Hardware

![](../imgs/imix.svg)

The Tock course is currently written for an imix hardware platform. To follow
the directions directly, you will need an _imix_ hardware platform (pictured
above). Tock is a general operating system, however, and other boards _should_
work, but they might not provide the exact same hardware sensors or peripherals.

To complete the 6LoWPAN networking portion of this guide, you'll need an
additional imix to act as a hub.

## Setup to Compile and Program the Kernel

All of the hands-on exercises will be done within the source code for this book.
So pop open a terminal, and navigate to the repository. If you're using the VM,
that'll be:

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
