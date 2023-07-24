# Security Key Setup

## Hardware Setup

First, you'll need an nRF52840DK board. Other boards that Tock supports should
work though, as long as they have at least one button. You'll also need two USB
cables, one for programming the board and the other for attaching it as a USB
device.

There are a couple of configurations on the nRF52840DK board that you should
double-check. First, the "Power" switch on the top left should be set to "On".
Secondly, the "nRF power source" switch in the top middle of the board should be
set to "VDD". Finally, the "nRF ONLY | DEFAULT" switch on the bottom right
should be set to "DEFAULT".

For now, you should plug one USB cable into the top of the board for programming
(NOT into the "nRF USB" port on the side). We'll attach the other USB cable
later.

## Software Setup

If you followed the previous ["Course Setup"](course_setup.md) steps and/or the
["Getting Started" guide](https://github.com/tock/tock/blob/master/doc/Getting_Started.md)
you should have the software you need.

As a reminder though, you'll need local clones of the
[Tock repo](https://github.com/tock/tock) and the
[Libtock-C repo](https://github.com/tock/libtock-c), which hold the kernel and
C-userland applications respectively. To compile code, you'll need the Rust
toolchain and the GCC embedded C toolchain. To upload code to the board you'll
need Tockloader, a python tool created to interact with Tock boards. Finally,
you'll want a couple of terminals and whatever code editor you prefer.

## Programming the Kernel

For the first part of the tutorial, you'll need the Tock kernel loaded onto the
nRF52840DK. We'll use a special version of the board that includes some code
we'll use for the tutorial.

> **TODO**: WHAT IS THE PATH TO THE TUTORIAL nRF52840DK board in Tock?

`cd` into the proper directory, then to compile the kernel, you can just type
`make`. After that has completed, use `make flash` to upload the kernel to your
board.

If everything worked properly, you should see a message that's something like
this:

```
$ make flash
    Finished release [optimized + debuginfo] target(s) in 0.33s
   text	   data	    bss	    dec	    hex	filename
 172036	      4	  33100	 205140	  32154	/home/brghena/Dropbox/repos/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk
fbb724085db6dfd7530f792ffc50833108c5f26322f3ff9803363000439857c5  /home/brghena/Dropbox/repos/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk.bin
tockloader  flash --address 0x00000 --board nrf52dk --jlink /home/brghena/Dropbox/repos/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk.bin
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[STATUS ] Flashing binary to board...
[INFO   ] Finished in 9.444 seconds
```
