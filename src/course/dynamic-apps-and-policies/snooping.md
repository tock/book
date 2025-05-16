# Snooping on Hardware Events

Tock by default makes all system call interfaces accessible to all applications.
However, part of the configuration for a Tock kernel in the
[`Kernel Resources`](https://docs.tockos.org/kernel/platform/trait.kernelresources)
trait is a system call filter:

```rust
pub trait KernelResources {
    /// The implementation of the system call filtering mechanism the kernel
    /// will use.
    type SyscallFilter: SyscallFilter;

...
}
```

The [`SyscallFilter`](https://docs.tockos.org/kernel/platform/trait.syscallfilter) trait
includes a single function `filter_syscall()`:


```rust
pub trait SyscallFilter {
    fn filter_syscall(&self, process: &dyn Process, syscall: &Syscall) -> Result<(), ErrorCode>
}
```

This function is called on every system call from userspace before the kernel
handles the system call. If the function returns `Ok()` the system call proceeds.
If the function returns an `Err(ErrorCode)` that error is returned to the process
and the system call is not executed.

In this module we will explore how we can use a `SyscallFilter` implementation
to enforce stronger security properties for a Tock system.

## Eavesdropping on Button Presses

We use the buttons to navigate the interface on the Process Info application.
However, any application can register button notifications. To see this, we
can observe a perhaps unexpected operation of the `temperature` application.

If we run `tockloader listen` to observe the console output from the board,
while interacting with the Process Info app, you will see additional messages
from the temperature app:

```
insert console output
```

Maybe maliciously, or maybe for future use, the temperature app is actually
logging all button presses! Our goal is to prevent a theoretically innocuous
app (temperature) from eavesdropping on our button presses.

## System Call Filtering Approach

To securely restrict access to the buttons to only the Process Info application we need two things:

1. A way to cryptographically verify which process is the Process Info application.
2. A system call filtering policy that only allows the Process Info application to access the buttons system call.

To accomplish these in this module, we are going to setup an additional
application signing key that we will only use for the Process Info application.
We will configure the kernel that if an app is signed with that special key
then it will have access to the buttons. All other apps will be denied access
to the buttons.

To record which key was used to sign each applications, we will use a specific
`AppId` assigning algorithm. We will encode the signing key identifier into the
upper four bits of the 32-bit `ShortId` for the app. This is the first hex
digit. An application that was not cryptographically signed will have this
nibble set to `0xF`. An application signed with the first key will have this set to 0,
second key will be 1, and so on.

> `AppId` is the system that Tock uses to cryptographically attach an identifier
> to Tock applications. The mechanism is meant to be very flexible to support a wide range of use cases.
> The common way `AppId` is used is by assigning a 32-bit `ShortId` to each
> application
> when that process is loaded. Multiple processes can belong to the same application (e.g., different versions of the same app)
> and the kernel will ensure that only one process per application is ever
> executed at the same time.
>
> You can read more about `AppId` [here](https://book.tockos.org/trd/trd-appid).

Now, the `ShortId` for each process will include information about the signing key used to sign the app.
We will use this information to determine if the buttons should be filtered.

### Application ID Assignment

The kernel configuration for the tutorial board is already setup to assign `ShortId`s based on the signing key used
when verifying the app's signature. The format of the `ShortId` looks like this:

```text
32         28                       0 bits
+----------+------------------------+
| metadata | CRC(name)              |
+----------+------------------------+
```

And the code to implement this requires creating a custom implementation of the
[`Compress`](https://docs.tockos.org/kernel/process_checker/trait.compress) trait.
This must create the `ShortId` based on the results from the signature checker. The signature checker
saves the key ID that verified the signature in the "metadata" field from the accepted credential.

The general structure of that assignment policy looks like:

```rust
pub struct AppIdAssignerNameMetadata {}

impl kernel::process_checker::Compress for AppIdAssignerNameMetadata {
    fn to_short_id(&self, process: &ProcessBinary) -> ShortId {
        // Get the stored metadata returned when this process had its credential
        // checked. If there is no accepted credential use 0xF.
        let metadata = process.credential.get().map_or(0xF, |accepted_credential| {
            accepted_credential
                .metadata
                .map_or(0xF, |metadata| metadata.metadata) as u32
        });

        let name = process.header.get_package_name().unwrap_or("");
        let sum = kernel::utilities::helpers::crc32_posix(name.as_bytes());

        // Combine the metadata and CRC into the short id.
        let sid = ((metadata & 0xF) << 28) | (sum & 0xFFFFFFF);

        core::num::NonZeroU32::new(sid).into()
    }
}
```

You can see the full implementation in `tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies/src/app_id_assigner_name_metadata.rs`.

### System Call Filtering

Now with the `ShortId` conveying which key signed each app, effectively encoding its authority,
we can now implement our system call filtering policy.


FILL IN



## Setting Up A Second Signature Verification Key

Tock's signature checking mechanism supports multiple verifying keys. We need to
add a second public key to the kernel configuration so we can sign the Process
Info app to give it the advanced permissions (e.g., access to buttons).

We have included a second public-private ECDSA key pair
in the `libtock-c/examples/tutorials/dynamic-apps-and-policies` folder.
You may use these. If you are interested in setting up the keys yourself,
you can follow the [ECDSA Setup Guide](../setup/ecdsa.md) to generate your own key pair.

Once you have the public key that the kernel will use to do the signature verification,
you will need to add the key to `tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies/src/main.rs`.

FILL IN

## Re-Signing the Process Info App

Finally, we need to change the signature used to sign the Process Info app. We can do this with the existing TAB.

```
$ cd libtock-c/examples/tutorials/dynamic-apps-and-policies/process-info
$ tockloader tbf credential delete ecdsap256
$ tockloader tbf credential add ecdsap256 ../public_key
```

## Putting It All Together

Now, if you haven't already, you need to:

1. Re-install the kernel with the new key for verification and system call filtering policy.
2. Re-install the process-info application with the new signature.

Once those steps are completed, Process Info should work just as it did before.
The temperature app continues to work, which we can verify by holding our
finger on the nRF52840 IC and seeing the temperature rise.

However, when we run `tockloader listen` we no longer see the button print messages
because the temperature app no longer has access to the buttons:

FILL IN







