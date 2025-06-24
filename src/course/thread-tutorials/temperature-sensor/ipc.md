# Inter Process Communication

We now have three working applications! To make sure we are on the same page, if
you have any uncertainty of your implementation(s) thus far, update your
tutorial implementation with the final checkpoint implementation. Then install
all three applications on your board:

```bash
$ cd libtock-c/examples/tutorials/thread_network/

# As-needed
$ cp -r 02_sensor_final my_sensor
$ cp -r 05_openthread_final my_openthread
$ cp -r 09_screen_final my_screen

# Then install each app!
$ make install -C my_sensor
$ make install -C my_openthread
$ make install -C my_screen
```

After installing these three applications, run:

```
$ tockloader listen
```

Within the tock console, you should see output of the following form:

```
tock$ [THREAD] Device IPv6 Addresses: fe80:0:0:0:b4ef:e680:d8ef:475e
[State Change] - Detached.
Current Temperature: 24
Current Temperature: 24
[State Change] - Child.
Successfully attached to Thread network as a child.
Received UDP Packet: 22
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
Current Temperature: 24
```

The exact output you observe will likely be interspersed. Remember Tock is
multitenant and scheduling each of our applications (resulting in our output to
this console being mixed across applications).

In addition to this output, you should also have the global/local/measured
temperature text on your screen as well as the ability to alter the local
temperature setpoint using the buttons.

Let's review how our HVAC control system will work:

1. The _communication application_ will send our desired local temperature
   setpoint and will receive the global setpoint from the central router.
2. The _sensor application_ will measure the local device temperature.
3. The _screen application_ will obtain user input to select the desired
   temperature setpoint and will display the global setpoint, local setpoint,
   and local measured temperature.

We see that these applications are interdependent on each other. How can we
share data between applications?

A naïve solution would be to allocate shared global state that each application
can access. Although this is inadvisable for security and robustness, many
embedded OSes would allow for this shared global state.

Tock, however, strictly isolates applications&mdash;meaning we are unable to
have shared global state across applications. This is beneficial as a buggy or
malicious application is unable to harm other applications or the kernel.

To allow applications to share data, the Tock kernel provides interprocess
communication (IPC). We will update our applications to use IPC next.

![thread_net_tutorial_apps](../../../imgs/thread_net_tutorial_apps.svg)

IPC in Tock is separated into services and clients.

For our HVAC control system:

- The _screen application_ will serve as our **_client_**.
- The _sensor application_ and _communication application_ will act as
  **_services_**.

## Screen Application IPC

> This part will edit `my_screen`, which should be up-to-date with equivalent
> operation of `09_screen_final`.

### Creating an IPC Client: Initialize and Discover Services

Let's go ahead and setup our client code first! We first must initialize our IPC
client. This will consist of:

1. Discovering the services (these will error for now since they are not
   implemented).
2. Registering callbacks that the kernel will invoke when our service wishes to
   notify client(s).
3. Sharing a buffer to the IPC interface.

Tock's IPC interface can be a bit challenging. For this early tutorial, we have
simply implemented these changes for you in the checkpoint `10_screen_ipc`.

Simply `$ cp 10_screen_ipc/main.c my_screen/main.c`.

> If you are interested in instead applying the changes to your screen
> implementation, work through the diff to update your application.
>
> ```bash
> $ diff -w 09_screen_final/main.c 10_screen_ipc/main.c
> ```

In either case, be sure to re-build and flash the updated `my_screen` to your
board.

Now that our IPC client is setup, let's add our IPC services!

## Temperature Sensor IPC

> This part will edit `my_sensor`, which should be up-to-date with equivalent
> operation of `02_sensor_final`.

Let's setup the sensor app as an IPC service! Change into the `my_sensor`
application.

First, we will create the callback that our client invokes when they request
this service. Add the following callback to our `main.c`:

```c
static void sensor_ipc_callback(int pid, int len, int buf,
                                __attribute__((unused)) void* ud) {
  // A client has requested us to provide them the current temperature value.
  // We must make sure that it provides us with a buffer sufficiently large to
  // store a single integer:
  if (len < ((int) sizeof(current_temperature))) {
    // We do not inform the caller and simply return. We do print a log message:
    puts("[thread-sensor] ERROR: sensor IPC invoked with too small buffer.\r\n");
  }

  // The buffer is large enough, copy the current temperature into it:
  memcpy((void*) buf, &current_temperature, sizeof(current_temperature));

  // Let the client know:
  ipc_notify_client(pid);
}
```

Now, let's register this app as an IPC service with the kernel. Add the
following to the sensor app `main()`:

```c
// Register this application as an IPC service under its name:
ipc_register_service_callback("org.tockos.thread-tutorial.sensor",
                              sensor_ipc_callback,
                              NULL);
```

**_Careful!_** To ensure an IPC client cannot make a request of the sensor
service before this app has read the temperature, be sure your app reads the
temperature sensor _at least_ once before registering the service with the
kernel.

Additionally, let's go ahead and remove the `printf()`. Now that we are using
the screen, we no longer need this information to be displayed on the console.

> **CHECKPOINT:** `11_sensor_ipc`

Congrats! You just successfully created a temperature sensor service! Let's go
ahead and do this for OpenThread now.

## OpenThread IPC

> This part will edit `my_openthread`, which should be up-to-date with
> equivalent operation of `05_openthread_final`.

We follow a similar structure to the temperature sensor service here. Let's
first create our callback that our client will invoke to use this service. Add
the following global variables and callback to the openthread app's `main.c`:

```c
uint8_t local_temperature_setpoint        = 22;
uint8_t global_temperature_setpoint       = 255;
uint8_t prior_global_temperature_setpoint = 255;
bool network_up      = false;
bool send_local_temp = false;

static void openthread_ipc_callback(int pid, int len, int buf,
                                    __attribute__((unused)) void* ud) {
  // A client has requested us to provide them the current temperature value.
  // We must make sure that it provides us with a buffer sufficiently large to
  // store a single integer:
  if (len < ((int) sizeof(prior_global_temperature_setpoint))) {
    // We do not inform the caller and simply return. We do print a log message:
    puts("[thread] ERROR: sensor IPC invoked with too small buffer.\r\n");
  }

  // copy value in buffer to local_temperature_setpoint
  uint8_t passed_local_setpoint = *((uint8_t*) buf);
  if (passed_local_setpoint != local_temperature_setpoint) {
    // The local setpoint has changed, update it.
    local_temperature_setpoint = passed_local_setpoint;
    send_local_temp = true;
  }

  if (network_up) {
    if (prior_global_temperature_setpoint != global_temperature_setpoint) {
      prior_global_temperature_setpoint = global_temperature_setpoint;

      // The buffer is large enough, copy the current temperature into it.
      memcpy((void*) buf, &global_temperature_setpoint, sizeof(global_temperature_setpoint));

      // Notify the client that the temperature has changed.
      ipc_notify_client(pid);
    }
  }
}

```

Now that we have this callback, let's register our service with the kernel. Add
the following to the openthread app's main function:

```c
// Register this application as an IPC service under its name:
ipc_register_service_callback("org.tockos.thread-tutorial.openthread",
                              openthread_ipc_callback,
                              NULL);
```

The logic in the callback determines if the local temperature setpoint has
changed, and if so, sends an update over the Thread network (if the Thread
network is enabled). We send this update using UDP. If you look closely, you
will notice that our callback does not directly call the
`sendUdpTemperature(...)` we used in the openthread module. **_Why is this?_**

### Callbacks and Reentrancy

If a callback function, say the `ipc_callback`, executes code that inserts a
yield point, we may experience reentrancy. This means that during the execution
of the `ipc_callback`, other callbacks&mdash;including `ipc_callback`
itself&mdash;may be scheduled again.

Consider the following example:

```c
void ipc_callback() {
  // The call to yield allows other callbacks to be scheduled,
  // including `ipc_callback` itself!
  yield();
}

void main() {
  send_ipc_request();

  // This call allows the initial `ipc_callback` to be scheduled:
  yield();
}
```

While Tock applications are single-threaded and this type of reentrancy is less
dangerous than, e.g., UNIX signal handlers, it can still cause issues. For
instance, when a function called from within a callback performs a `yield`
internally, it can unexpectedly be run _within_ the execution of the function.
This can in turn break the function's semantics. Thus, it is good practice to
restrict callback handler code to only non-blocking operations.

For this reason, the openthread IPC callback only sets a flag specifying that we
should send an update packet (as `sendUdpTemperature(..)` internally will
yield).

We now must add a check to our main loop to see if a client of our openthread
service requires us to send a packet updating the local temperature setpoint.

> **EXERCISE** Add a check to see if the `send_local_temp` flag is set. If this
> condition is met, send the value of `local_temperature_setpoint` using the
> `sendUdpTemperature(...)` method.

> **EXERCISE** Alter the `handleUdpRecvTemperature(...)` method to no longer
> print the received global temperature packet, but instead update the
> `global_temperature_setpoint` variable with this value.

Wonderful, we are almost finished. The final modification we will need to make
is to the state change callback. The way we have currently designed our system,
we must send the local temperature setpoint and update the `network_up` flag
when we attach to a thread network. Add the following to the
`stateChangeCallback(...)` for the case of becoming a child:

```c
network_up = true;
sendUdpTemperature(instance, local_temperature_setpoint);
```

> **CHECKPOINT:** `12_openthread_ipc`

And congratulations! You have now have a complete, working, networked
temperature controller!

In the final stage, next, we will
[explore how isolated processes enable robust operation](robustness.md).
