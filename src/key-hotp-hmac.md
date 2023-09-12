# Using HMAC-SHA256 in Userspace

Our next task is we need an HMAC engine for our HOTP application to use. Tock
already includes HMAC-SHA256 as a capsule within the kernel, we just need to
expose it to userspace.

## Configuring the Kernel

First we need to use components to instantiate a software implementation of
SHA256 and HMAC-SHA256. Add this to your main.rs file.

```rust
//--------------------------------------------------------------------------
// HMAC-SHA256
//--------------------------------------------------------------------------

let sha256_sw = components::sha::ShaSoftware256Component::new()
    .finalize(components::sha_software_256_component_static!());

let hmac_sha256_sw = components::hmac::HmacSha256SoftwareComponent::new(sha256_sw).finalize(
    components::hmac_sha256_software_component_static!(capsules_extra::sha256::Sha256Software),
);

let hmac = components::hmac::HmacComponent::new(
    board_kernel,
    capsules_extra::hmac::DRIVER_NUM,
    hmac_sha256_sw,
)
.finalize(components::hmac_component_static!(
    capsules_extra::hmac_sha256::HmacSha256Software<capsules_extra::sha256::Sha256Software>,
    32
));
```

Then add these capsules to the `Platform` struct:

```rust
pub struct Platform {
	...
	hmac: &'static capsules_extra::hmac::HmacDriver<
	    'static,
	    capsules_extra::hmac_sha256::HmacSha256Software<
	        'static,
	        capsules_extra::sha256::Sha256Software<'static>,
	    >,
	    32,
	>,
    ...
}

let platform = Platform {
    ...
    hmac,
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
            capsules_extra::hmac::DRIVER_NUM => f(Some(self.hmac)),
            ...
        }
    }
}
```

## Testing

You should be able to install the `libtock-c/examples/tests/hmac` app and run
it:

```
cd libtock-c/examples/tests/hmac
make
tockloader install
```

> **Checkpoint:** HMAC is now accessible to userspace!