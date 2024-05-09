# Building the User Interface

In the previous stage we have built a *sensor application* that is
able to query the Tock kernel for the current temperature and expose
this value as an IPC service. We also provide a minimal *controller
application* which uses this service and prints the temperature value
onto the console.

However, this is not a great user interface. In this stage of the
tutorial, we will extend this application to display information on an
OLED screen attached to the board. For this we use the Tock kernel's
screen driver support, in addition to the `u8g2` graphics library.

> **CHECKPOINT:** `02_sensor_final` + `03_controller_screen`
>
> We assume that the sensor application is already loaded onto the
> board, and that the provided control application is able to print
> the temperature retrieved via IPC.

## Adding the `u8g2` Library

Tock is able to run arbitrary code in its userspace applications,
including existing C libraries. For this stage in particular, we are
interested in displaying information on a screen. Without a library to
render text or symbols, this can be quite cumbersome. Instead, we will
use the `u8g2` library for which `libtock-c` provides some bindings.

To add this library to our application we add the following two lines
to our application's `Makefile`, before the `AppMakefile.mk` include:

```makefile
STACK_SIZE  = 4096
EXTERN_LIBS += $(TOCK_USERLAND_BASE_DIR)/u8g2
```

We increase the size of the stack that is pre-allocated for the
application, as `libtock-c` by default allocates a stack of 2 kB which
is insufficient for `u8g2`. We then specify that our application
depends on the `u8g2` library, by adding the `libtock-c/u8g2`
directory to `EXTERN_LIBS`. This directory contains a wrapper that
allows the `u8g2` library to communicate with Tock's screen driver
system calls and ensures that the library can be used from within our
application.

Once this is done, we can add some initialization code to our
controller application:

```
#include <u8g2.h>
#include <u8g2-tock.h>

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

When we now build and install this app, it should still display the
temperature readouts on the serial console. However, it should also
clear the screen and you may see repeatedly flicker when installing
applications or resetting your board.

> **EXERCISE:** Extend the above app to print a simple message on the
> screen. You can use the `u8g2_SetColor(&u8g2, 1);` method to draw in
> either the `0` or `1` color (i.e., foreground or background).
> `u8g2_DrawStr(&u8g2, $XCOORD, $YCOORD, $YOUR_STRING);` can be used
> to print a string to the display. Make sure you update the dislay
> contents with a final call to `u8g2_SendBuffer`.

## Displaying the Current Temperature

