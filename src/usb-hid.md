# Implementing a USB Keyboard Device

The Tock kernel supports implementing a USB device and we can setup our kernel
so that it is recognized as a USB keyboard device. This is necessary to enable
the HOTP key to send the generated key to the computer when logging in.

## Configuring the Kernel

We need to setup our kernel to include USB support, and particularly the USB HID
(keyboard) profile. This requires modifying the boards `main.rs` file. You
should add the following setup near the end of main.rs, just before the creating
the `Platform` struct.

You first need to create three strings that will represent this device to the
USB host.

```rust
// Create the strings we include in the USB descriptor.
let strings = static_init!(
    [&str; 3],
    [
        "Nordic Semiconductor", // Manufacturer
        "nRF52840dk - TockOS",  // Product
        "serial0001",           // Serial number
    ]
);
```

Then we need to create the keyboard USB capsule in the board. This example works
for the nRF52840dk. You will need to modify the types if you are using a
different microcontroller.

```rust
let (keyboard_hid, keyboard_hid_driver) = components::keyboard_hid::KeyboardHidComponent::new(
    board_kernel,
    capsules_core::driver::NUM::KeyboardHid as usize,
    &nrf52840_peripherals.usbd,
    0x1915, // Nordic Semiconductor
    0x503a,
    strings,
)
.finalize(components::keyboard_hid_component_static!(
    nrf52840::usbd::Usbd
));
```

Towards the end of the main.rs, you need to enable the USB HID driver:

```rust
keyboard_hid.enable();
keyboard_hid.attach();
```

Finally, we need to add the driver to the `Platform` struct:

```rust
pub struct Platform {
	...
	keyboard_hid_driver: &'static capsules_extra::usb_hid_driver::UsbHidDriver<
	    'static,
	    capsules_extra::usb::keyboard_hid::KeyboardHid<'static, nrf52840::usbd::Usbd<'static>>,
	>,
    ...
}

let platform = Platform {
    ...
    keyboard_hid_driver,
    ...
};
```

and map syscalls from userspace to our kernel driver:

```rust
// Keyboard HID Driver Num:
const KEYBOARD_HID_DRIVER_NUM: usize = capsules_core::driver::NUM::KeyboardHid as usize;

impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
        	...
            KEYBOARD_HID_DRIVER_NUM => f(Some(self.keyboard_hid_driver)),
            ...
        }
    }
}
```

Now you should be able to compile the kernel and load it on to your board.

```
cd tock/boards/...
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
