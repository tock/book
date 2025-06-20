# Wireless Networking and Signed Sensor Data

[TODO: Turn into flushed out text]

Wireless networking exposes IoT devices to an increased attack surface. To
secure devices and the data that is sent over wireless networks, wireless
protocols use a range of security and encryption measures. Although data can be
secured using these wireless networking protocols, certain applications require
confirming the authenticity of the data and that it has not been tampered with.
How can we do this?

One technique is to sign data using encryption. Perhaps our company, Super
Secure Systems Corp makes a sensor that we desire to take measurements,
sign/encrypt the data, and then send this to other devices in our network. Our
Super Secure Device is an IoT device that gains network connectivity using a
Thread network that also hosts devices from other IoT companies---importantly
our competitor, Lazy Security LLC. Although Thread networking, a popular IoT
protocol, possesses security measures to encrypt network traffic, all devices
within the network are able to decrypt Thread packets. For these reasons, we
need to encrypt our Super Secure Device sensor data to be sure it originates
from other Super Secure Systems devices (and not our malicious competitor Lazy
Security LLC).

To encrypt/decrypt our data, notice that we require all our devices to possess
the Super Secure Systems encryption key. How can we securely ship our devices
with the needed key to confirm that the received data is signed?

A hardware root of trust provides the ability to securely store and ship a
device with keys (more on this in a bit!). Tock's design allows for easily
creating secure systems that utilize a root of trust (for more details on how
Tock can be used as a root of trust see [(TODO) LINK FOR ZERORISC MODULE]().
Furthermore, Tock also possesses "out of the box" support for joining a Thread
network.

## Goal

In this module, we will demonstrate how Tock provides the building blocks to
create a device capable of securely storing keys and encrypting/decrypting data
to determine the authenticity of received data.

We will first introduce Thread Networking, a popular IoT wireless networking
protocol and demonstrate Tock's support for OpenThread. Using our now networked
device, we will then leverage Tock's security guarantees and ability to provide
a root of trust that can securely store our encryption key and determine if
received data is properly signed.

## Hardware Notes

Any hardware that supports Tock should work, although this module will build on
the nrf52840dk board.

### nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

There are a couple of configurations on the nRF52840DK board that you should
double-check:

1. The "Power" switch in the corner near the USB should be set to "On".
2. The "nRF power source" switch in the middle of the board (under the screen)
   should be set to "VDD".
3. The "nRF ONLY | DEFAULT" switch on the side near the LEDs should be set to
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

## Main Tutorial

This module is broken into 2 stages:

1. Joining a Thread network using Tock.

[Thread Networking](thread.md).

2. Using a kernel module to securely decrypt signed data.

[Signed Data](signed-data.md).
