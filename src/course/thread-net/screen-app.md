# Building the User Interface

In the previous stages we have built a _sensor application_ that is able to
query the Tock kernel for the current temperature and an openthread application
that is able to send and receive UDP packets. We now will build a user interface
so that you are able to request your desired temperature and avoid overheating
or freezing!

We will first build a simple button interface to introduce's Tock's concept of
callbacks. We will then expand this to utilize an OLED screen to display the
temperature readings and desired temperature setpoint.

> **CHECKPOINT:** `06_screen`

Now that you're familiar with `tock` and `libtock-c`, We begin making the screen
app with an empty application! Remember, if you get stuck at any point, we
include checkpoints along the way. Here we go!

## Adding the button interface

`tock` and `libtock-c` embrace an asynchronous design. Thus far, we have been
using the command syscalls the kernel exposes to userland. The `tock` kernel
also allows user applications to register callbacks so that applications can be
notified upon certain events. In practice, Tock userland apps often take the
form:

```
 [Register callback for event]
       	        |
                |
             [Yield]
                |
                |
               ...
                |
                |
    [Kernel invokes callback]
                |
                |
    [App continues execution]
```

Sometimes blocking an app with a synchronous function is useful. To accomodate
this, `libtock-c` libraries are split into `libtock-c` (which is async) and
`libtock-sync`. If you recall, we used a `libtock-sync` function to implement
the delay when reading the temperature sensor earlier. Internally, the
`libtock-sync` methods call the standard `libtock-c` async methods, but utilizes
the following pattern to provide the application with synchronous blocking
behavior:

```c
void yield_for(bool* cond) {
  while (!*cond) {
    yield();
  }
```

Another important consideration with callbacks is that the `tock` kernel will
only execute a pending callback once the application has yielded. This means
that the application developer should `yield` when waiting to receive a callback
from the kernel.

Now that we understand a bit more what's happening under the hood, let's add our
first callback!

`libtock-c` possess a wrapper to register a callback with the kernel that
corresponds to button presses:

```c
// Function signature for button press callbacks.
//
// - `arg1` (`returncode_t`): Returncode indicating status of button press.
// - `arg2` (`int`): Button index.
// - `arg3` (`bool`): True if pressed, false otherwise.
typedef void (*libtock_button_callback)(returncode_t, int, bool);

// Setup a callback when a button is pressed.
//
// ## Arguments
//
// - `button_num`: The index of the button.
// - `cb`: The function to be called when the button is pressed. Will be called
//   both when the button is pressed and when released.
returncode_t libtock_button_notify_on_press(int button_num, libtock_button_callback cb);
```

With this in mind, let's add a callback function to our screen app that prints
to the console. Add the following to `main.c`:

```c
#include <libtock/interface/button.h>

static void button_callback(returncode_t ret,
                            int          btn_num,
                            bool         pressed) {
  if (ret != RETURNCODE_SUCCESS) return;

  if (pressed) {
    printf("Button %i pressed!\r\n", btn_num);
  }
}
```

> **EXERCISE** Register our above `button_callback` with the
> `libtock_button_notify_on_press(...)` method.

> **HINTS**
>
> 1. We must register callbacks for each of the four buttons.
> 2. Did you remember to `yield`? The kernel will only execute an app's
>    registered callback if the application has yielded.
> 3. Does your `main()` return? We want this application to "run forever". Still
>    confused? an infinite loop with `yield()` inside the body should do the
>    trick :)

Let's build and flash this screen application to our board. Try pressing any of
the 4 buttons on the nRF52840dk (not the reset button). If you have correctly
implemented the callback, you should see:

```
tock$ reset
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$ Button 0 pressed!

```

> **CHECKPOINT** `07_screen_button`

## Adding the `u8g2` Library

Tock is able to run arbitrary code in its userspace applications, including
existing C libraries. For this stage in particular, we are interested in
displaying information on a screen. Without a library to render text or symbols,
this can be quite cumbersome. Instead, we will use the `u8g2` library with
`libtock-c` bindings.

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

Once this is done, we can add some initialization code to our screen
application:

```c
#include <u8g2.h>
#include <u8g2-tock.h>

// Global reference to the u8g2 context.
u8g2_t u8g2;

// Helper method to update and format u8g2 screen.
static void update_screen(void);

int main(void) {
  // Required initialization code:
  u8g2_tock_init(&u8g2);
  u8g2_SetFont(&u8g2, u8g2_font_profont12_tr);
  u8g2_SetFontPosTop(&u8g2);

  // Clear the screen:
  u8g2_ClearBuffer(&u8g2);
  u8g2_SendBuffer(&u8g2);

  [...]
}
```

When we now build and install this app, it should clear the screen and you may
see repeatedly flickering when installing applications or resetting your board.

> **EXERCISE:** Extend the above app to print a simple message on the screen.
> You can use the `u8g2_SetDrawColor(&u8g2, 1);` method to draw in either the
> `0` or `1` color (i.e., foreground or background).
> `u8g2_DrawStr(&u8g2, $XCOORD, $YCOORD, $YOUR_STRING);` can be used to print a
> string to the display. Make sure you update the display contents with a final
> call to `u8g2_SendBuffer(&u8g2);`.

Well done! Now we can begin adding the desired text for our HVAC controller.

We want our screen to display 3 lines of text:

```
Set Point: {VALUE}

Global Set Point: {VALUE}

Measured Temp: {VALUE}
```

The set point is _our_ desired temperature for the HVAC system. The global set
point is the average of all motes requested desired temperature. Finally, the
measured temperature is the temperature measured using the temperature sensor.

For use with the later stages of our application, it will be helpful to have a
function that performs the screen update. Add the following global variables and
a function of the form to our screen `main.c`:

```c
uint8_t global_temperature_setpoint = 0;
uint8_t local_temperature_setpoint  = 22;
uint8_t measured_temperature        = 0;

static void update_screen(void) {
  char temperature_set_point_str[35];
  char temperature_global_set_point_str[35];
  char temperature_current_measure_str[35];

  // TODO: Format output buffer; display text to screen.
}
```

> **EXERCISE** Extend `update_screen` to display our desired 3 lines of text and
> the value of the respective global variable.

> **HINT** `sprintf(...)` is useful for formating our char array.

As always, build and flash the screen application. At this point, you should see
3 strings on your u8g2 screen. If you are struggling to display the 3
strings, feel free to utilize the checkpoint!

> **CHECKPOINT** `08_screen_u8g2`

## Updating the Desired Local Temperature

We are now able to display text to our screen and also receive user input
through the button presses. With these pieces, we can begin building our
controller user interface! This interface will allow the user to input their
desired temperature setpoint. The nRF52840dk has 4 user input buttons. These
buttons are labeled 0-3 moving clockwise from the upper left button. We map the
buttons as follows:

- Button 0 => increase local setpoint (+1)
- Button 1 => decrease local setpoint (-1)
- Button 2 => reset local setpoint to 22 C

> **EXERCISE:** Update the `button_callback` to update the
> `local_temperature_setpoint` for button presses---using the above button
> mapping. When implementing this setpoint logic, ensure that the maximum
> setpoint is 35 C and that the minimum setpoint is 0 C.

If we build / flash this application, we notice that the screen remains at the
default values. This is because we need to call the update function when a
button is pressed. How can we do this?

We can naively update `main()` to update the screen within our main loop:

```c
  for(;;) {
    yield();
    update_screen();
  }
```

This will yield until the kernel fires a callback, at which point the u8g2
screen update function will be invoked. Although this works for our current
example, take a second to think why this may cause issues as we expand our
application.

You guessed it! Because this function will only yield until a callback is fired,
_any_ callback will cause our screen to be updated. This is somewhat
inefficient. We instead desire the application to yield _until_ a button press
occurs. Do you remember something we discussed earlier that might fill this
need? (hint, this was mentioned in the `libtock-sync` discussion).

Exactly! `yield_for`:

```c
void yield_for(bool* cond) {
  while (!*cond) {
    yield();
  }
```

This `libtock-sync` function will `yield` until our desired condition is met.
Let's add this to our screen application. To do this, we will add a global bool
variable

```c
bool callback_event = false;
```

> **EXERCISE**
>
> 1. Update the button callback to set the `callback_event` true
> 2. Update our infinite loop to use `yield_for(&callback_event)`.

As always, build and flash your screen application. You should now see that your
displayed local setpoint temperature updates with button presses!

> **CHECKPOINT:** `09_screen_final`

This concludes the screen app module. Continue on [here](ipc.md).
