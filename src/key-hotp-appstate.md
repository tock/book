# Using Nonvolatile Application State in Userspace

When we use the HOTP application to store new keys, we want those keys to be
persistent across reboots. That is, if we unplug the USB key, we would like our
saved keys to still be accessible when we plug the key back in.

To enable this, we are using the `app_state` capsule. This allows userspace
applications to edit their own flash region. We will use that flash region to
save our known keys.

## Configuring the Kernel

Again we will use components to add app_state to the kernel. To add the proper
drivers, include this in the main.rs file:

```rust
//--------------------------------------------------------------------------
// APP FLASH
//--------------------------------------------------------------------------

let mux_flash = components::flash::FlashMuxComponent::new(&base_peripherals.nvmc).finalize(
    components::flash_mux_component_static!(nrf52840::nvmc::Nvmc),
);

let virtual_app_flash = components::flash::FlashUserComponent::new(mux_flash).finalize(
    components::flash_user_component_static!(nrf52840::nvmc::Nvmc),
);

let app_flash = components::app_flash_driver::AppFlashComponent::new(
    board_kernel,
    capsules_extra::app_flash_driver::DRIVER_NUM,
    virtual_app_flash,
)
.finalize(components::app_flash_component_static!(
    capsules_core::virtualizers::virtual_flash::FlashUser<'static, nrf52840::nvmc::Nvmc>,
    512
));
```

Then add these capsules to the `Platform` struct:

```rust
pub struct Platform {
	...
	app_flash: &'static capsules_extra::app_flash_driver::AppFlash<'static>,
    ...
}

let platform = Platform {
    ...
    app_flash,
    ...
};
```

And make them accessible to userspace by adding to the `with_driver` function:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
        	...
            capsules_extra::app_flash_driver::DRIVER_NUM => f(Some(self.app_flash)),
            ...
        }
    }
}
```

> **Checkpoint:** App Flash is now accessible to userspace!
