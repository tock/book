# Using HMAC-SHA256 in Userspace

Our next task is we need an HMAC engine for our HOTP application to use. Tock
already includes HMAC-SHA256 as a capsule within the kernel, we just need to
expose it to userspace.

## Background

An HMAC engine is a necessary tool for a HOTP security key. From
[Wikipedia](https://en.wikipedia.org/wiki/HMAC):

> An HMAC...is a specific type of message authentication code (MAC) involving a
> cryptographic hash function and a secret cryptographic key. As with any MAC,
> it may be used to simultaneously verify both the data integrity and
> authenticity of a message. An HMAC is a type of keyed hash function that can
> also be used in a key derivation scheme or a key stretching scheme.

An HMAC is computed roughly using the following equation (for simplicity this
omits details on padding):

```
HMAC = Hash(Key + Hash(Key + Message))
```

The result is a output the length of the output of the hash function used.
Because the key is used inside the hash operation, only someone who knows the
secret key can compute the correct HMAC (authenticity). And because the message
is used inside the hash operation, if the message is altered the HMAC will no
longer match (integrity).

HMAC supports any hash function, but the specific hash function used affects the
resulting HMAC. Therefore we must specify. In this example, we will use the
SHA256 hash algorithm. That means the resulting HMAC will be 32 bytes long.

## Configuring the Kernel

### 1. Define Types for HMAC

For convenience we declare the component types at the top of main.rs for the
HMAC capsules.

As we are using a software implementation of the SHA-256 algorithm, we do not
need to customize any types for our specific microcontroller.

Include this near the top of main.rs (above the Platform struct):

```rust
// HMAC
type HmacSha256Software = components::hmac::HmacSha256SoftwareComponentType<
    capsules_extra::sha256::Sha256Software<'static>,
>;
type HmacDriver = components::hmac::HmacComponentType<HmacSha256Software, 32>;
```

### 2. Instantiate the Components

Next we need to use components to instantiate a software implementation of
SHA256 and HMAC-SHA256. Add this towards the bottom of your main.rs file.

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
.finalize(components::hmac_component_static!(HmacSha256Software, 32));
```

### 3. Expose HMAC to Userspace

Next add these capsules to the `Platform` struct:

```rust
pub struct Platform {
	...
	hmac: &'static HmacDriver,
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
