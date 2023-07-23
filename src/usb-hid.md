# Implementing a USB Keyboard Device

Our first task is to setup our kernel so that it is recognized as a USB keyboard
device.

## Configuring the Kernel

We need to setup our kernel to include USB support, and particularly the USB HID
(keyboard) profile.

To do that, uncomment the USB code in `boards/nordic/nrf52840dk/src/main.rs`.

**MORE HERE**

Compile the kernel and load it on to your board.

```
cd tock/boards/nordic/nrf52840dk
make install
```

## Connecting the USB Device

We will use both USB cables on our hardware. The main USB header is for
debugging and programming. The USB header connected directly to the
microcontroller will be the USB device. Ensure both USB devices are connected to
your computer.

## Testing the USB Keyboard

To test the USB keyboard device will will use a simple userspace application.
libtock-c includes an example app which just prints a string via USB keyboard
when a button is pressed.

```
cd libtock-c/examples/tests/keyboard_hid
make
tockloader install
```

Position your cursor somewhere benign, like a new terminal. Then press a button
on the board.

> **Checkpoint:** You should see a welcome message from your hardware!
