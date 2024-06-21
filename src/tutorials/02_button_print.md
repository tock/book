# Say "Hello!" On Every Button Press

This tutorial will walk you through calling `printf()` in response to a button
press.

1. **Start a new application**. A Tock application in C looks like a typical C
   application. Lets start with the basics:

   ```c
   #include <stdio.h>

   int main(void) {
     return 0;
   }
   ```

   You also need a makefile. Copying a makefile from an existing app is the
   easiest way to get started.

2. **Setup a button callback handler**. A button press in Tock is treated as an
   interrupt, and in an application this translates to a function being called,
   much like in any other event-driven system. To listen for button presses, we
   first need to define a callback function.

   ```c
   #include <stdio.h>
   #include <libtock/interface/button.h>

   // Callback for button presses.
   //   btn_num: The index of the button associated with the callback
   //   val: true if pressed, false if depressed
   static void button_callback(
     returncode_t ret,
     int          btn_num,
     bool         val) {
   }

   int main(void) {
     return 0;
   }
   ```

   All callbacks in the libtock are specific to the individual driver, and the
   values provided depend on how the individual drivers work.

3. **Enable the button interrupts**. By default, the interrupts for the buttons
   are not enabled. To enable them, we make a syscall. Buttons, like other
   drivers in Tock, follow the convention that applications can ask the kernel
   how many there are. This is done by calling `button_count()`.

   ```c
   #include <stdio.h>
   #include <libtock/interface/button.h>

   // Callback for button presses.
   //   btn_num: The index of the button associated with the callback
   //   val: true if pressed, false if depressed
   static void button_callback(
     returncode_t ret,
     int          btn_num,
     bool         val) {
   }

   int main(void) {
     // Ensure there is a button to use.
     int count;
     libtock_button_count(&count);
     if (count < 1) {
       // There are no buttons on this platform.
       printf("Error! No buttons on this platform.\n");
     } else {
       // Enable an interrupt on the first button.
       libtock_button_notify_on_press(0, button_callback);
     }

     // Loop forever waiting on button presses.
     while (1) {
       yield();
     }
   }
   ```

   The button count is checked, and the app only continues if there exists at
   least one button. To enable the button interrupt,
   `libtock_button_notify_on_press()` is called with the index of the button to
   use. In this example we just use the first button.

   We then need to wait in a loop calling `yield()` to continue to receive
   button presses.

4. **Call `printf()` on button press**. To print a message, we call `printf()`
   in the callback.

   ```c
   #include <stdio.h>
   #include <libtock/interface/button.h>

   // Callback for button presses.
   //   btn_num: The index of the button associated with the callback
   //   val: true if pressed, false if depressed
   static void button_callback(
     __attribute__ ((unused)) returncode_t ret,
     __attribute__ ((unused)) int          btn_num,
     bool                                  val) {
     // Only print on the down press.
     if (val) {
       printf("Hello!\n");
     }
   }

   int main(void) {
     // Ensure there is a button to use.
     int count;
     libtock_button_count(&count);
     if (count < 1) {
       // There are no buttons on this platform.
       printf("Error! No buttons on this platform.\n");
     } else {
       // Enable an interrupt on the first button.
       libtock_button_notify_on_press(0, button_callback);
     }

     // Loop forever waiting on button presses.
     while (1) {
       yield();
     }
   }
   ```

5. **Run the application**. To try this tutorial application, you can find it in
   the
   [tutorials app folder](https://github.com/tock/libtock-c/tree/master/examples/tutorials/02_button_print).
   See the first tutorial for details on how to compile and install a C
   application.

   Once installed, when you press the button, you should see "Hello!" printed to
   the terminal!
