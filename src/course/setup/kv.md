# Using Key-Value Storage in Userspace

To enable persistent storage across reboots, we can use Tock's Key-Value (KV)
interface. This allows userspace applications to store data in the form of
key-value pairs. Applications can retrieve data by querying for the given key.

## Checking if Key-Value Support Already Exists

Having key-value support is useful for many cases, and so it is possible that
your board already has key-value support enabled.

To check this, load the `kv_check` test app onto your board:

```
cd libtock-c/examples/tests/kv_check
make
tockloader install
```

Run `tockloader listen` and reset the board. You should see the following output
if KV support exists:

```
[KV] Check for Key-Value Support
Key-Value support is enabled.
```

> If KV support already exists, you can skip this module!

## Configuring the Kernel

Again we will use components to add key-value support to the kernel.

### 1. Include the Key-Value Stack Types

The KV stack includes many layers which leads to rather complex types. For more
information about the KV stack in Tock, see the [TicKV](../../course/tickv.md)
reference. To simplify somewhat, we define a series of types used at each layer
of the stack. Include these towards the top of main.rs:

```rust
// TicKV
type Mx25r6435f = components::mx25r6435f::Mx25r6435fComponentType<
    nrf52840::spi::SPIM<'static>,
    nrf52840::gpio::GPIOPin<'static>,
    nrf52840::rtc::Rtc<'static>,
>;
const TICKV_PAGE_SIZE: usize =
    core::mem::size_of::<<Mx25r6435f as kernel::hil::flash::Flash>::Page>();
type Siphasher24 = components::siphash::Siphasher24ComponentType;
type TicKVDedicatedFlash =
    components::tickv::TicKVDedicatedFlashComponentType<Mx25r6435f, Siphasher24, TICKV_PAGE_SIZE>;
type TicKVKVStore = components::kv::TicKVKVStoreComponentType<
    TicKVDedicatedFlash,
    capsules_extra::tickv::TicKVKeyType,
>;
type KVStorePermissions = components::kv::KVStorePermissionsComponentType<TicKVKVStore>;
type VirtualKVPermissions = components::kv::VirtualKVPermissionsComponentType<KVStorePermissions>;
type KVDriver = components::kv::KVDriverComponentType<VirtualKVPermissions>;
```

Note the first type is the underlying flash driver where the KV database is
actually stored. This will need to be customized for your specific board and
flash device.

### 2. Include the KV Components

Now we can use those types to instantiate the components for each layer of the
KV stack:

```rust
//--------------------------------------------------------------------------
// TICKV
//--------------------------------------------------------------------------

// Static buffer to use when reading/writing flash for TicKV.
let page_buffer = static_init!(
    <Mx25r6435f as kernel::hil::flash::Flash>::Page,
    <Mx25r6435f as kernel::hil::flash::Flash>::Page::default()
);

// SipHash for creating TicKV hashed keys.
let sip_hash = components::siphash::Siphasher24Component::new()
    .finalize(components::siphasher24_component_static!());

// TicKV with Tock wrapper/interface.
let tickv = components::tickv::TicKVDedicatedFlashComponent::new(
    sip_hash,
    mx25r6435f,
    0, // start at the beginning of the flash chip
    (capsules_extra::mx25r6435f::SECTOR_SIZE as usize) * 32, // arbitrary size of 32 pages
    page_buffer,
)
.finalize(components::tickv_dedicated_flash_component_static!(
    Mx25r6435f,
    Siphasher24,
    TICKV_PAGE_SIZE,
));

// KVSystem interface to KV (built on TicKV).
let tickv_kv_store = components::kv::TicKVKVStoreComponent::new(tickv).finalize(
    components::tickv_kv_store_component_static!(
        TicKVDedicatedFlash,
        capsules_extra::tickv::TicKVKeyType,
    ),
);

let kv_store_permissions = components::kv::KVStorePermissionsComponent::new(tickv_kv_store)
    .finalize(components::kv_store_permissions_component_static!(
        TicKVKVStore
    ));

// Share the KV stack with a mux.
let mux_kv = components::kv::KVPermissionsMuxComponent::new(kv_store_permissions).finalize(
    components::kv_permissions_mux_component_static!(KVStorePermissions),
);

// Create a virtual component for the userspace driver.
let virtual_kv_driver = components::kv::VirtualKVPermissionsComponent::new(mux_kv).finalize(
    components::virtual_kv_permissions_component_static!(KVStorePermissions),
);

// Userspace driver for KV.
let kv_driver = components::kv::KVDriverComponent::new(
    virtual_kv_driver,
    board_kernel,
    capsules_extra::kv_driver::DRIVER_NUM,
)
.finalize(components::kv_driver_component_static!(
    VirtualKVPermissions
));
```

This example is for the nRF52840dk board. You will likely need to change the
`mx25r6435f` flash driver to the flash driver appropriate for your board.

### 3. Update the `Platform` Struct and Expose KV to Userspace

We need to include the `kv_driver` in the board's platform struct:

Then add these capsules to the `Platform` struct:

```rust
pub struct Platform {
    ...
    kv_driver: &'static KVDriver,
    ...
}

let platform = Platform {
    ...
    kv_driver,
    ...
};
```

And make the syscall interface available to userspace:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
            ...
            capsules_extra::kv_driver::DRIVER_NUM => f(Some(self.kv_driver)),
            ...
        }
    }
}
```

> **Checkpoint:** Key-Value is now accessible to userspace!

## Testing and Trying Out KV Storage

With KV support in your Tock kernel, you can use the applications in
`libtock-c/examples/tests/kv*` to experiment with KV storage. In particular, the
`kv_interactive` app allows you to get and set key-value pairs.
