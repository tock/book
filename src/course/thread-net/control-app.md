# Building the User Interface

In the previous stage we have built a _sensor application_ that is able to query
the Tock kernel for the current temperature and expose this value as an IPC
service. We also provide a minimal _controller application_ which uses this
service and prints the temperature value onto the console.

However, this is not a great user interface. In this stage of the tutorial, we
will extend this application to display information on an OLED screen attached
to the board. For this we use the Tock kernel's screen driver support, in
addition to the `u8g2` graphics library.

> **CHECKPOINT:** `02_sensor_final` + `03_controller_screen`
>
> We assume that the sensor application is already loaded onto the board, and
> that the provided control application is able to print the temperature
> retrieved via IPC.

## Adding the `u8g2` Library

Tock is able to run arbitrary code in its userspace applications, including
existing C libraries. For this stage in particular, we are interested in
displaying information on a screen. Without a library to render text or symbols,
this can be quite cumbersome. Instead, we will use the `u8g2` library for which
`libtock-c` provides some bindings.

To add this library to our application we add the following two lines to our
application's `Makefile`, before the `AppMakefile.mk` include:

```makefile
STACK_SIZE  = 4096
EXTERN_LIBS += $(TOCK_USERLAND_BASE_DIR)/u8g2
```

We increase the size of the stack that is pre-allocated for the application, as
`libtock-c` by default allocates a stack of 2 kB which is insufficient for
`u8g2`. We then specify that our application depends on the `u8g2` library, by
adding the `libtock-c/u8g2` directory to `EXTERN_LIBS`. This directory contains
a wrapper that allows the `u8g2` library to communicate with Tock's screen
driver system calls and ensures that the library can be used from within our
application.

Once this is done, we can add some initialization code to our controller
application:

```
#include <u8g2.h>
#include <u8g2-tock.h>

// Global reference to the u8g2 context:
u8g2_t u8g2;

int main(void) {
  // Required initialization code:
  u8g2_tock_init(&u8g2);
  u8g2_SetFont(&u8g2, u8g2_font_profont12_tr);
  u8g2_SetFontPosTop(&u8g2);

  // Clear the screen:
  u8g2_ClearBuffer(&u8g2);
  u8g2_SendBuffer(&u8g2);

  [...]
```

When we now build and install this app, it should still display the temperature
readouts on the serial console. However, it should also clear the screen and you
may see repeatedly flicker when installing applications or resetting your board.

> **EXERCISE:** Extend the above app to print a simple message on the screen.
> You can use the `u8g2_SetDrawColor(&u8g2, 1);` method to draw in either the
> `0` or `1` color (i.e., foreground or background).
> `u8g2_DrawStr(&u8g2, $XCOORD, $YCOORD, $YOUR_STRING);` can be used to print a
> string to the display. Make sure you update the display contents with a final
> call to `u8g2_SendBuffer(&u8g2);`.

## Displaying the Current Temperature

As a first step to building our HVAC control user interface, we want the screen
to display the current temperature. For this, we consult the the sensor
application, which exposes this data via IPC.

The controller should regularly sample data from the sensor application. A naive
way to implement this is shown in the pseudo-code example below:

```
void ipc_callback(int temperature) {
  // Print temperature onto screen.
}

int main(void) {
  for (;;) {
    // Issue IPC request...

	// Wait for 250ms between requests:
	libtocksync_alarm_delay_ms(250);
}
```

This architecture has a few issues though. For instance, during the call to
`delay_ms`, the application is effectively prevented from doing other useful
work. While `delay_ms` does not spin and allows the kernel, other applications
or even callbacks into the same application to work, it does block the
application's main loop.

Another issue with this design is that the `ipc_callback` function performs
complex application code which may, in turn, wait on some asynchronous events
(callbacks) by inserting a yield point. This means that during the execution of
the `ipc_callback`, other callbacks -- including `ipc_callback` itself -- may be
scheduled again. Consider the following example:

```
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

As such, we instead architect our controller and sensor application interactions
using two callbacks and an asynchronous timer. It will work as follows:

1. The `main` function will request the `sensor` app to provide a temperature
   reading, and thus issue an IPC callback.
2. The IPC client callback will save the temperature value, and request a timer
   callback in 250 ms.
3. The timer callback will request an IPC service call from the sensor app,
   going back to step 2.

As such, this loop does not execute any blocking / `yield`ing operations in any
callback. It also moves all timing / scheduling logic out of the applications
main loop, which can instead look like this:

```
int main(void) {
  // Send initial IPC request

  // Yield in a loop, allowing callbacks to be run:
  for (;;) {
    yield();
  }
}
```

The final piece of the puzzle is to run blocking code in response to these
callbacks, but outside of the callback handlers themselves. For this, Tock
provides the `yield_for` function: it `yield`s the application, _until_ a
certain condition is met. For instance, the controller application sets the
`callback_event` boolean variable to `true` every time a callback is run. When
we want to wait on this event in our main function, we can use the following
logic:

```
// Shared variable to signal whether a callback has fired:
bool callback_event = false;

void ipc_callback() {
  // Indicate that a callback has fired:
  callback_event = true;
}

int main(void) {
  // Send initial IPC request

  // Yield in a loop, allowing callbacks to be run:
  for (;;) {
    // Wait for callback_event to be true:
    yield_for(&callback_event);
	// Reset callback_event to false for the next iteration:
	callback_event = false;

	// This code is executed whenever one or more callbacks have
	// fired. It can be long running and yield and will not be
	// re-entered:
	// ...
  }
}
```

> **EXERCISE:** The `03_controller_screen` checkpoint already contains the logic
> outlined above. Extend the main function to, in response to a callback, write
> the current temperature on a screen. You can do this by extending the
> `update_screen` function. You might find it useful to split this code out into
> a different function.

Finally, we will wire up this application to the OpenThread network to send the
current temperature setpoint to all other control units, and retrieve an average
value back. We provide some useful scaffolding for this in the next checkpoint,
so it is advisable to either switch to that, or copy the commented out function
signatures for OpenThread communication and integration at this point:

> **CHECKPOINT:** `04_controller_thread`

We [continue here](comms-app.md).
