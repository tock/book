# Dynamic Application Loading and Secure Policies with Tock

Tock enables a host of security features not possible with other embedded system
OSes. Tock kernels can enforce strict isolation and least privilege for
applications through mechanisms including application signing, system call
filtering, and resource controls. Platforms running Tock can strongly reason
about the capabilities entrusted to each application.

Further, Tock platforms are designed to be dynamic, with applications updating
over time. Tock supports loading new applications at runtime without
interrupting existing processes.

This module will walk you through some of these features and how Tock supports
many security features not otherwise possible on resource-constrained embedded
systems.

## Hardware Notes

Any hardware that supports Tock should work, although this module will build on
the nrf52840dk board.

## Goal

Traditionally, for an application to be installed on a Tock supported board, one
must use `tockloader`, a python tool that offers users various ways to interact
with the OS. Typically, applications are used using `tockloader install` which
writes the application to the board and restarts the device.

Imagine if your phone restarted each time you had to update an app!

To allow for a seamless application loading experience, we will try to enable
Tock to do this process without using `tockloader`, or requiring a restart.

Then we will use cryptographic application signing to enforce per-process
security properties for running Tock applications.

## nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

There are a couple of configurations on the nRF52840DK board that you should
double-check:

1. The "Power" switch on the top left should be set to "On".
2. The "nRF power source" switch in the top middle of the board should be set to
   "VDD".
3. The "nRF ONLY | DEFAULT" switch on the bottom right should be set to
   "DEFAULT".

## Organization and Getting Oriented to Tock

This module will refer to some Tock components. This section briefly describes
the general structure of Tock that you will need to be somewhat familiar with to
follow the module.

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

This module is broken into N stages:

1. Configuring the kernel to provide necessary syscall drivers:
   1. [Dynamic App Load Setup](../setup/dynamic-app-loading.md).
2. [Experimenting with the Process Manager userspace application](./process-manager.md).
2. [Creating the application loader helper application](./userspace.md).
