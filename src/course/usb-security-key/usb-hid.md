# Implementing a USB Keyboard Device

The Tock kernel supports implementing a USB device and we can setup our kernel
so that it is recognized as a USB keyboard device. This is necessary to enable
the HOTP key to send the generated key to the computer when logging in.

## Background

This module configures your hardware board to be a USB HID device. From
[Wikipedia](https://en.wikipedia.org/wiki/USB_human_interface_device_class):

> The USB human interface device class (USB HID class) is a part of the USB
> specification for computer peripherals: it specifies a device class (a type of
> computer hardware) for human interface devices such as keyboards, mice, game
> controllers and alphanumeric display devices.
>
> The USB HID class describes devices used with nearly every modern computer.
> Many predefined functions exist in the USB HID class. These functions allow
> hardware manufacturers to design a product to USB HID class specifications and
> expect it to work with any software that also meets these specifications.

Enabling USB HID will allow your board to operate as a normal keyboard. As far
as your computer is concerned, you plugged in a USB keyboard. This means your
board and microcontroller can "type" to your computer.

## Configuring the Kernel

We need to setup our kernel to include USB support, and particularly the USB HID
(keyboard) profile. This requires modifying the board's `main.rs` file. These
steps will guide you through adding the USB HID device as a new resource
provided by the Tock kernel on your hardware board. You will also expose this
resource to userspace via the syscall interface.

### 1. USB Strings

You first need to create three strings that will represent this device to the
USB host.

You should add the following setup near the end of main.rs, just before the
creating the `Platform` struct.

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

### 2. Include USB HID Capsule Type

Now we need to instantiate the keyboard USB capsule in the board. This capsule
provides the USB Keyboard HID stack needed to interface with the USB hardware
and provide an interface to communicate as a HID device.

In general, adding a capsule to a Tock kernel can be somewhat cumbersome. To
simplify this, we use what we call a "component" to bundle all of the setup. We
can use the pre-made `KeyboardHidComponent` component.

First we define a type for the capsule, which is board-specific as it refers to
the specific microcontroller on the board. This type can become unwieldy and
redundant, so specifying a type makes adding the same capsule and component to
multiple boards more consistent.

Near the top of the main.rs file, include the correct definitions based on your
board. In particular, the `UsbHw` definition must match the type of the USB
hardware driver for your specific microcontroller.

```rust
// USB Keyboard HID - for nRF52840dk
type UsbHw = nrf52840::usbd::Usbd<'static>; // For any nRF52840 board.
type KeyboardHidDriver = components::keyboard_hid::KeyboardHidComponentType<UsbHw>;

// ------------------------------

// USB Keyboard HID - for imix
type UsbHw = sam4l::usbc::Usbc<'static>; // For any SAM4L board.
type KeyboardHidDriver = components::keyboard_hid::KeyboardHidComponentType<UsbHw>;
```

### 3. Include USB HID Capsule Component

Once we have the type we can include the actual component. This should go below
the `strings` object declared before.

Again the `usb_device` variable must match for your specific board. Choose the
type correctly from the examples in the code snippet.

```rust
// For nRF52840dk
let usb_device = &nrf52840_peripherals.usbd;

// For imix
let usb_device = &peripherals.usbc;

// Generic HID Keyboard component usage
let (keyboard_hid, keyboard_hid_driver) = components::keyboard_hid::KeyboardHidComponent::new(
    board_kernel,
    capsules_core::driver::NUM::KeyboardHid as usize,
    usb_device,
    0x1915, // Nordic Semiconductor
    0x503a,
    strings,
)
.finalize(components::keyboard_hid_component_static!(UsbHw));
```

### 4. Activate USB HID Support

Towards the end of the main.rs, you need to enable the USB HID driver:

```rust
keyboard_hid.enable();
keyboard_hid.attach();
```

### 5. Expose USB HID to Userspace

Finally, we need to make sure that userspace applications can use the USB HID
interface.

First, we need to keep track of a reference to our USB HID stack by adding the
driver to the `Platform` struct:

```rust
pub struct Platform {
	...
	keyboard_hid_driver: &'static KeyboardHidDriver,
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
