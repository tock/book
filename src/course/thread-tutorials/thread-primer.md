# Wireless Networking

We now will utilize Tock's network capabilities to connect our board to a Thread
network.

---

> Before starting to develop this app, please remove any existing apps from the
> board using the following tockloader command:
>
> ```
> $ tockloader erase-apps
> ```
>
> Importantly, be sure you flash the correct kernel image by running
>
> ```
> $ make install
> ```
>
> in the Tock `boards/tutorials/nrf52840dk-thread-tutorial` directory.

---

## Background

### IEEE 802.15.4

To facilitate wireless communication, Tock provides an IEEE 802.15.4 network
stack. IEEE 802.15.4 (hence forth abbreviated 15.4) is a physical (PHY) and
media access control (MAC) specification that is purpose-built for low-rate
wireless personal area networks.

Notable examples of popular wireless network technologies utilizing 15.4
include:

- Thread
- Zigbee
- 6LoWPAN
- ISA100.11a

Tock exposes 15.4 functionality to userspace through a series of command
syscalls. Within the kernel, a 15.4 capsule and a 15.4 radio driver serve to
virtualize radio resources across other kernel endpoints and applications. To
provide platform agnostic 15.4 logic, Tock prescribes a 15.4 radio Hardware
Interface Layer (HIL) that must be implemented for each 15.4 radio supported by
Tock.

### Thread

[Thread networking](https://www.threadgroup.org) is a low-power and low-latency
wireless mesh networking protocol built using a 15.4, 6LoWPAN, and UDP network
stack. Notably, each Thread node possess a globally addressable IPv6 address
given Thread's adoption of 6LoWPAN (an IPv6 compression scheme). Although we
will not exhaustively describe Thread here, we will provide a brief overview and
pointers to more in-depth resources that further describe Thread.

Thread devices fit into two broadly generalized device types: routers and
children. Routers often possess a non-constrained power supply (i.e., "plugged
in") while children are often power constrained battery devices. Children form a
star topology around their respective parent router while routers maintain a
mesh network amongst routers. This division of responsibilities allows for the
robustness and self-healing capabilities a mesh network provides while not being
prohibitive to power constrained devices.

Further resources on Thread networking can be found
[here](https://openthread.io/guides/thread-primer).

### Tock and OpenThread

[OpenThread](https://github.com/openthread/openthread) is an open source
implementation of the [Thread standard](https://www.threadgroup.org/). This
implementation is the "de facto" Thread implementation.

For a given platform to support OpenThread, the platform must provide:

- IEEE 802.15.4 radio
- Random Number Generator
- Alarm
- Nonvolatile Storage

These functionalities are provided to OpenThread using OpenThread's platform
abstraction layer (PAL) that a given platform implements as the "glue" between
the OpenThread stack and the platform's hardware.

OpenThread is a popular network stack supported by other embedded platforms
(e.g. [Zephyr](https://github.com/zephyrproject-rtos/zephyr)). Typically, the
OpenThread PAL is exposed either directly to hardware or links directly to the
kernel. Tock faces a unique design challenge in supporting OpenThread as the
Tock kernel's threat model explicitly bans external dependencies.

Subsequently, Tock provides an OpenThread port that runs as an application. This
provides the added benefit that a bug in OpenThread will not cause the entire
system to crash and that a faulting OpenThread app can be recovered and
restarted by the Tock kernel without affecting other apps. The libtock-c
OpenThread port can be found in the `libtock-c/libopenthread` directory for
further details. `libopenthread` directly checks out the upstream
[OpenThread](https://github.com/openthread/openthread) repository and as such
possesses the entire set of OpenThread APIs.

Now that we have a primer for OpenThread let's continue our tutorial!

- If you are completing the Temperature Sensor Tutorial
  [click here!](./temperature-sensor/comms-app.md)
- If you are completing the Encrypted Sensor Data Tutorial
  [click here!](./encrypted-sensor-data/thread-app.md)
