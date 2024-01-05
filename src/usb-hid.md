# Implementing a USB Keyboard Device

The Tock kernel supports implementing a USB device and we can setup our kernel
so that it is recognized as a USB keyboard device. This is necessary to enable
the HOTP key to send the generated key to the computer when logging in.

## Configuring the Kernel

We need to setup our kernel to include USB support, and particularly the USB HID
(keyboard) profile. This requires modifying the board's `main.rs` file. These
steps will guide you through adding the USB HID device as a new resource
provided by the Tock kernel on your hardware board. You will also expose this
resource to userspace via the syscall interface.

You should add the following setup near the end of main.rs, just before the
creating the `Platform` struct.

### 1. USB Strings

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

### 2. Include USB HID Capsule

Then we need to instantiate the keyboard USB capsule in the board. This capsule
provides the USB Keyboard HID stack needed to interface with the USB hardware
and provide an interface to communicate as a HID device.

In general, adding a capsule to a Tock kernel can be somewhat cumbersome. To
simplify this, we use what we call a "component" to bundle all of the setup. We
can use the pre-made `KeyboardHidComponent` component.

This example works for the nRF52840dk. You will need to modify the types if you
are using a different microcontroller.

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

### 3. Activate USB HID Support

Towards the end of the main.rs, you need to enable the USB HID driver:

```rust
keyboard_hid.enable();
keyboard_hid.attach();
```

### 4. Expose USB HID to Userspace

Finally, we need to make sure that userspace applications can use the USB HID
interface.

First, we need to keep track of a reference to our USB HID stack by adding the
driver to the `Platform` struct:

```rust
pub struct Platform {
	...
	keyboard_hid_driver: &'static capsules_extra::usb_hid_driver::UsbHidDriver<
	    'static,
	    capsules_extra::usb::keyboard_hid::KeyboardHid<'static, nrf52840::usbd::Usbd<'static>>,
	>,
    ...
}
```

and then adding the object to where `Platform` is constructed:

```rust
let platform = Platform {
    ...
    keyboard_hid_driver,
    ...
};
```

Next we need to map syscalls from userspace to our kernel driver by editing the
`SyscallDriverLookup` implementation for the board:

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

## Compiling and Installing the Kernel

Now you should be able to compile the kernel and load it on to your board.

```
cd tock/boards/<board name>
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
