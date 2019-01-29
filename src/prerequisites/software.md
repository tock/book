# Software

You can either download a [virtual machine](#virtual-machine) with all
development environment pre-installed, or, if you have a Linux or OS X
workstation, you may install the development environment
[natively](#native-installation). Using a virtual machine is quicker and easier
to set up, while installing natively will yield the most comfortable
development environment and is better for long term use.

## Virtual Machine

If you're comfortable working inside a Debian virtual machine, you can download
an image with all of the dependencies already installed
[here](http://www.scs.stanford.edu/~alevy/Tock.ova)

 * VirtualBox users: [File → Import Appliance...](https://docs.oracle.com/cd/E26217_01/E26796/html/qs-import-vm.html),
 * VMWare users: [File → Open...](https://pubs.vmware.com/workstation-9/index.jsp?topic=%2Fcom.vmware.ws.using.doc%2FGUID-DDCBE9C0-0EC9-4D09-8042-18436DA62F7A.html)

The VM account is "user" with password "user". Feel free to customize it with
whichever editors, window managers, etc. you like before the training starts.

> If the Host OS is Linux, you may need to add your user to the `vboxusers`
> group on your machine in order to connect the hardware boards to the virtual
> machine.

## Native Installation

If you choose to install the development environment natively, you will need
the following software:

1. Command line utilities: curl, make, git

1. Python 3 and pip3

1. A local clone of the Tock repository

        $ git clone https://github.com/tock/tock.git

1. A local clone of the Tock applications repository (for apps written in C)

        $ git clone https://github.com/tock/libtock-c.git

1. [rustup](http://rustup.rs/). This tool helps manage installations of the
   Rust compiler and related tools.

        $ curl https://sh.rustup.rs -sSf | sh

1. [arm-none-eabi toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads) (version >= 5.2)

   OS-specific installation instructions can be found
   [here](https://github.com/tock/tock/blob/master/doc/Getting_Started.md#arm-none-eabi-toolchain)

1. [tockloader](https://github.com/tock/tockloader)

        $ pip3 install -U --user tockloader

    > Note: On MacOS, you may need to add `tockloader` to your path. If you
    > cannot run it after installation, run the following:

        $ export PATH=$HOME/Library/Python/3.6/bin/:$PATH

    > Similarly, on Linux distributions, this will typically install to
    > `$HOME/.local/bin`, and you may need to add that to your `$PATH` if not
    > already present:

        $ PATH=$HOME/.local/bin:$PATH


### Testing

To verify you have everything installed correctly,
[hop back over to the testing directions in the main README](README.md#testing).

## Testing

To test if your environment is working, go to the `tock/boards/imix` directory
and type `make program`. This should compile the kernel for the default board,
Imix, and try to program it over a USB serial connection. It may need to compile
several supporting libraries first (so may take 30 seconds or so the first
time). You should see output like this:

```
$ make flash
   Compiling tock-registers v0.2.0 (file:///Users/bradjc/git/tock/libraries/tock-register-interface)
   Compiling tock-cells v0.1.0 (file:///Users/bradjc/git/tock/libraries/tock-cells)
   Compiling enum_primitive v0.1.0 (file:///Users/bradjc/git/tock/libraries/enum_primitive)
   Compiling imix v0.1.0 (file:///Users/bradjc/git/tock/boards/imix)
   Compiling kernel v0.1.0 (file:///Users/bradjc/git/tock/kernel)
   Compiling cortexm v0.1.0 (file:///Users/bradjc/git/tock/arch/cortex-m)
   Compiling capsules v0.1.0 (file:///Users/bradjc/git/tock/capsules)
   Compiling cortexm4 v0.1.0 (file:///Users/bradjc/git/tock/arch/cortex-m4)
   Compiling sam4l v0.1.0 (file:///Users/bradjc/git/tock/chips/sam4l)
    Finished release [optimized + debuginfo] target(s) in 23.89s
   text    data     bss     dec     hex filename
 148192    5988   34968  189148   2e2dc target/thumbv7em-none-eabi/release/imix
tockloader  flash --address 0x10000 target/thumbv7em-none-eabi/release/imix.bin
No device name specified. Using default "tock"
No serial ports found. Is the board connected?

make: *** [program] Error 1
```

That is, since you don't yet have a board plugged in it can't program it. But
the above output indicates that it can compile correctly and invoke `tockloader`
to program a board.

