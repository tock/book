# HOTP Userspace Application

As a reminder, this module guides you through creating a USB security key: a USB
device that can be connected to your computer and authenticate you to some
service.

At this point, we have configured the Tock kernel to provide the baseline
resources necessary to implement the USB security key and use it with real
services. However, we still need to actually implement the security key's
operational logic. This submodule will guide you through creating a userspace
application that follows the HOTP protocol.

## Background

### HOTP USB Security Keys

One open standard for implementing USB security keys is
[HMAC-based One-Time Password (HOTP)](https://en.wikipedia.org/wiki/HMAC-based_one-time_password).
It generates the 6 to 8 digit numeric codes which are used as a second-factor
for some websites.

These security keys typically do not just calculate HOTP codes, but can also
enter them to your computer automatically. We will also enable that
functionality by having our devices function as a USB HID keyboard device as
well. This means that when plugged in through the proper USB port, it appears as
an additional keyboard to your computer and is capable of entering text.

### Applications in Tock

Tock applications look much closer to applications on traditional OSes than to
normal embedded software. They are compiled separately from the kernel and
loaded separately onto the hardware. They can be started or stopped individually
and can be removed from the hardware individually. Importantly for later in this
tutorial, the kernel decides which applications to run and what permissions they
should be given.

Applications make requests to the OS kernel through system calls. Applications
instruct the kernel using "command" system calls, and the kernel notifies
applications with "upcalls". Importantly, upcalls never interrupt a running
application. The application must `yield` to receive upcalls (i.e. callbacks).

The userspace library ("libtock") wraps system calls in easier to use functions.
Often the library functions include the call to `yield` and expose a synchronous
driver interface. Application code can also call `yield` directly as we will do
in this module.

## Submodule Overview

This stage builds up to a full-featured HOTP key application. We'll start with a
basic HOTP application which has a pre-compiled HOTP secret key. Then, each
milestone will add additional functionality:

1. Milestone one adds user input to reconfigure the HOTP secret.
2. Milestone two adds persistent storage for the HOTP information so it is
   remembered across resets and power cycles.
3. Milestone three adds support for multiple HOTP secrets simultaneously.

We have provided starter code as well as completed code for each of the
milestones. If you're facing some bugs which are limiting your progress, you can
reference or even wholesale copy a milestone in order to advance to the next
parts of the tutorial.

## Setup

There are two steps to check before you begin:

1. Make sure you have compiled and installed the Tock kernel with the USB HID,
   HMAC, and KV drivers on to your board.
2. Make sure you have no testing apps installed. To remove all apps:

   ```
   tockloader erase-apps
   ```

## Starter Code

We'll start with the starter code which implements a basic HOTP key.

1. Within `libtock-c`, navigate to
   `libtock-c/examples/tutorials/hotp/hotp_starter/`.

   This contains the starter code for the HOTP application. It has a hardcoded
   HOTP secret and generates an HOTP code from it each time the Button 1 on the
   board is pressed.

2. Compile the application and load it onto your board. In the app directory,
   run:

   ```
   make
   tockloader install
   ```

3. To see console output from the application, run `tockloader listen` in a
   separate terminal.

   > **TIP:** You can leave the console running, even when compiling and
   > uploading new applications. It's worth opening a second terminal and
   > leaving `tockloader listen` always running.

4. Since this application creates a USB HID device to enter HOTP codes, you'll
   need a second USB cable which will connect directly to the microcontroller.
   If you are using the nRF52840dk, plug the USB cable into the port on the
   left-hand side of the nRF52840DK labeled "nRF USB".

   After attaching the USB cable, you should restart the application by hitting
   the reset button (on the nRF52840DK it is labeled "IF BOOT/RESET").

5. To generate an HOTP code, press the first button ("Button 1" on the
   nRF5240DK). You should see a message printed to console output that says
   `Counter: 0. Typed "750359" on the USB HID the keyboard`.

   The HOTP code will also be written out over the USB HID device. The six-digit
   number should appear wherever your cursor is.

6. Verify the HOTP values with
   [https://www.verifyr.com/en/otp/check#hotp](https://www.verifyr.com/en/otp/check#hotp).
   Go to section "#2 Generate HOTP Code". Once there, enter:

   - "test" as the HOTP Code to auth
   - The current counter value from console as the Counter
   - "sha256" as the Algorithm
   - 6 as the Digits

   Click "Generate" and you'll see a six-digit HOTP code that should match the
   output of the Tock HOTP app.

The source code for this application is in the file `main.c`.

This is roughly 300 lines of code and includes Button handling, HMAC use and the
HOTP state machine. Execution starts at the `main()` function at the bottom of
the file.

Play around with the app and take a look through the code to make sure it makes
sense. Don't worry too much about the HOTP next code generation, as it already
works and you won't have to modify it.

> **Checkpoint**: You should be able to run the application and have it output
> HOTP codes over USB to your computer when Button 1 is pressed.

## Milestone One: Configuring Secrets

The first milestone is to modify the HOTP application to allow the user to set a
secret, rather than having a pre-compiled default secret. Completed code is
available in the `hotp_milestone_one/` folder in case you run into issues.

1. Modify the code in `main()` to detect when a user wants to change the HOTP
   secret rather than get the next code.

   The simplest way to do this is to sense how long the button is held for. You
   can delay a short period, roughly 500 ms would work well, and then read the
   button again and check if it's still being pressed. You can wait
   synchronously with the
   [`delay_ms()` function](https://github.com/tock/libtock-c/blob/master/libtock/timer.h)
   and you can read a button with the
   [`button_read()` function](https://github.com/tock/libtock-c/blob/master/libtock/button.h).

   - Note that buttons are indexed from 0 in Tock. So "Button 1" on the hardware
     is button number 0 in the application code. All four of the buttons on the
     nRF52840DK are accessible, although the `initialize_buttons()` helper
     function in main.c only initializes interrupts for button number 0. (You
     can change this if you want!)

   - An alternative design would be to use different buttons for different
     purposes. We'll focus on the first method, but feel free to implement this
     however you think would work best.

2. For now, just print out a message when you detect the user's intent. Be sure
   to compile and upload your modified application to test it.

3. Next, create a new helper function to allow for programming new secrets. This
   function will have three parts:

   1. The function should print a message about wanting input from the user.

      - Let them know that they've entered this mode and that they should type a
        new HOTP secret.

   2. The function should read input from the user to get the base32-encoded
      secret.

      - You'll want to use the
        [Console functions `getch()` and `putnstr()`](https://github.com/tock/libtock-c/blob/master/libtock/console.h).
        `getch()` can read characters of user input while `putnstr()` can be
        used to echo each character the user types. Make a loop that reads the
        characters into a buffer.

      - Since the secret is in base32, special characters are not valid. The
        easiest way to handle this is to check the input character with
        [`isalnum()`](https://cplusplus.com/reference/cctype/isalnum/) and
        ignore it if it isn't alphanumeric.

      - When the user hits the enter key, a `\n` character will be received.
        This can be used to break from the loop.

   3. The function should decode the secret and save it in the `hotp-key`.

      - Use the `program_default_secret()` implementation for guidance here. The
        `default_secret` takes the place of the string you read from the user,
        but otherwise the steps are the same.

4. Connect the two pieces of code you created to allow the user to enter a new
   key. Then upload your code to test it!

   - You can test that the new secret works with
     [https://www.verifyr.com/en/otp/check#hotp](https://www.verifyr.com/en/otp/check#hotp)
     as described previously.

> **Checkpoint**: Your HOTP application should now take in user-entered secrets
> and generate HOTP codes for them based on button presses.

## Milestone Two: Persistent Secrets

The second milestone is to save the HOTP struct in persistent flash rather than
in volatile memory. After doing so, the secret and current counter values will
persist after resets and when the USB device is unplugged. We'll do the saving
to flash with the Key-Value driver, which allows an application to save
information as key-value pairs. Completed code is available in
`hotp_milestone_two/` in case you run into issues.

1. In the HOTP application code we will store the persistent key data as the
   "value" in a key-value pair.

   Start by writing a function which saves the `hotp_key_t` object to a specific
   key (perhaps "hotp"). Use the `kv_set_sync()` function.

2. Now write a matching function which reads the same key to load the key data
   from persistent storage. Use the `kv_get_sync()` function.

3. Make sure to update the key-value pair whenever part of the HOTP key is
   modified, i.e. when programming a new secret or updating the counter.

4. Upload your code to test it. You should be able to keep the same secret and
   counter value on resets and also on power cycles.

- There is an on/off switch on the top left of the nRF52840DK you can use for
  power cycling.

> **Checkpoint:** Your application should now both allow for the configuring of
> HOTP secrets and the HOTP secret and counter should be persistent across
> reboots.

## Milestone Three: Multiple HOTP Keys

The third and final application milestone is to add multiple HOTP keys and a
method for choosing between them. This milestone is **optional**, as the rest of
the tutorial will work without it. If you're short on time, you can skip it
without issue. Completed code is available in `hotp_milestone_three/` in case
you run into issues.

- The recommended implementation of multiple HOTP keys is to assign one key per
  button (so four total for the nRF52840DK). A short press will advance the
  counter and output the HOTP code while a long press will allow for
  reprogramming of the HOTP secret.

- The implementation here is totally up to you. Here are some suggestions to
  consider:

  - Select which key you are using based on the button number of the most recent
    press. You'll also need to enable interrupts for all of the buttons instead
    of just Button 1.

  - Make the HOTP key into an array with up to four slots. Choose different key
    names for storage.

  - Having multiple key slots allows for different numbers of digits for the
    HOTP code on different slots, which you could experiment with.

> **Checkpoint:** Your application should now hold multiple HOTP keys, each of
> which can be configured and is persistent across reboots.
