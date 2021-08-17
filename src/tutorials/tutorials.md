# Tock Mini Tutorials

These tutorials walk through how to use some various features of Tock. They are
narrower in scope than the course, but try to explain in detail how various Tock
apps work.

You will need the `libtock-c` repository to run these tutorials. You should
check out a copy of `libtock-c` by running:

    $ git clone https://github.com/tock/libtock-c

`libtock-c` contains many example Tock applications as well as the library
support code for running C and C++ apps on Tock. If you are looking to develop
Tock applications you will likely want to start with an existing app in
`libtock-c` and modify it.

## Setup

You need to be able to compile and load the Tock kernel and Tock applications.
See the [getting started guide](../getting_started.html) on how to get setup.

You also need [hardware](https://tockos.org/hardware) that supports Tock.

The tutorials assume you have a Tock kernel loaded on your hardware board. To
get a kernel installed, follow these steps.

1. **Obtain the Tock Source**. You can clone a copy of the Tock repository to
   get the kernel source:

   ```bash
   $ git clone https://github.com/tock/tock
   $ cd tock
   ```

2. **Compile Tock**. In the root of the Tock directory, compile the kernel for
   your hardware platform. You can find a list of boards by running `make list`.
   For example if your board is `imix` then:

   ```bash
   $ make list
   $ cd boards/imix
   $ make
   ```

   If you have another board just replace "imix" with `<your-board>`

   This will create binaries of the Tock kernel. Tock is compiled with Cargo, a
   package manager for Rust applications. The first time Tock is built all of
   the crates must be compiled. On subsequent builds, crates that haven't
   changed will not have to be rebuilt and the compilation will be faster.

3. **Load the Tock Kernel**. The next step is to program the Tock kernel onto
   your hardware. To load the kernel, run:

   ```bash
   $ make install
   ```

   in the board directory. Now you have the kernel loaded onto the hardware. The
   kernel configures the hardware and provides drivers for many hardware
   resources, but does not actually include any application logic. For that, we
   need to load an application.

   Note, you only need to program the kernel once. Loading applications does not
   alter the kernel, and applications can be re-programed without re-programming
   the kernel.

With the kernel setup, you are ready to try the mini tutorials.

## Tutorials

1. **[Blink an LED](01_running_blink.md)**: Get your first Tock app running.
1. **[Button to Printf()](02_button_print.md)**: Print to terminal in response
   to button presses.
1. **[BLE Advertisement Scanning](03_ble_scan.md)**: Sense nearby BLE packets.
1. **[Sample Sensors and Use Drivers](04_sensors_and_drivers.md)**: Use syscalls
   to interact with kernel drivers.
1. **[Inter-process Communication](05_ipc.md)**: Tock's IPC mechanism.

### Board compatiblity matrix

| Tutorial # | Supported boards          |
| ---------- | ------------------------- |
| 1          | All                       |
| 2          | All Cortex-M based boards |
| 3          | Hail and imix             |
| 4          | Hail and imix             |
| 5          | All that support IPC      |
