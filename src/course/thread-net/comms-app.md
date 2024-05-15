# Wireless Networking

We have created a device capable of sensing temperature, accepting user input,
and displaying data. We now set out to utilize Tock's network capabilities to
connect our temperature controller to a central node.

## Background

### IEEE 802.15.4

To facilitate wireless communication, Tock provides an IEEE 802.15.4 network
stack. IEEE 802.15.4 (hence forth abbreviated 15.4) is a physical (PHY) and
media access control (MAC) specification that is purpose built for low-rate
wireless personal area networks. As such, 15.4 is harmonious with Tock's use
case as an embedded operating system for resource constrained devices.

Notable examples of popular wireless network technologies utilizing 15.4
include:

- Thread
- Zigbee
- 6LoWPAN
- ISA100.11a

Tock exposes to userspace 15.4 functionality through a series of command
syscalls. Within the kernel, a 15.4 capsule and 15.4 radio driver serve to
virtualize radio resources across other kernel endpoints and applications. To
provide platform agnostic 15.4 logic, Tock prescribes a 15.4 radio Hardware
Interface Layer (HIL) that must be implemented for each 15.4 radio supported by
Tock.

### Thread

[Thread networking](https://www.threadgroup.org) is a low-power and low-latency
wireless mesh networking protocol built using a 15.4, 6LoWPAN, UDP network
stack. Notably, each Thread node possess a globally addressable IPv6 address
given Thread's adoption of 6LoWPAN (an IPv6 compression scheme). Although we
will not exhaustively describe Thread here, we will provide a brief overview and
pointers to more in-depth resources that further describe Thread.

Thread devices fit into two broadly generalized device types: routers and
children. Routers often possess a non constrained power supply (i.e. "plugged
in") while children are often power constrained battery devices. Children form a
star topology around their respective parent router while routers maintain a
mesh network amongst routers. This division of responsibilities allows for the
robustness and self healing capabilities a mesh network provides while not being
prohibitive to power constrained devices.

Further resources on Thread networking can be found
[here](https://openthread.io/guides/thread-primer).

### Tock and OpenThread

[OpenThread](https://github.com/openthread/openthread) is an opensource
implementation of the [Thread standard](https://www.threadgroup.org/). This
implementation is the "de facto" Thread implementation.

In order for a given platform to support OpenThread, the platform must provide:

- IEEE 802.15.4 radio
- Random Number Generator
- Alarm
- Nonvolatile Storage

These functionalities are provided to OpenThread using OpenThread's platform
abstraction layer (PAL) that a given platform implements as the "glue" between
the OpenThread stack and the platform's hardware.

OpenThread is a popular network stack supported by other embedded platforms
(e.g. [Zephyr](https://github.com/zephyrproject-rtos/zephyr)). In other embedded
platforms, the OpenThread PAL is exposed either directly to hardware or links
directly to the kernel. Tock faces a unique design challenge in supporting
OpenThread as the Tock kernel's threat model explicitly bans external
dependencies. Subsequently, Tock provides an OpenThread port that runs as an
application. This provides the added benefit that a bug in OpenThread will not
cause the entire system to crash and that a faulting OpenThread app can be
recovered and restarted by the Tock kernel. The libtock-c OpenThread port can be
found in the `libopenthread` directory for further details. `libopenthread`
directly checks out the upstream
[OpenThread](https://github.com/openthread/openthread) repository and as such
possesses the entire set of OpenThread APIs.

### Libopenthread

We assume that a single nRF52840DK board is used as a Thread router that also
performs certain logic (such as averaging temperature setponts). In a hosted
tutorial setting you will likely be provided with such a board; we do provide
instructions for this [here](./router-setup.md).

We now begin implementing an OpenThread app using `libopenthread`. Because Tock
is able to run arbitrary code in userspace, we can make use of this existing
library and tie it into the Tock ecosystem. As such, this part of our
application works quite similar compared to other platforms.

For the purposes of this tutorial, we provide a hardcoded network key
(_commissioned joining_ would be a more secure authentication method). The major
steps to join a Thread network include:

1. Initializing the IP interface (`ifconfig up`)
2. Creating a dataset (`dataset init new`)
3. Adding the network key, _panid_, and channel to the dataset
4. Committing the active dataset ('dataset commit active')
5. Begin thread network attachment (`thread start`)

To send and receive UDP packets, we must also correctly configure UDP. Because
of these steps are mostly OpenThread specific, we provide an application that
performs the vast majority of these steps.

> **CHECKPOINT:** `06_openthread`

> **EXERCISE:** Build and flash the openthread app, located under
> `examples/tutorials/thread_network/06_openthread`.

Upon successfully flashing the app, launch `tockloader listen`. Once in the
tockloader console reset the board using:

```
tock$ reset
```

If you have successfully compiled and flashed the app, you will see:

```
tock$ [THREAD] Device IPv6 Addresses: fe80:0:0:0:b4ef:e680:d8ef:475e
[State Change] - Detached.
[State Change] - Child.
Successfully attached to Thread network as a child.
```

> **TROUBLESHOOTING**
>
> 1. _Thread output not printed to the console_.
>
>    Run `tockloader list` and you should see:
>
>    ```
>    tock$ list
>     PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
>     0      Unique     org.tockos.thread-tutorial.openthread   125      1586         0   6/18   Running
>     1      Unique     thread_controller        2       187         0   5/18   Yielded
>     2      Unique     org.tockos.thread-tutorial.sensor     0       132         0   3/18   Yielded
>    ```
>
>    If you do not see this, you have not successfully flashed the app.
>
> 2. _Thread output does not say successfully joined_.
>    - First confirm that you have flashed the router with the
>      [provided instructions](./router-setup.md).
>    - Attempt resetting your board again.

Congratulations! We now have a networked mote. We now must modify the provided
implementation to be integrated with the controller app.

> **EXERCISE:** We provide a list of the features and expected behaviors of this
> app. We leave the implementation of this logic to you. This will utilize a
> similar IPC framework as between the controller and sensor apps. The specified
> behavior is as follows.
>
> 1. The openthread app will receive an IPC request (the specified local
>    setpoint will be contained in the first byte of the shared buffer).
> 2. The openthread app will multicast this value to all router devices.
> 3. The router will average this value against all other received requests and
>    then multicast the averaged value to all children.
> 4. Upon receiving the multicasted response, our openthread app will place the
>    received global average into the first byte of the shared IPC buffer. We
>    then must notify the client that the requested service is completed.
>
> More specifically, here is a todo list of things to implement. If you become
> stuck, we provide a checkpoint with the completed OpenThread app
> (`07_openthread_final`). To be implemented:
>
> 1. Add IPC callback (mirroring structure of sensor IPC) and register the the
>    service.
> 2. Within this callback copy the `local_setpoint` found in the shared IPC
>    buffer to the variable `local_temperature_setpoint`.i
> 3. Send a UDP packet with the local temperature setpoint. You can use the
>    `udpSend()` method. This function multicasts to all routers the value
>    stored in the variable `local_temperature_setpoint`.
> 4. We should _ONLY_ copy the global setpoint into the shared IPC buffer and
>    notify the controller client _IF_ the mote is connected to a thread
>    network. If we are not connected to a network, we have no way of knowing
>    the global setpoint. _(HINT: we can use the `statechangedcallback` to track
>    when we are attached to a network)_.

> **CHECKPOINT:** `07_openthread_final`

We now have a completed OpenThread app that provides an IPC service capable of
broadcasting the given mote's desired setpoint, receiving the global average
setpoint, and notifying the IPC client.
