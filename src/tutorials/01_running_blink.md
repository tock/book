Blink: Running Your First App
=============================

This guide will help you get the `blink` app running on top of Tock kernel.

Instructions
------------

1. **Erase any existing applications**. First, we need to remove any applications already
on the board. Note that Tockloader by default will install any application in
addition to whatever is already installed on the board.

    ```bash
    $ tockloader erase-apps
    ```

2. **Install Blink**. Tock supports an "app store" of sorts. That is, tockloader
   can install apps from a remote repository, including Blink. To do this:

    ```bash
    $ tockloader install blink
    ```

    You will have to tell Tockloader that you are OK with fetching the app from
    the Internet.

    Your specific board may require additional arguments, please see the readme
    in the `boards/` folder for more details.

3. **Compile and Install Blink**. We can also compile the blink app and load our
   compiled version. The basic C version of blink is located in the
   [libtock-c](https://github.com/tock/libtock-c) repository. Clone that
   repository, then navigate to `examples/blink`. From there, you should be able
   to compile it and install it by:

    ```bash
    $ make
    $ tockloader install
    ```

    When the blink app is installed you should see the LEDs on the board
    blinking. Congratulations! You have just programmed your first Tock
    application.
