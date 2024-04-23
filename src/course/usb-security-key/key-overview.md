# Security USB Key with Tock

This module and submodules will walk you through how to create a USB security
key using Tock.

![Security Key](../../imgs/usbkey.jpg)

## Hardware Notes

To fully follow this guide you will need a hardware board that supports a
peripheral USB port (i.e. where the microcontroller has USB hardware support).
We recommend using the nRF52840dk.

Compatible boards:

- nRF52840dk
- imix

You'll also need two USB cables, one for programming the board and the other for
attaching it as a USB device.

## Goal

Our goal is to create a standards-compliant HOTP USB key that we can use with a
demo website. The key will support enrolling new URL domains and providing
secure authentication.

The main logic of the key will be implemented as a userspace program. That
userspace app will use the kernel to decrypt the shared key for each domain,
send the HMAC output as a USB keyboard device, and store each encrypted key in a
nonvolatile key-value storage.

## nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

If you are using the nRF52840dk, there are a couple of configurations on the
nRF52840DK board that you should double-check:

1. The "Power" switch on the top left should be set to "On".
2. The "nRF power source" switch in the top middle of the board should be set to
   "VDD".
3. The "nRF ONLY | DEFAULT" switch on the bottom right should be set to
   "DEFAULT".

For now, you should plug one USB cable into the top of the board for programming
(NOT into the "nRF USB" port on the side). We'll attach the other USB cable
later.

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
   1. [USB Keyboard Device](./usb-hid.md).
   2. [HMAC](./key-hotp-hmac.md)
   3. [Key-Value](./key-hotp-kv.md)
2. [Creating an HOTP userspace application](./key-hotp-application.md).
3. [Creating an in-kernel encryption oracle](./key-hotp-oracle.md).
4. [Enforcing access control restrictions to the oracle](./key-hotp-access.md).
