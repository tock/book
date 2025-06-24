# Wireless Networking and Signed Sensor Data

Wireless networking exposes IoT devices to an increased attack surface. To
secure devices and the data that is sent over wireless networks, wireless
protocols use a range of security and encryption measures. Although data can be
secured using these wireless networking protocols, this security often only
protects our data from devices outside our network. In the context of an IoT
network that may contain malicious devices, we may desire to add an additional
layer of security to send sensitive data over our shared network that contains
potentially malicious devices. How can we do this?

One technique is to use an additional layer of encryption. Perhaps our company,
Super Secure Systems Corp makes a sensor that we desire to take measurements,
encrypt the data, and then send this to other devices in our network. Our Super
Secure Device is an IoT device that gains network connectivity using a Thread
network that also hosts devices from other IoT companies---importantly our
competitor, Lazy Security LLC. Although Thread networking, a popular IoT
protocol, possesses security measures to encrypt network traffic, all devices
within the network are able to decrypt Thread packets. For these reasons, we
need to encrypt our Super Secure Device sensor data to be sure that the spies
from our competitor, Lazy Security LLC, who ity LLC) and also to ensure that
Lazy Security LLC's spies are not able to snoop on the data we are sending.

To encrypt/decrypt our data, notice that we require all our devices to possess
the Super Secure Systems encryption key. How can we securely ship our devices
with the needed key?

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
a root of trust that can securely store our encryption key and decrypt .

## Hardware Notes

Any hardware that supports Tock should work, although this module will build on
the nrf52840dk board.

### nRF52840dk Hardware Setup

![nRF52840dk](../../../imgs/nrf52840dk.jpg)

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

1. Joining a Thread network using Tock. [Thread Networking](thread-app.md).

2. Using a kernel module to securely decrypt our sensor data.
   [Signed Data](encrypted-data.md).

Let's get started! [Click here](../thread-primer.md) to continue and start
learning about Thread networking.
