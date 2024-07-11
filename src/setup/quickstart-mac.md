# Quickstart: Mac

This guide assumes you have the [Homebrew](https://brew.sh/) package manager
installed.

Install the following:

1.  Command line utilities.

        $ brew install wget pipx git coreutils

1.  Clone the Tock kernel repository.

        $ git clone https://github.com/tock/tock

1.  [rustup](http://rustup.rs/). This tool helps manage installations of the
    Rust compiler and related tools.

        $ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

1.  [arm-none-eabi toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads)
    and riscv64-unknown-elf toolchains. This enables you to compile apps written
    in C.

        $ brew install arm-none-eabi-gcc riscv64-elf-gcc

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

        $ brew install open-ocd
