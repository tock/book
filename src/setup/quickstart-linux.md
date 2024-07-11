# Quickstart: Linux

Install the following:

1.  Command line utilities.

        $ sudo apt install git wget zip curl python3 python3-pip python3-venv

1.  Clone the Tock kernel repository.

        $ git clone https://github.com/tock/tock

1.  [rustup](http://rustup.rs/). This tool helps manage installations of the
    Rust compiler and related tools.

        $ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

1.  [arm-none-eabi toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads)
    and riscv64-unknown-elf toolchains. This enables you to compile apps written
    in C.

        $ sudo apt install gcc-arm-none-eabi gcc-riscv64-unknown-elf

1.  [tockloader](https://github.com/tock/tockloader). This is an all-in-one tool
    for programming boards and using Tock.

        $ pipx install tockloader

    > Note: You may need to add `tockloader` to your path. If you cannot run it
    > after installation, run the following:

        $ pipx ensurepath

1.  `JLinkExe` to load code onto your board. `JLink` is available
    [from the Segger website](https://www.segger.com/downloads/jlink). You want
    to install the "J-Link Software and Documentation Pack". There are various
    packages available depending on operating system.

1.  OpenOCD. Another tool to load code. You can install through package
    managers.

        $ sudo apt install openocd

> #### One-Time Fixups
>
> On Linux, you might need to give your user access to the serial port used by
> the board. If you get permission errors or you cannot access the serial port,
> this is likely the issue.
>
> You can fix this by setting up a udev rule to set the permissions correctly
> for the serial device when it is attached. You only need to run the command
> below for your specific board, but if you don't know which one to use, running
> both is totally fine, and will set things up in case you get a different
> hardware board!
>
>     $ sudo bash -c "echo 'ATTRS{idVendor}==\"0403\", ATTRS{idProduct}==\"6015\", MODE=\"0666\"' > /etc/udev/rules.d/99-ftdi.rules"
>     $ sudo bash -c "echo 'ATTRS{idVendor}==\"2341\", ATTRS{idProduct}==\"005a\", MODE=\"0666\"' > /etc/udev/rules.d/98-arduino.rules"
>
> Afterwards, detach and re-attach the board to reload the rule.
