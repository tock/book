# Wireless Networking App

> **NOTE** Please read the [Thread Primer](../thread-primer.md) if you have not
> already done so.

## Libopenthread

> At this point the tutorial assumes there is a separate, single nRF52840DK
> board running nearby that is acting as a Thread router and also providing a
> network endpoint that performs certain logic (such as averaging temperature
> setponts).
>
> In a hosted tutorial setting this will already be set up for you. If you are
> working through the tutorial on your own, you will need to
> [follow the router setup instructions](../router-setup.md) before continuing
> if you have not already.

We now begin implementing an OpenThread app using `libopenthread`. Because Tock
is able to run arbitrary code in userspace, we can make use of this existing
library and tie it into the Tock ecosystem. As such, this part of our
application works quite similar compared to other platforms.

For the purposes of this tutorial, we provide a hardcoded network key
(_commissioned joining_ would be a more secure authentication method). The major
steps to join a Thread network include:

1. Creating a dataset.
2. Adding the network key, `panid`, and channel to the dataset.
3. Committing the active dataset.
4. Initializing the IP interface.
5. Begin thread network attachment.

Each of these steps are accomplished using functions the OpenThread API exposes.

> **CHECKPOINT:** `03_openthread`

We provide a skeleton implementation in `03_openthread` that is missing the
logic needed to attach to the thread network. Your task is to add the needed
OpenThread API calls to attach your device to the thread network.

As before, begin by making a copy of the starting checkpoint to work from:

```bash
$ cp -r 03_openthread my_openthread
$ cd my_openthread
```

The provided starter code includes a helper method:
`void setNetworkConfiguration(otInstance* aInstance)`. This method will
initialize the network configuration dataset to the correct values (this
completes steps 1, 2, and 3 above).

> **EXERCISE** Initialize the network dataset.

Now that we have the network dataset initialized, we now must initialize the IP
interface to have an IPv6 address assigned to our Thread node. The OpenThread
library possess an API exposed as many functions. Two useful API functions
include:

```
otIp6SetEnabled(otInstance* aInstance, bool aEnabled)
otThreadSetEnabled(otInstance* aInstance, bool aEnabled)
```

> **EXERCISE** Initialize the IP interface.

To confirm that we have successfully initialized the IP interface, add the
following helper method after your IP initialization:

```
print_ip_addr(instance);
```

Our Thread node is now fully configured and ready to attempt joining a network.

> **EXERCISE** Start the Thread Network

After completing these changes, build and flash the updated openthread app
(`$ make install`).

Our skeleton registers a callback with OpenThread to notify upon state change.
Upon successfully implementing the above network attachment, flash the app,
launch `tockloader listen` and reset the board using:

```
tock$ reset
```

If you have successfully implemented the thread network attachment, you will
see:

```
tock$ [THREAD] Device IPv6 Addresses: fe80:0:0:0:b4ef:e680:d8ef:475e
[State Change] - Detached.
[State Change] - Child.
Successfully attached to Thread network as a child.
```

If you are unable to join the network, this is a good time to ask for help at a
hosted tutorial event, or feel free to jump ahead to the checkpoint below.

> **CHECKPOINT:** 04_openthread_attach

To send and receive UDP packets, we must also correctly configure UDP.

We must complete the following steps to setup UDP in the OpenThread library:

1. Initialize UDP interface.
2. Register a function as a receive callback.
3. Implement a function to transmit.

For your convience, we provide helper methods to accomplish each of the
aformentioned steps.

1. Initialize UDP interface &rarr; `initUdp`
2. Register a function as a receive callback &rarr; `handleUdpRecvTemperature`
3. Implement a function to transmit &rarr; `sendUdpTemperature`

Internally, our provided `initUDP` function registers our receive callback
(`handleUdpRecvTemperature`).

Add the following functions to the communication application's `main.c`:

```c
static otUdpSocket sUdpSocket;

void initUdp(otInstance* instance);

void handleUdpRecvTemperature(void* aContext, otMessage* aMessage,
			      const otMessageInfo* aMessageInfo);

void sendUdpTemperature(otInstance* aInstance, uint8_t temperature);

void handleUdpRecvTemperature(void* aContext, otMessage* aMessage,
                      	      const otMessageInfo* aMessageInfo) {
  OT_UNUSED_VARIABLE(aContext);
  OT_UNUSED_VARIABLE(aMessageInfo);
  char buf[2];

  const otIp6Address sender_addr = aMessageInfo->mPeerAddr;
  otIp6AddressToString(&sender_addr, buf, sizeof(buf));

  otMessageRead(aMessage, otMessageGetOffset(aMessage), buf, sizeof(buf) - 1);
  printf("Received UDP Packet: %d\r\n", buf[0]);
}

void initUdp(otInstance* aInstance) {
  otSockAddr listenSockAddr;

  memset(&sUdpSocket, 0, sizeof(sUdpSocket));
  memset(&listenSockAddr, 0, sizeof(listenSockAddr));

  listenSockAddr.mPort = 1212;

  otUdpOpen(aInstance, &sUdpSocket, handleUdpRecvTemperature, aInstance);
  otUdpBind(aInstance, &sUdpSocket, &listenSockAddr, OT_NETIF_THREAD);
}

void sendUdpTemperature(otInstance* aInstance, uint8_t temperature) {

  otError error = OT_ERROR_NONE;
  otMessage*   message;
  otMessageInfo messageInfo;
  otIp6Address destinationAddr;

  memset(&messageInfo, 0, sizeof(messageInfo));

  otIp6AddressFromString("ff02::02", &destinationAddr);
  messageInfo.mPeerAddr = destinationAddr;
  messageInfo.mPeerPort = 1212;

  message = otUdpNewMessage(aInstance, NULL);
  if (message == NULL) {
    printf("Error creating udp message\n");
    return;
  }

  error = otMessageAppend(message, &temperature, 1);
  if (error != OT_ERROR_NONE && message != NULL) {
    printf("Error appending to udp message\n");
    otMessageFree(message);
    return;
  }

  error = otUdpSend(aInstance, &sUdpSocket, message, &messageInfo);
  if (error != OT_ERROR_NONE && message != NULL) {
    printf("Error sending udp packet\n");
    otMessageFree(message);
  }
}
```

> **EXERCISE** Add the `initUDP` function to the Thread initialization that
> occurs within `main()`.

We now have an initialized UDP interface. Now let's try to send a UDP packet to
our router over the Thread interface. Importantly, we must only attempt to send
a UDP packet _after_ we have succesfully joined the Thread network.

> **EXERCISE** Modify the `stateChangeCallback` such that when our device
> attaches to the network and becomes a child, we send a UDP packet using:
>
> ```
> sendUdpTemperature(instance, 22)
> ```

The registered UDP receive callback is implemented to print received packets to
the console. Our router is implemented to receive UDP packets and reply with a
multicast of the global average temperature setpoint.

After completing these changes, build and flash the openthread application. In
the tockloader console, you should see (upon reset):

```
tock$ [THREAD] Device IPv6 Addresses: fe80:0:0:0:b4ef:e680:d8ef:475e
[State Change] - Detached.
[State Change] - Child.
Successfully attached to Thread network as a child.
Received UDP Packet: {GLOBAL_SET_POINT_VALUE}
```

> **CHECKPOINT:** `05_openthread_final`

Congratulations! We now have a networked mote that is attached to our router and
capable of sending and receiving UDP packets.

Next up, we will work to
[obtain user input (buttons) and implement the display](screen-app.md).
