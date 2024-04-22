# OpenThread Temperature Sensor Network with Tock

This module and submodules will walk you through how to create a Tock
temperature sensor network mote that communicates over a Thread network.

**ADD IMAGE**

## Hardware Notes

To fully follow this guide you will need a hardware board that supports the
nRF52840 microcontroller. We recommend using the nRF52840dk.

[TODO] notes about the screen/brad's shield?

Compatible boards:

- nRF52840dk
- [TODO] do we want to list others here? Makepython?

## Goal

In a shared office space, the temperature set point can be a contencious
subject. Our goal is to create a sensor mote capable of sensing the temperature
at our workstation while also being able to provide our desired temperature to
the "central" temperature controller.

The main logic of the mote will be implemented as a userspace program. The
"sense and control" userspace app will use the kernel to obtain measurements
from the temperature sensor and user input from button presses. To communicate
our desired temperature to the central temperature controller, we utilize Tock's
port of OpenThread. To ensure a "buggy" temperature sensor implementation does
not render our device unreachable (i.e. crash the device), we place the
OpenThread instance in a separate application to utilize Tock's fault tolerance.

## nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

If you are using the nRF52840dk, there are a couple of configurations on the
nRF52840DK board that you should double-check:

1. The "Power" switch on the top left should be set to "On".
2. The "nRF power source" switch in the top middle of the board should be set to
   "VDD".
3. The "nRF ONLY | DEFAULT" switch on the bottom right should be set to
   "DEFAULT".

You should plug one USB cable into the top of the board for programming (NOT
into the "nRF USB" port on the side).

## Organization and Getting Oriented to Tock

This module will refer to various Tock components. This section briefly
describes the general structure of Tock that you will need to be somewhat
familiar with to follow the module.

Using Tock consists of two main building blocks:

1. The Tock kernel, which runs as the operating system on the board. This is
   compiled from the [Tock repository](https://github.com/tock/tock).
2. Userspace applications, which run as processes and are compiled and loaded
   separately from the kernel.

The Tock kernel is compiled specifically for a particular hardware device,
termed a "board". The location of the top-level file for the kernel on a
specific board is in the Tock repository, under `/tock/boards/<board name>`. Any
time you need to compile the kernel or edit the board file, you will go to that
folder. You also install the kernel on the hardware board from that directory.

Userspace applications are stored in a separate repository, either
[libtock-c](https://github.com/tock/libtock-c) or
[libtock-rs](https://github.com/tock/libtock-rs) (for C and Rust applications,
respectively). Those applications are compiled within those repositories.

## Stages

This module is broken into four stages:

1. Configuring the kernel to provide necessary syscall drivers:
   1. [TODO] We need to decide what/if we want anything to be done in the
      kernel.
2. [Creating a temperature sensing and control application]().
3. [Creating application for OpenThread network attachment]().
4. [Resilent networking]().
