# Inter Process Communication

We now have three working applications! To make sure we are on the same page,
navigate to each of the following directories and run `make install`:

1. `libtock-c/examples/tutorials/thread_network/02_sensor_final`
2. `libtock-c/examples/tutorials/thread_network/05_openthread_final`
3. `libtock-c/examples/tutorials/thread_network/09_screen_final`

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
the console being mixed across applications). In addition to this output, you
should also have the global/local/measured temperature text on your screen in
addition to the ability to alter the local temperature setpoint using the
buttons.

Let's review how our HVAC control system will work:

1. Thread application will receive the global setpoint from the central router
   and will send our desired local temperature setpoint.
2. Sensor application will measure the temperature.
3. Screen application will obtain user input to the desired temperature setpoint
   and display the global setpoint / local setpoint / measured temperature.

We see that these applications are interdependent on each other. How can we
share data between applications? A naive solution would be to allocate shared
global state that each application can access. Although this is inadvisable,
many embedded OSes would allow for this shared global state. Tock, however,
strictly isolates applications---meaning we are unable to have shared global
state across applications. This is beneficial as a buggy or malicious
application is unable to harm other applications or the kernel. To allow
applications to share data, the Tock kernel provides interprocess communication.
We will update our applications to do this here.

![thread_net_tutorial_apps](../../imgs/thread_net_tutorial_apps.svg)

## Screen IPC

IPC in Tock is seperated into services and clients. For our HVAC control system,
the screen application will serve as our client; the openthread and sensor apps
will act as services.

### Initialize / Discover IPC Client

Let's go ahead and setup our client code first! We first must initialize our IPC
client. This will consist of:

1. Discovering the services (these will error for now since they are not
   implemented).
2. Register callbacks that the kernel will invoke when our service wishes to
   notify the client.
3. Share a buffer to the IPC interface.

To make your life easier we have implemented these changes in the checkpoint
`10_screen_ipc`. If you are interested in seeing what has changed, try

```
$ diff 09_screen_final/main.c 10_screen_ipc/main.c
```

Before proceeding, be sure to build and flash `10_screen_ipc` to your board.

Now that our IPC client is setup, let's add our IPC services!

## Temperature Sensor IPC

Let's setup the sensor app as an IPC service! As mentioned earlier, we will be
expanding `02_sensor_final`.

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

To ensure an IPC client cannot request our service before our service has read
the temperature, be sure to read the temperature sensor _at least_ once before
registering the service with the kernel.

Additionally, let's go ahead and remove the `printf()` as, now that we are using
the screen, we no longer need this information to be displayed on the console.

> **CHECKPOINT:** `11_sensor_ipc`

Congrats! You just successfully created a temperature sensor service! Let's go
ahead and do this for OpenThread now.

## OpenThread IPC

> **NOTE** We assume you are modifying `06_openthread_final`

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
`sendUdpTemperature(...)` we used in the openthread module. Why is this?

### Callbacks and Re-entrancy

If a callback function, say the `ipc_callback`, executes code that
inserts a yield point, we may experience reentrancy.
This means that during the execution of the `ipc_callback`, other callbacks --
including `ipc_callback` itself -- may be scheduled again. Consider the
following example:

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
