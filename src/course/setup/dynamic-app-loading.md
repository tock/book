# Implementing the Dynamic Application Loader

The Tock kernel supports implementing a dynamic application loader that allows
an external application to store and execute a new application.

We use the `app_loader` capsule. This will setup the bridge between the
userspace application and the kernel for loading new applications. The
`app_loader` capsule requires a `dynamic_binary_storage` driver to store and
load the application, so we need to set that up as well.

## Configuring the Kernel

We will use components to add app_state to the kernel. To add the proper
drivers, include this in the main.rs file:

```rust

//--------------------------------------------------------------------------
// Syscall Driver Type Definitions
//--------------------------------------------------------------------------

type FlashUser = nrf52833::nvmc::Nvmc;
type NonVolatilePages = components::dynamic_binary_storage::NVPages<FlashUser>;
type DynamicBinaryStorage<'a> = kernel::dynamic_binary_storage::SequentialDynamicBinaryStorage<
    'static,
    'static,
    nrf52840::chip::NRF52<'a, Nrf52840DefaultPeripherals<'a>>,
    kernel::process::ProcessStandardDebugFull,
    NonVolatilePages,
>;
type AppLoaderDriver = capsules_extra::app_loader::AppLoader<
    DynamicBinaryStorage<'static>,
    DynamicBinaryStorage<'static>,
>;


//--------------------------------------------------------------------------
// Dynamic App Loading
//--------------------------------------------------------------------------

// Create the dynamic binary flasher.
let dynamic_binary_storage =
    components::dynamic_binary_storage::SequentialBinaryStorageComponent::new(
        virtual_flash_dbs,
        loader,
    )
    .finalize(components::sequential_binary_storage_component_static!(
        FlashUser,
        nrf52840::chip::NRF52<Nrf52840DefaultPeripherals>,
        kernel::process::ProcessStandardDebugFull,
    ));

// Create the dynamic app loader capsule.
let dynamic_app_loader = components::app_loader::AppLoaderComponent::new(
    board_kernel,
    capsules_extra::app_loader::DRIVER_NUM,
    dynamic_binary_storage,
    dynamic_binary_storage,
)
.finalize(components::app_loader_component_static!(
    DynamicBinaryStorage<'static>,
    DynamicBinaryStorage<'static>,
));
```

```
Note:
1. The definition of the `FlashUser` type is hardware dependent.
2. If there are other applications that use the `IsolatedNonvolatileStorage` capsule,
we have to virtualize the flash. In that case, the `FlashUser` type will look something
like:

type FlashUser =
    capsules_core::virtualizers::virtual_flash::FlashUser<'static, nrf52840::nvmc::Nvmc>;
```

Then add the capsule to the `Platform` struct:

```rust
pub struct Platform {
	...
	dynamic_app_loader: &'static AppLoaderDriver,
    ...
}

let platform = Platform {
    ...
    dynamic_app_loader,
    ...
};
```

And make it accessible to userspace by adding to the `with_driver` function:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
        	...
            capsules_extra::app_loader::DRIVER_NUM => f(Some(self.dynamic_app_loader)),
            ...
        }
    }
}
```

> **Checkpoint:** App Loader is now accessible to userspace!
