# Getting Started

This getting started guide covers how to get started using Tock.

## Hardware

To really be able to use Tock and get a feel for the operating system, you will
need a hardware platform that tock supports. The
[TockOS Hardware](https://www.tockos.org/hardware/) includes a list of supported
hardware boards. You can also view the
[boards folder](https://github.com/tock/tock/tree/master/boards) to see what
platforms are supported.

As of February 2021, this getting started guide is based around five hardware
platforms. Steps for each of these platforms are explicitly described here.
Other platforms will work for Tock, but you may need to reference the README
files in `tock/boards/` for specific setup information. The five boards are:

- Hail
- imix
- nRF52840dk (PCA10056)
- Arduino Nano 33 BLE (regular or Sense version)
- BBC Micro:bit v2

These boards are reasonably well supported, but note that others in Tock may
have some "quirks" around what is implemented (or not), and exactly how to load
code and test that it is working. This guides tries to be general, and Tock
generally tries to follow a certain convention, but the project is under active
development and new boards are added rapidly. You should definitely consult the
board-specific README to see if there are any board-specific details you should
be aware of.

When you are ready to use your board, see the
[hardware setup guide](./setup/hardware.md) for information on any needed setup
to get the board working with your machine.

## Software

Tock, like many computing systems, is split between a kernel and userspace apps.
These are developed, compiled, and loaded separately.

First, complete the [quickstart guide](./setup/quickstart.md) to get all of the
necessary tools installed.

The kernel is available in the [Tock repository](https://github.com/tock/tock).
See [here](./setup/kernel.md) for information on getting started.

Userspace apps are compiled and loaded separately from the kernel. You can
install one or more apps without having to update or re-flash the kernel. See
[here](./setup/apps.md) for information on getting started.
