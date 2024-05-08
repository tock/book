# Quickstart

Get started with Tock quickly! You can either install a virtual machine or setup
a local development environment.

## Option 1: Run a Virtual Machine

You can download
a virtual machine image with all of the dependencies already installed
[here](https://praxis.princeton.edu/~alevy/Tock.ova) or
[here](https://www.cs.virginia.edu/~bjc8c/archive/Tock.ova). Using `curl` to
download the image is recommended, but your browser should be able to download
it as well:

```
$ curl -O https://praxis.princeton.edu/~alevy/Tock.ova
or
$ curl -O https://www.cs.virginia.edu/~bjc8c/archive/Tock.ova
```

With the virtual machine image downloaded, you can run it with VirtualBox or
VMWare:

- VirtualBox:
  [File → Import Appliance...](https://docs.oracle.com/cd/E26217_01/E26796/html/qs-import-vm.html),
- VMWare:
  [File → Open...](https://pubs.vmware.com/workstation-9/index.jsp?topic=%2Fcom.vmware.ws.using.doc%2FGUID-DDCBE9C0-0EC9-4D09-8042-18436DA62F7A.html)

The VM account is "tock" with password "tock".

> If your Host OS is Linux, you may need to add your user to the `vboxusers`
> group on your machine in order to connect the hardware boards to the virtual
> machine.

## Option 2: Install All Tools on your Machine Locally

Install the following:

1.  Command line utilities: `curl`, `make`, `git`, `python` and `pip3`.

        # Ubuntu
        $ sudo apt install git wget zip curl python3 python3-pip python3-venv

1.  Clone the Tock kernel repository.

        $ git clone https://github.com/tock/tock

1.  [rustup](http://rustup.rs/). This tool helps manage installations of the
    Rust compiler and related tools.

        $ curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

1.  [arm-none-eabi toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads)
    and riscv64-unknown-elf toolchains. This enables you to compile apps written
    in C.

        # MacOS
        $ brew install arm-none-eabi-gcc riscv64-elf-gcc

        # Ubuntu
        $ sudo apt install gcc-arm-none-eabi gcc-riscv64-unknown-elf

1.  [tockloader](https://github.com/tock/tockloader). This is an all-in-one tool
    for programming boards and using Tock.

        $ pipx install tockloader

    > Note: You may need to add `tockloader` to your path. If you cannot run it
    > after installation, run the following:

        $ pipx ensurepath

1.  `JLinkExe` to load code onto your board. `JLink` is available [from the
    Segger website](https://www.segger.com/downloads/jlink). You want to install
    the "J-Link Software and Documentation Pack". There are various packages
    available depending on operating system.

1.  OpenOCD. Another tool to load code. You can install through package
    managers.

        # MacOS
        $ brew install open-ocd

        # Ubuntu
        $ sudo apt install openocd
