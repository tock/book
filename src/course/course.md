# Tock Course

The Tock course includes several different modules that guide you through
various aspects of Tock and Tock applications. Each module is designed to be
fairly standalone such that a full course can be composed of different modules
depending on the interests and backgrounds of those doing the course. You should
be able to do the lessons that are of interest to you.

Each module begins with a description of the lesson, and then includes steps to
follow. The modules cover both programming in the kernel as well as
applications.

## Setup and Preparation

You should follow the [getting started guide](../getting_started.html) to get
your development setup and ensure you can communicate with the hardware.

### Compile the Kernel

All of the hands-on exercises will be done within the main Tock repository and
the `libtock-c` or `libtock-rs` userspace repositories. To work on the kernel,
pop open a terminal, and navigate to the repository. If you're using the VM,
that'll be:

    $ cd ~/tock

#### Make sure your Tock repository is up to date

    $ git pull

This will fetch the lastest commit from the Tock kernel repository. Individual
modules may ask you to check out specific commits or branches. In this case, be
sure to have those revisions checked out instead.

#### Build the kernel

To build the kernel for your board, navigate to the `boards/$YOUR_BOARD`
subdirectory. From within this subdirectory, a simple `make` should be
sufficient to build a kernel. For instance, for the Nordic nRF52840DK board, run
the following:

    $ cd boards/nordic/nrf52840dk
    $ make
       Compiling nrf52840 v0.1.0 (/home/tock/tock/chips/nrf52840)
       Compiling components v0.1.0 (/home/tock/tock/boards/components)
       Compiling nrf52_components v0.1.0 (/home/tock/tock/boards/nordic/nrf52_components)
        Finished release [optimized + debuginfo] target(s) in 24.07s
       text    data     bss     dec     hex filename
     167940       4   28592  196536   2ffb8 /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk
    88302039a5698ab37d159ec494524cc466a0da2e9938940d2930d582404dc67a  /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk.bin

If this is the first time you are trying to make the kernel, the build system
will use cargo and rustup to install various Tock dependencies.

### Programming the kernel and interfacing with your board

Boards may require slightly different procedures for programming the Tock
kernel.

If you are following along with the provided VM, do not forget to pass your
board's USB interface(s) to the VM. In VirtualBox, this should work by selecting
"Devices > USB" and then enabling the respective device (for example
`SEGGER J-Link [0001]`).
