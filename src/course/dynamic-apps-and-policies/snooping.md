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

The
[`SyscallFilter`](https://docs.tockos.org/kernel/platform/trait.syscallfilter)
trait includes a single function `filter_syscall()`:

```rust
pub trait SyscallFilter {
    fn filter_syscall(&self, process: &dyn Process, syscall: &Syscall) -> Result<(), ErrorCode>
}
```

This function is called on every system call from userspace before the kernel
handles the system call. If the function returns `Ok()` the system call
proceeds. If the function returns an `Err(ErrorCode)` that error is returned to
the process and the system call is not executed.

In this module we will explore how we can use a `SyscallFilter` implementation
to enforce stronger security properties for a Tock system.

## Eavesdropping on Button Presses

We use the buttons to navigate the interface on the Process Manager application.
However, any application can register button notifications. To see this, we can
observe a perhaps unexpected operation of the `temperature` application.

If we run `tockloader listen` to observe the console output from the board,
while interacting with the Process Manager app, you will see additional messages
from the temperature app:

```
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
Processes Loaded at Main:
[0] temperature
    ShortId: 0xfb713632
[1] counter
    ShortId: 0xf7b60a92
[2] process_manager
    ShortId: 0xfc5167b0
[Temp App] Snooped button 2
[Temp App] Snooped button 0
[Temp App] Snooped button 2
[Temp App] Snooped button 2
[Temp App] Snooped button 2
[Temp App] Snooped button 0
[Temp App] Snooped button 2
[Temp App] Snooped button 3
[Temp App] Snooped button 3
[Temp App] Snooped button 2
```

Maybe maliciously, or maybe for future use, the temperature app is actually
logging all button presses! Our goal is to prevent a theoretically innocuous app
(temperature) from eavesdropping on our button presses.

## System Call Filtering Approach

To securely restrict access to the buttons to only the Process Manager
application we need two things:

1. A way to cryptographically verify which process is the Process Manager
   application.
2. A system call filtering policy that only allows the Process Manager
   application to access the buttons system call.

To accomplish these in this module, we are going to setup an additional
application signing key that we will only use for the Process Manager
application. We will configure the kernel that if an app is signed with that
special key then it will have access to the buttons. All other apps will be
denied access to the buttons.

To record which key was used to sign each applications, we will use a specific
`AppId` assigning algorithm. We will encode the signing key identifier into the
upper four bits of the 32-bit `ShortId` for the app. This is the first hex
digit. An application that was not cryptographically signed will have this
nibble set to `0xF`. An application signed with the first key will have this set
to 0, second key will be 1, and so on.

> `AppId` is the system that Tock uses to cryptographically attach an identifier
> to Tock applications. The mechanism is meant to be very flexible to support a
> wide range of use cases. The common way `AppId` is used is by assigning a
> 32-bit `ShortId` to each application when that process is loaded. Multiple
> processes can belong to the same application (e.g., different versions of the
> same app) and the kernel will ensure that only one process per application is
> ever executed at the same time.
>
> You can read more about `AppId` [here](https://book.tockos.org/trd/trd-appid).

Now, the `ShortId` for each process will include information about the signing
key used to sign the app. We will use this information to determine if the
buttons should be filtered.

### Application ID Assignment

The kernel configuration for the tutorial board is already setup to assign
`ShortId`s based on the signing key used when verifying the app's signature. The
format of the `ShortId` looks like this:

```text
32         28                       0 bits
+----------+------------------------+
| metadata | CRC(name)              |
+----------+------------------------+
```

And the code to implement this requires creating a custom implementation of the
[`Compress`](https://docs.tockos.org/kernel/process_checker/trait.compress)
trait. This must create the `ShortId` based on the results from the signature
checker. The signature checker saves the key ID that verified the signature in
the "metadata" field from the accepted credential.

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

You can see the full implementation in
`tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies/src/app_id_assigner_name_metadata.rs`.

## Setting Up A Second Signature Verification Key

Tock's signature checking mechanism supports multiple verifying keys. We need to
add a second public key to the kernel configuration so we can sign the Process
Info app to give it the advanced permissions (e.g., access to buttons).

We have included a second public-private ECDSA key pair in the
`libtock-c/examples/tutorials/dynamic-apps-and-policies/keys` folder. You may
use these. If you are interested in setting up the keys yourself, you can follow
the [ECDSA Setup Guide](../setup/ecdsa.md) to generate your own key pair.

Once you have the public key that the kernel will use to do the signature
verification, you will need to add the key to
`tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies/src/main.rs`. We
need to modify the `verifying_keys` object to include the second key. To get the
bytes of the second public key (the private key files hold both keys), run:

```
$ tail -c 64 ec-secp256r1-manager-key.private.p8 | hexdump -v -e '1/1 "0x%02x, "'
```

**Task:** Modify the `verifying_keys` object in main.rs to add the second key.

## Re-Signing the Process Manager App

Finally, we need to change the signature used to sign the Process Manager app.
We can do this with the existing TAB.

```
$ cd libtock-c/examples/tutorials/dynamic-apps-and-policies/process-manager
$ tockloader tbf credential delete ecdsap256
$ tockloader tbf credential add ecdsap256 --private-key ../keys/ec-secp256r1-manager-key.private.pem
```

You can also modify the application's Makefile to use the other key when the
application is compiled.

> **Checkpoint:** Verify that the Process Manager application is being verified
> with the second key. You can check this by verifying that the `ShortId`
> computed by the kernel starts with `0x1` (instead of `0x0`). The `ShortId` is
> printed to the console when the kernel boots.

## Re-Enabling the Screen for Process Manager

You may have noticed that the Process Manager no longer works. This is because
it no longer has access to the screen. The Tock kernel allocates regions of the
screen to different apps based on their `ShortId`, but we just changed Process
Manager's `ShortId`!

To fix this, we need to update the short ID used to assign a region of screen
for the Process Manager. The screen allocation looks like this in main.rs:

```rust
let apps_regions = kernel::static_init!(
    [capsules_extra::screen_shared::AppScreenRegion; 3],
    [
        capsules_extra::screen_shared::AppScreenRegion::new(
            create_short_id_from_name("process_manager", 0x0), // Need to change 0x0 to 0x1
            0,      // x
            0,      // y
            16 * 8, // width
            7 * 8   // height
        ),
        capsules_extra::screen_shared::AppScreenRegion::new(
            create_short_id_from_name("counter", 0x0),
            0,     // x
            7 * 8, // y
            8 * 8, // width
            1 * 8  // height
        ),
        capsules_extra::screen_shared::AppScreenRegion::new(
            create_short_id_from_name("temperature", 0x0),
            8 * 8, // x
            7 * 8, // y
            8 * 8, // width
            1 * 8  // height
        )
    ]
);

let screen = components::screen::ScreenSharedComponent::new().finalize();
```

**Task:** Modify the arguments to `create_short_id_from_name()` for the Process
Manager to set the key metadata to 0x1.

> **Checkpoint:** After re-flashing the kernel verify that the Process Manager
> app continues to work and that the buttons work to interact with the app.

## System Call Filtering

Now with the `ShortId` conveying which key signed each app, effectively encoding
its authority, we can now implement our system call filtering policy.

The implementation of a system call filter looks like this. You can find the
full starter code in
`tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies/src/system_call_filter.rs`.

```rust
use kernel::errorcode::ErrorCode;
use kernel::process::Process;
use kernel::syscall::Syscall;

pub struct DynamicPoliciesCustomFilter {}

impl SyscallFilter for DynamicPoliciesCustomFilter {
    fn filter_syscall(&self, process: &dyn Process, syscall: &Syscall) -> Result<(), ErrorCode> {
        // Get the upper four bits of the ShortId.
        let signing_key_id = if let ShortId::Fixed(fixed_id) = process.short_app_id() {
            ((u32::from(fixed_id) >> 28) & 0xF) as u8
        } else {
            0xff_u8
        };

        // Enforce the correct policy based on the signing key and the system
        // call.
        //
        // Documentation for system call:
        // https://docs.tockos.org/kernel/syscall/enum.syscall#implementations
        match signing_key_id {
            0 => Ok(()),
            1 => Ok(()),
            _ => Ok(()),
        }
    }
}
```

We also need two other helpful pieces of information: how to get the system call
driver number and how to get the driver number for buttons:

```rust
let driver_num = syscall.driver_number();
let button_driver_num = capsules_core::button::DRIVER_NUM;
```

**Task:** finish the implementation for the `SyscallFilter` that only permits
system calls for buttons if the signing key is 1.

## Putting It All Together

Now, if you haven't already, you need to:

1. Re-install the kernel with the new key for verification and system call
   filtering policy.
2. Re-install the process-info application with the new signature.

Once those steps are completed, Process Manager should work just as it did
before. The temperature app continues to work, which we can verify by holding
our finger on the nRF52840 IC and seeing the temperature rise.

However, when we run `tockloader listen` we no longer see the button print
messages because the temperature app no longer has access to the buttons:

```
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$ Processes Loaded at Main:
[0] app_loader
    ShortId: 0x1f37c81
[1] process_manager
    ShortId: 0x1c5167b0
[2] counter
    ShortId: 0x7b60a92
[3] temperature
    ShortId: 0xb713632
[4] blink
    ShortId: 0xfd19e248
[Temp App] Error: Unable to access the buttons.
[Process Manager] Discovered App Loader Service
```

> **Checkpoint:** You now have Tock running with multiple concurrent
> applications, multiple signing keys, and per-app system call filtering. This
> enables us to securely ensure that only the Process Manager app has access to
> the buttons.
>
> If you want to continue to explore how Tock can enforce properties for
> applications, here are some ideas you might investigate:
>
> - Modify the system call filter to only allow the Process Manager app to
>   access the `process info` system call, and the App Loader app to access the
>   `app loader` system call.
> - Prevent unsigned apps from running at all.
> - Have applications signed with two keys (e.g. by the developer and the app
>   store).
> - Use the `ShortId` TBF header to assign short IDs rather than a CRC of the
>   app name.

## Conclusion

This concludes our tutorial on using Tock to dynamically inspect and load apps
and use cryptographic signatures to restrict access to system calls. We hope you
enjoyed it!

We covered the following topics:

- an interactive, screen-based tool for inspecting the state of Tock processes
- dynamically loading new applications at runtime without restarting the kernel
- signing applications with ECDSA signing keys
- implementing least-privilege with system call filtering

Tock is an operating system applicable to a broad set of application domains,
such as low-power and security-critical systems. We provide a broad set of
guides and documentation:

- This book: [https://book.tockos.org](https://book.tockos.org)
- Tock code documentation: [https://docs.tockos.org](https://docs.tockos.org)
- Reference documentation:
  [https://github.com/tock/tock/tree/master/doc](https://github.com/tock/tock/tree/master/doc)

We also provide some community resources, which you can find here:
[https://tockos.org/community/](https://tockos.org/community/)

---

We always appreciate feedback on our tutorials. What went well? What did you
like? What was not so smooth? What was less interesting? How can we make things
better? Please do not hesitate to reach out, and if you have found any smaller
typographical or technical errors,
[pull requests are welcome and appreciated!](https://github.com/tock/book)
