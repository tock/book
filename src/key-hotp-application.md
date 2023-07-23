# HOTP Application

The motivating example for this entire tutorial is the creation of a USB
security key: a USB device that can be connected to your computer and
authenticate you to some service. One open standard for implementing such keys
is
[HMAC-based One-Time Password (HOTP)](https://en.wikipedia.org/wiki/HMAC-based_one-time_password).
It generates the 6 to 8 digit numeric codes which are used as a second-factor
for some websites.

The crypto for implementing HOTP has already been created (HMAC and SHA256), so
you certainly don't have to be an expert in cryptography to make this
application work. We have actually implemented the software for generating HOTP
codes as well. Instead, you will focus on improving that code as a demonstration
of Tock and its features.

On the application side, we'll start with a basic HOTP application which has a
pre-compiled HOTP secret key. Milestone one will be improving that application
to take user input to reconfigure the HOTP secret. Milestone two will be adding
the ability to persistently store the HOTP information so it is remembered
across resets and power cycles. Finally, milestone three will be adding the
ability to handle multiple HOTP secrets simultaneously.

The application doesn't just calculate HOTP codes, it implements a USB HID
device as well. This means that when plugged in through the proper USB port, it
appears as an additional keyboard to your computer and is capable of entering
text.

We have provided starter code as well as completed code for each of the
milestones. If you're facing some bugs which are limiting your progress, you can
reference or even wholesale copy a milestone in order to advance to the next
parts of the tutorial.

## Applications in Tock

A few quick details on applications in Tock.

Applications in Tock look much closer to applications on traditional OSes than
to normal embedded software. They are compiled separately from the kernel and
loaded separately onto the hardware. They can be started or stopped individually
and can be removed from the hardware individually. Importantly for later in this
tutorial, the kernel is really in full control here and can decide which
applications to run and what permissions they should be given.

Applications make requests from the OS kernel through system calls, but for the
purposes of this part of the tutorial, those system calls are wrapped in calls
to driver libraries. The most important aspect though is that results from
system calls never interrupt a running application. The application must `yield`
to receive callbacks. Again, this is frequently hidden within synchronous
drivers, but our application code will have a `yield` in the main loop as well,
where it waits for button presses.

The tool for interacting with Tock applications is called `Tockloader`. It is a
python package capable of loading applications onto a board, inspecting
applications on a board, modifying application binaries before they are loaded
on a board, and opening a console to communicate with running applications.
We'll reference various `Tockloader` commands which you'll run throughout the
tutorial.

## Starter Code

We'll start by playing around with the starter code which implements a basic
HOTP key.

- Within the `libtock-c` checkout, navigate to
  `libtock-c/examples/tutorials/hotp/hotp_starter/`.

  This contains the starter code for the HOTP application. It has a hardcoded
  HOTP secret and generates an HOTP code from it each time the Button 1 on the
  board is pressed.

- To compile the application and load it onto your board, run `make flash` in
  the terminal (running just `make` will compile but not upload).

  - You likely want to remove other applications that are running on your board
    if there are any. You can see which applications are installed with
    `tockloader list` and you can remove an app with `tockloader uninstall` (it
    will let you choose which app(s) to remove). Bonus information: `make flash`
    is just a shortcut for `make && tockloader install`.

- To see console output from the application, run `tockloader listen` in a
  separate terminal.

> **TIP:** You can leave the console running, even when compiling and uploading
> new applications. It's worth opening a second terminal and leaving
> `tockloader listen` always running.

- Since this application creates a USB HID device to enter HOTP codes, you'll
  need a second USB cable which will connect directly to the microcontroller.
  Plug it into the port on the left-hand side of the nRF52840DK labeled "nRF
  USB".

  - After attaching the USB cable, you should restart the application by hitting
    the reset button the nRF52840DK labeled "IF BOOT/RESET".

- To generate an HOTP code, press "Button 1" on the nRF5240DK. You should see a
  message printed to console output that says
  `Counter: 0. Typed "750359" on the USB HID the keyboard`.

  The HOTP code will also be written out over the USB HID device. The six-digit
  number should appear wherever your cursor is.

- You can verify the HOTP values with
  [https://www.verifyr.com/en/otp/check#hotp](https://www.verifyr.com/en/otp/check#hotp)

  Go to section "#2 Generate HOTP Code". Enter "test" as the HOTP Code to auth,
  the current counter value from console as the Counter, "sha256" as the
  Algorithm, and 6 as the Digits. Click "Generate" and you'll see a six-digit
  HOTP code that should match the output of the Tock HOTP app.

- The source code for this application is in the file `main.c`.

  This is roughly 300 lines of code and includes Button handling, HMAC use and
  the HOTP state machine. Execution starts at the `main()` function at the
  bottom of the file.

- Play around with the app and take a look through the code to make sure it
  makes sense. Don't worry too much about the HOTP next code generation, as it
  already works and you won't have to modify it.

> **Checkpoint**: You should be able to run the application and have it output

    HOTP codes over USB to your computer when Button 1 is pressed.

## Milestone One: Configuring Secrets

The first milestone is to modify the HOTP application to allow the user to set a
secret, rather than having a pre-compiled default secret. Completed code is
available in `hotp_milestone_one/` in case you run into issues.

- First, modify the code in main() to detect when a user wants to change the
  HOTP secret rather than get the next code.

  The simplest way to do this is to sense how long the button is held for. You
  can delay a short period, roughly 500 ms would work well, and then read the
  button again and check if it's still being pressed. You can wait synchronously
  with the
  [`delay_ms()` function](https://github.com/tock/libtock-c/blob/master/libtock/timer.h)
  and you can read a button with the
  [`button_read()` function](https://github.com/tock/libtock-c/blob/master/libtock/button.h).

  - Note that buttons are indexed from 0 in Tock. So "Button 1" on the hardware
    is button number 0 in the application code. All four of the buttons on the
    nRF52840DK are accessible, although the `initialize_buttons()` helper
    function in main.c only initializes interrupts for button number 0. (You can
    change this if you want!)

  - An alternative design would be to use different buttons for different
    purposes. We'll focus on the first method, but feel free to implement this
    however you think would work best.

- For now, just print out a message when you detect the user's intent. Be sure
  to compile and upload your modified application to test it.

- Next, create a new helper function to allow for programming new secrets. This
  function will have three parts:

  1. The function should print a message about wanting input from the user.

     - Let them know that they've entered this mode and that they should type a
       new HOTP secret.

  2. The function should read input from the user to get the base32-encoded
     secret.

     - You'll want to use the
       [Console functions `getch()` and `putnstr()`](https://github.com/tock/libtock-c/blob/master/libtock/console.h).
       `getch()` can read characters of user input while `putnstr()` can be used
       to echo each character the user types. Make a loop that reads the
       characters into a buffer.

     - Since the secret is in base32, special characters are not valid. The
       easiest way to handle this is to check the input character with
       [`isalnum()`](https://cplusplus.com/reference/cctype/isalnum/) and ignore
       it if it isn't alphanumeric.

     - When the user hits the enter key, a `\n` character will be received. This
       can be used to break from the loop.

  3. The function should decode the secret and save it in the `hotp-key`.

     - Use the `program_default_secret()` implementation for guidance here. The
       `default_secret` takes the place of the string you read from the user,
       but otherwise the steps are the same.

- Connect the two pieces of code you created to allow the user to enter a new
  key. Then upload your code to test it!

  - You can test that the new secret works with
    [https://www.verifyr.com/en/otp/check#hotp](https://www.verifyr.com/en/otp/check#hotp)
    as described previously.

> **Checkpoint**: Your HOTP application should now take in user-entered secrets
> and generate HOTP codes for them based on button presses.

## Milestone Two: Persistent Secrets

The second milestone is to save the HOTP struct in persistent Flash rather than
in volatile memory. After doing so, the secret and current counter values will
persist after resets and power outages. We'll do the saving to flash with the
App State driver, which allows an application to save some information to its
own Flash region in memory. Completed code is available in `hotp_milestone_two/`
in case you run into issues.

- First, understand how the App State driver works by playing with some example
  code. The App State test application is available in
  [`libtock-c/examples/tests/app_state/main.c`](https://github.com/tock/libtock-c/blob/master/examples/tests/app_state/main.c)

  - Compile it and load it onto your board to try it out.

  - If you want to uninstall the HOTP application from the board, you can do so
    with `tockloader uninstall`. When you're done, you can use that same command
    to remove this application.

- Next, we'll go back to the HOTP application code and add our own App State
  implementation.

  Start by creating a new struct that holds both a `magic` field and the HOTP
  key struct.

  - The value in the `magic` field can be any unique number that is unlikely to
    occur by accident. A 32-bit value (that is neither all zeros nor all ones)
    of your choosing is sufficient.

- Create an App State initialization function that can be called from the start
  of `main()` which will load the struct from Flash if it exists, or initialize
  it and store it if it doesn't.

  - Be sure to call the initialization function _after_ the one-second delay at
    the start of `main()` so that it doesn't attempt to modify Flash during
    resets while uploading code.

- Update code throughout your application to use the HOTP key inside of the App
  State struct.

  You'll also need to synchronize the App State whenever part of the HOTP key is
  modified: when programming a new secret or updating the counter.

- Upload your code to test it. You should be able to keep the same secret and
  counter value on resets and also on power cycles.

  - There is an on/off switch on the top left of the nRF52840DK you can use for
    power cycling.

  - Note that uploading a modified version of the application _will_ overwrite
    the App State and lose the existing values inside of it.

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

  - Make the HOTP key in the App State struct into an array with up to four
    slots.

  - Having multiple key slots allows for different numbers of digits for the
    HOTP code on different slots, which you could experiment with.

> **Checkpoint:** Your application should now hold multiple HOTP keys, each of
> which can be configured and is persistent across reboots.
