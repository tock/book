# Tock as a Hardware Root of Trust (HWRoT) Operating Sytsem

This module and submodules will walk you through setting up Tock as an operating
system capable of providing the software backbone of a hardware root of trust,
placing emphasis on why Tock is well-suited for this role.

## Background

A hardware root of trust (HWRoT) is a security-hardened device intended to
provide the foundation of trust for the system they're integrated into. Systems
such as mobile phones, servers, and industrial control systems run code and
access data that needs to be trusted, and if compromised, could have severe
negative impacts. HWRoTs serve to ensure the trustworthiness of the code and
data their system uses to prevent these outcomes.

HWRoTs can come in two flavors: discrete and integrated.

- Discrete: a _discrete_ HWRoT is an individually-packaged system on chip (SoC),
  and communicates over one or more external buses to provide functionality.

- Integrated: an _integrated_ HWRoT is integrated into a SoC, and communicates
  over one or more internal buses to provide functionality to the rest of the
  SoC it resides in.

Some notable examples of HWRoTs include:

- The general-purpose, open-source _OpenTitan HWRoT_ which comes in the discrete
  _Earl Grey_ design as well as the _Darjeeling_ integrated design
- Apple's _Secure Enclave_, the integrated root of trust in iPhone mobile
  processors
- Google's _Titan Security Module_, the discrete root of trust in Google Pixel
  phones
- Hewlett Packard Enterprise's _Silicon Root of Trust_, the integrated root of
  trust in their out-of-band management chip
- Microsoft's _Pluton Security Processor_, the integrated root of trust
  integrated into many of its silicon collaborators' processors (Intel, AMD,
  etc.)
- Arm's _TrustZone_, the general-purpose integrated HWRoT provided in some
  Cortex-M and Cortex-A processors
- Infineon's _SLE78 Secure Element_, which is used in YubiKey 5 series USB
  security keys

In practice, hardware roots of trust are essential for providing support for all
kinds of operations, including:

- **Application-level cryptography**: While any processor can be used to perform
  cryptographic operations, doing so on a non-hardened processor can result in
  side-channel leaks or vulnerability to fault injection attacks, allowing
  attackers to uncover secrets. HWRoTs are specifically designed to prevent such
  issues.

- **Key management**: Similarly, cryptographic keys stored in memory can be
  leaked using invasive attacks on a chip--a secure element can instead store
  the keys and use them without them ever being copied to memory. Smaller HWRoTs
  focused on providing hardware cryptographic operations and secure key storage
  are often called _secure elements_.

- **Secure boot**: In many systems, it is critical to ensure that code the
  processor runs hasn't been tampered with by an attacker. Secure boot allows
  for this by having multiple boot stages, where each stage verifies a digital
  signature on the next to verify integrity. The bottom-most boot stage is
  immutable (usually a ROM image baked into the chip design itself). In
  security-critical systems, the first boot stage is the HWRoT's ROM, which then
  boots the rest of the RoT, and finally the main processor of the system.

- **Hardware attestation**: Often with internet-connected devices, it's
  important for a server to be able to verify that it's connected to a valid,
  uncompromised device before transfering data back-and-forth. During boot, each
  boot stage of a device with a HWRoT can generate and sign certificates
  attesting to the hash of the next boot stage's value. The server can then
  review those certificates, verifying that the expected hash values were
  reported all the way back to the HWRoT ROM.
- **Device firmware updates (DFU)**: Device firmware updates can be a major
  threat vector to a device, as a vulnerability in the target device's ability
  to verify authenticity of an update can allow for an attacker to achieve
  remote code execution. By relegating device firmware updates to a HWRoT, which
  can verify the signature and update flash in a tamper-free way on its own, the
  process of DFU can be made significantly less risky.
- **Drive encryption**: Similarly, drive encryption can be performed using a
  HWRoT to avoid attackers tampering with the drive encryption process and
  compromising the confidentiality of user data.

## Hardware Notes

For accessibility, we will use a standard microcontroller in this demo rather
than an actual hardware root of trust; that said, the principles in this demo
apply readily to any HWRoT.

To fully follow this guide you will need a hardware board that supports a
peripheral USB port (i.e. where the microcontroller has USB hardware support).
In the future, this tutorial may be extended to support other boards, but for
now only the nrf52840dk is supported.

Compatible boards:

- nRF52840dk

## Goal

Our goal is to build a simple encryption service which we'll mount several
attacks on in order to demonstrate how Tock prevents against them.

Along the way, we'll also cover foundational Tock concepts to give a top-level
view of the OS as a whole.

## nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

Before beginning, check the following configurations on your nRF52840dk board.

1. The "Power" switch on the top left should be set to "On".
2. The "nRF power source" switch in the top middle of the board should be set to
   "VDD".
3. The "nRF ONLY | DEFAULT" switch on the bottom right should be set to
   "DEFAULT".

You should plug one USB cable into the top of the board for both programming and
communication, into the port labeled "MCU USB" on the short side of the board.

## Kernel Setup

This tutorial requires a Tock kernel configured with two specific capsules
instantiated that may not be included by default with a particular kernel:

1. [Screen](../setup/screen.md)
2. [Encryption Oracle](../usb-security-key/key-hotp-oracle.md)

The easiest way to get a kernel image with these installed is to use the [HOTP
tutorial configuration for the nRF52840dk]
(https://github.com/tock/tock/tree/master/boards/tutorials/nrf52840dk-hotp-tutorial).

```
cd tock/boards/tutorials/nrf52840dk-root-of-trust-tutorial
make install
```

But, you can also follow the guides to setup these capsules yourself in a
different kernel setup or for a different board.

## Organization and Getting Oriented to Tock

To get started, we briefly describe the general structure of Tock and will
deep-dive into these components throughout the tutorial:

A Tock system contains primarily two components:

1. The Tock kernel, which runs as the operating system on the board. This is
   compiled from the [Tock repository](https://github.com/tock/tock).
2. Userspace applications, which run as processes and are compiled and loaded
   separately from the kernel.

The Tock kernel is compiled specifically for a particular hardware device,
termed a "board". Tock provides a set of reference board files under
[`/boards/<board name>`](https://github.com/tock/tock/tree/master/boards). Any
time you need to compile the kernel or edit the board file, you will go to that
folder. You also install the kernel on the hardware board from that directory.

While the Tock kernel is written entirely in Rust, it supports userspace
applications written in multiple languages. In particular, we provide two
userspace libraries for application development in C and Rust respectively:

- `libtock-c` for C applications (
  [tock/libtock-c](https://github.com/tock/libtock-c) )
- `libtock-rs` for Rust applications (
  [tock/libtock-rs](https://github.com/tock/libtock-rs) )

We will use `libtock-c` in this tutorial. Its example applications are located
in the [`/examples`](https://github.com/tock/libtock-c/tree/master/examples)
directory of the `libtock-c` repository.

## Stages

This module is broken into two stages:

1. [Creating a simple encryption service](encryption-service.md)
2. [Preventing attacks at runtime with the MPU](userspace-attack.md)
