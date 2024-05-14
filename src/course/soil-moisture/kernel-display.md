# Soil Moisture Display Kernel Configuration

In this submodule we will continue to configure the Tock kernel to support a
screen so we can display the soil moisture reading to users.

## Background and Goal

Our goal with the display is to eventually support _multiple_ applications which
can write to the display. This poses an issue as the two applications will not
know about each other, will try to write to the same display, and will overwrite
what the other has written.

What we need is some way to virtualize or share the screen. To accomplish this,
we will effectively create windows, or regions, of the display and allow
different applications to use different windows/regions. In practice, these
windows will be rectangular and non-overlapping for simplicity. This, however,
poses a new issue: which app gets which window? If we assign in some arbitrary
order (e.g., first-come first-served, or based on `ProcessId`) then the windows
can switch depending on exactly which apps are installed and the order they are
flashed on the board. This gets confusing, and if we want different apps to have
different size windows, then we want to be able to fix an app to a particular
window.

What we now need is some way to persistently identify an application, and to map
those identifiers to our screen windows. In Tock, we can accomplish this with
the AppId feature. AppId allows for app developers to cryptographically attach
an application identifier to a particular application. We won't be using the
support for cryptographic assignment, but we will use the AppId mechanism to
ensure that our applications have persistent identifiers we can use when
assigning screen windows.

## Enabling the Screen

We start, however, by configuring our Tock kernel to support a display. This
guide assumes you are using a SSD1306-based OLED display (like
[this one](https://www.amazon.com/UCTRONICS-SSD1306-Self-Luminous-Display-Raspberry/dp/B072Q2X2LL)).
You can use other displays, but note you will have to use a different driver and
connection to the screen.

1.  Setup the I2C bus to connect to the screen. We will instantiate an I2C mux
    using one of the hardware I2C peripherals, and then define an `I2CDevice` to
    use for the screen.

    ```rust
    const I2C_SDA_PIN: Pin = Pin::P0_26;
    const I2C_SCL_PIN: Pin = Pin::P0_27;

    let i2c_bus = components::i2c::I2CMuxComponent::new(&base_peripherals.twi0, None)
        .finalize(components::i2c_mux_component_static!(nrf52840::i2c::TWI));
    base_peripherals.twi0.configure(
        nrf52840::pinmux::Pinmux::new(I2C_SCL_PIN as u32),
        nrf52840::pinmux::Pinmux::new(I2C_SDA_PIN as u32),
    );

    // I2C address is b011110X, and on this board D/C̅ is GND.
    let ssd1306_i2c = components::i2c::I2CComponent::new(i2c_bus, 0x3c)
        .finalize(components::i2c_component_static!(nrf52840::i2c::TWI));
    ```

2.  Next, we instantiate the actual driver for the SSD1306 display. This uses
    the I2C device we created in the previous step.

    ```rust
    const I2C_SDA_PIN: Pin = Pin::P0_26;
    const I2C_SCL_PIN: Pin = Pin::P0_27;

    let i2c_bus = components::i2c::I2CMuxComponent::new(&base_peripherals.twi0, None)
        .finalize(components::i2c_mux_component_static!(nrf52840::i2c::TWI));
    base_peripherals.twi0.configure(
        nrf52840::pinmux::Pinmux::new(I2C_SCL_PIN as u32),
        nrf52840::pinmux::Pinmux::new(I2C_SDA_PIN as u32),
    );

    // I2C address is b011110X, and on this board D/C̅ is GND.
    let ssd1306_i2c = components::i2c::I2CComponent::new(i2c_bus, 0x3c)
        .finalize(components::i2c_component_static!(nrf52840::i2c::TWI));

    // Create the ssd1306 object for the actual screen driver.
    let ssd1306 = components::ssd1306::Ssd1306Component::new(ssd1306_i2c, true)
        .finalize(components::ssd1306_component_static!(nrf52840::i2c::TWI));
    ```

3.  For now, our last step is going to be instantiating a capsule to provide
    userspace with access to the screen. There are multiple capsules that
    support this, but we are going to use the `SharedScreen` capsule, as it
    supports creating screen windows and assigning the windows to applications.
    Again, for now we will just create an empty array of screen regions and
    assignments. We will fill this in later.

    ```rust
    const I2C_SDA_PIN: Pin = Pin::P0_26;
    const I2C_SCL_PIN: Pin = Pin::P0_27;

    type Screen = components::ssd1306::Ssd1306ComponentType<nrf52840::i2c::TWI<'static>>;

    let i2c_bus = components::i2c::I2CMuxComponent::new(&base_peripherals.twi0, None)
        .finalize(components::i2c_mux_component_static!(nrf52840::i2c::TWI));
    base_peripherals.twi0.configure(
        nrf52840::pinmux::Pinmux::new(I2C_SCL_PIN as u32),
        nrf52840::pinmux::Pinmux::new(I2C_SDA_PIN as u32),
    );

    // I2C address is b011110X, and on this board D/C̅ is GND.
    let ssd1306_i2c = components::i2c::I2CComponent::new(i2c_bus, 0x3c)
        .finalize(components::i2c_component_static!(nrf52840::i2c::TWI));

    // Create the ssd1306 object for the actual screen driver.
    let ssd1306 = components::ssd1306::Ssd1306Component::new(ssd1306_i2c, true)
        .finalize(components::ssd1306_component_static!(nrf52840::i2c::TWI));

    let apps_regions = static_init!(
        [capsules_extra::screen_shared::AppScreenRegion; 0],
        []
    );

    let screen = components::screen::ScreenSharedComponent::new(
        board_kernel,
        capsules_extra::screen::DRIVER_NUM,
        ssd1306,
        apps_regions,
    )
    .finalize(components::screen_shared_component_static!(1032, Screen));

    ssd1306.init_screen();
    ```

    We end up with a `screen` object we can use to handle syscalls from
    userspace.

### Connect Screen to Userspace

We allow system calls to use the screen in the same way we setup the GPIO and
ADC drivers.

Even though we are using the `ScreenShared` syscall driver capsule, the syscalls
are the same as with the `Screen` capsule. To make this transparent to
userspace, we use the same driver number for both screen syscall driver
capsules.

```rust
type ScreenDriver = components::screen::ScreenSharedComponentType<Screen>;

pub struct Platform {
    ...
    screen: &'static ScreenDriver,
    ...
}
```

Add the `screen` object to the platform struct.

```rust
let platform = Platform {
    ...
    screen,
    ...
};
```

Then make sure that userspace system calls can access the `screen` capsule:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
        	...
            capsules_core::screen::DRIVER_NUM => f(Some(self.screen)),
            ...
        }
    }
}
```

## Assigning AppIds

Next, we need to use Tock's application identifier mechanism to assign each
installed app a persistent AppId. Tock supports two versions of the AppId: the
full version and a `ShortId` which is 32 bits. The full AppId can be arbitrarily
large. In practice, we want to use the `ShortId` so we have a fixed size and
fixed overhead to use the application identifier.

AppIds (and `ShortId`s) are assigned when processes are loaded. Two policies are
used when doing this assignment:

1. An application credential checking policy (trait name
   `AppCredentialsPolicy`). This checks the cryptographic credentials attached
   to the application binary. The policy can determine what type of credentials
   are acceptable and whether an application binary has a valid credential.
2. An application identifier assignment policy (trait name `AppIdPolicy`). This
   assigns AppIds for processes and determines whether two application binaries
   are actually the same application (for example two versions of the same
   application).

For our purposes we only need the `AppIdPolicy` to assign predictable `ShortId`s
to our applications.

1.  Create an AppId assigner. We use a simple AppId assigner that generates a 32
    bit ShortId based on the process's name.

    ```rust
    // Create the AppID assigner.
    let assigner = components::appid::assigner_name::AppIdAssignerNamesComponent::new()
        .finalize(components::appid_assigner_names_component_static!());
    ```

2.  We also need a credential checker. At this point, we won't actually use
    credentials, so we can use a NULL credential checker.

    ```rust
    // Create the AppID assigner.
    let assigner = components::appid::assigner_name::AppIdAssignerNamesComponent::new()
        .finalize(components::appid_assigner_names_component_static!());

    // Create the null credential checker.
    let checking_policy = components::appid::checker_sha::AppCheckerNullComponent::new()
        .finalize();

    // Create the process checking machine.
    let checker = components::appid::checker::ProcessCheckerMachineComponent::new(checking_policy)
        .finalize(components::process_checker_machine_component_static!());
    ```

3.  Next we need an additional process binary array for the more advanced
    process loader.

    ```rust
    // Create the AppID assigner.
    let assigner = components::appid::assigner_name::AppIdAssignerNamesComponent::new()
        .finalize(components::appid_assigner_names_component_static!());

    // Create the null credential checker.
    let checking_policy = components::appid::checker_sha::AppCheckerNullComponent::new()
        .finalize();

    // Create the process checking machine.
    let checker = components::appid::checker::ProcessCheckerMachineComponent::new(checking_policy)
        .finalize(components::process_checker_machine_component_static!());

    let process_binary_array = static_init!(
        [Option<kernel::process::ProcessBinary>; NUM_PROCS],
        [None, None, None, None, None, None, None, None]
    );
    ```

4.  Now we can instantiate the actual process loader mechanism. This replaces
    any existing `load_processes()` function. We need to ensure the checker has
    the loader as a client and that the loader is registered and started.

    ```rust
    // Create the AppID assigner.
    let assigner = components::appid::assigner_name::AppIdAssignerNamesComponent::new()
        .finalize(components::appid_assigner_names_component_static!());

    // Create the null credential checker.
    let checking_policy = components::appid::checker_sha::AppCheckerNullComponent::new()
        .finalize();

    // Create the process checking machine.
    let checker = components::appid::checker::ProcessCheckerMachineComponent::new(checking_policy)
        .finalize(components::process_checker_machine_component_static!());

    let process_binary_array = static_init!(
        [Option<kernel::process::ProcessBinary>; NUM_PROCS],
        [None, None, None, None, None, None, None, None]
    );

    let loader = static_init!(
        kernel::process::SequentialProcessLoaderMachine<
            nrf52840::chip::NRF52<Nrf52840DefaultPeripherals>,
        >,
        kernel::process::SequentialProcessLoaderMachine::new(
            checker,
            &mut PROCESSES,
            process_binary_array,
            board_kernel,
            chip,
            core::slice::from_raw_parts(
                &_sapps as *const u8,
                &_eapps as *const u8 as usize - &_sapps as *const u8 as usize,
            ),
            core::slice::from_raw_parts_mut(
                &mut _sappmem as *mut u8,
                &_eappmem as *const u8 as usize - &_sappmem as *const u8 as usize,
            ),
            &FAULT_RESPONSE,
            assigner,
            &process_management_capability
        )
    );

    checker.set_client(loader);
    loader.register();
    loader.start();
    ```

Now the kernel will assign ShortIds to every process as the CRC of the process
name. This serves as the mechanism we can use to ensure we assign the same
screen window to the same process on every reboot.

## Assigning Screen Windows

Now we can assign portions of the screen to specific applications. This will
both ensure that a specific process will get the same window region on every
boot and regardless of how the processes are loaded on the board, and that any
apps without an allocated window will not have access to the screen.

To do this, we just need to populate the `apps_regions` array. We need to use
the same function the AppId policy uses to convert the process name to a
ShortId. Then we need to choose the region of the screen to allocate to that
process.

> Note: The screen windows must be aligned to a multiple of 8 pixels.

We will assign the bottom of the screen to the `soil-moisture-display` app.

```rust
fn crc(s: &'static str) -> u32 {
    kernel::utilities::helpers::crc32_posix(s.as_bytes())
}

let apps_regions = static_init!(
    [capsules_extra::screen_shared::AppScreenRegion; 1],
    [
        capsules_extra::screen_shared::AppScreenRegion::new(
            kernel::process::ShortId::Fixed(
                core::num::NonZeroU32::new(crc("soil-moisture-display")).unwrap()
            ),
            0,      // x
            6 * 8,  // y
            16 * 8, // width
            2 * 8   // height
        )
    ]
);
```

## Wrap Up

You can now compile and load the kernel. This will support both the
`soil-moisture-sensor` and `soil-moisture-display` apps.
