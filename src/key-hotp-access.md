# Security Key Application Access Control

With security-focused and privileged system resources, a board may wish to
restrict which applications can access which system call resources. In this
module we will extend the Tock kernel to restrict access to the encryption
capsule to only trusted (credentialed) apps.

## Background

We need two Tock mechanisms to implement this feature. First, we need a way to
identify the trusted app that we will give access to the encryption engine. We
will do this by adding credentials to the app's
[TBF (Tock Binary Format file)](https://github.com/tock/tock/blob/master/doc/TockBinaryFormat.md)
and verifying those credentials when the application is loaded. This mechanism
allows developers to sign apps, and then the kernel can verify those signatures.

The second mechanism is way to permit syscall access to only specific
applications. The Tock kernel already has a hook that runs on each syscall to
check if the syscall should be permitted. By default this just approves every
syscall. We will need to implement a custom policy which permits access to the
encryption capsule to only the trusted HOTP apps.

## Module Overview

Our goal is to add credentials to Tock apps, verify those credentials in the
kernel, and then permit only verified apps to use the encryption oracle API. To
keep this simple we will use a simple SHA-256 hash as our credential, and verify
that the hash is valid within the kernel.

## Step 1: Credentialed Apps

To implement our access control policy we need to include an offline-computed
SHA256 hash with the app TBF, and then check it when running the app. The SHA256
credential is simple to create, and serves as a stand-in for more useful
credentials such as cryptographic signatures.

This will require a couple pieces:

- We need to actually include the hash in our app.
- We need a mechanism in the kernel to check the hash exists and is valid.

### Signing Apps

We can use Tockloader to add a hash to a compiled app. This will require
Tockloader version 1.10.0 or newer.

First, compile the app:

```
$ cd libtock-c/examples/blink
$ make
```

Now, add the hash credential:

```
$ tockloader tbf credential add sha256
```

It's fine to add to all architectures or you can specify which TBF to add it to.

To check that the credential was added, we can inspect the TAB:

```
$ tockloader inspect-tab
```

You should see output like the following:

```
$ tockloader inspect-tab
[INFO   ] No TABs passed to tockloader.
[STATUS ] Searching for TABs in subdirectories.
[INFO   ] Using: ['./build/blink.tab']
[STATUS ] Inspecting TABs...
TAB: blink
  build-date: 2023-06-09 21:52:59+00:00
  minimum-tock-kernel-version: 2.0
  tab-version: 1
  included architectures: cortex-m0, cortex-m3, cortex-m4, cortex-m7

 Which TBF to inspect further? cortex-m4

cortex-m4:
  version               : 2
  header_size           :        104         0x68
  total_size            :      16384       0x4000
  checksum              :              0x722e64be
  flags                 :          1          0x1
    enabled             : Yes
    sticky              : No
  TLV: Main (1)                                   [0x10 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       5068       0x13cc
  TLV: Program (9)                                [0x20 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       5068       0x13cc
    binary_end_offset   :       8360       0x20a8
    app_version         :          0          0x0
  TLV: Package Name (3)                           [0x38 ]
    package_name        : blink
  TLV: Kernel Version (8)                         [0x4c ]
    kernel_major        : 2
    kernel_minor        : 0
    kernel version      : ^2.0
  TLV: Persistent ACL (7)                         [0x54 ]
    Write ID            :          11          0xb
    Read IDs (1)        : 11
    Access IDs (1)      : 11

TBF Footers
  Footer
    footer_size         :       8024       0x1f58
  Footer TLV: Credentials (128)
    Type: SHA256 (3) ✓ verified
    Length: 32
  Footer TLV: Credentials (128)
    Type: Reserved (0)
    Length: 7976
```

Note at the bottom, there is a `Footer TLV` with SHA256 credentials! Because
tockloader was able to double-check the hash was correct there is `✓ verified`
next to it.

> **SUCCESS:** We now have an app with a hash credential!

### Verifying Credentials in the Kernel

To have the kernel check that our hash credential is present and valid, we need
to add a credential checker before the kernel starts each process.

To create the app checker, we'll edit the board's `main.rs` file in the kernel.
Tock includes a basic SHA256 credential checker, so we can use that. The
following code should be added to the `main.rs` file somewhere before the
platform setup occurs (probably right after the encryption oracle capsule from
the last module!).

```rust
//--------------------------------------------------------------------------
// CREDENTIALS CHECKING POLICY
//--------------------------------------------------------------------------

// Create the software-based SHA engine.
let sha = static_init!(capsules_extra::sha256::Sha256Software<'static>,
                       capsules_extra::sha256::Sha256Software::new());
kernel::deferred_call::DeferredCallClient::register(sha);

// Create the credential checker.
static mut SHA256_CHECKER_BUF: [u8; 32] = [0; 32];
let checker = static_init!(
    kernel::process_checker::basic::AppCheckerSha256,
    kernel::process_checker::basic::AppCheckerSha256::new(sha, &mut SHA256_CHECKER_BUF)
    );
kernel::hil::digest::Digest::set_client(sha, checker);
```

That code creates a `checker` object. We now need to modify the board so it
hangs on to that `checker` struct. To do so, we need to add this to our
`Platform` struct type definition near the top of the file:

```rust
struct Platform {
    ...
    credentials_checking_policy: &'static kernel::process_checker::basic::AppCheckerSha256,
}
```

Then when we create the platform object near the end of `main()`, we can add our
`checker`:

```rust
let platform = Platform {
    ...
    credentials_checking_policy: checker,
}
```

And we need the platform to provide access to that checker when requested by the
kernel for credentials-checking purposes. This goes in the `KernelResources`
implementation for the `Platform` type:

```rust
impl KernelResources for Platform {
    ...
    type CredentialsCheckingPolicy = kernel::process_checker::basic::AppCheckerSha256;
    ...
    fn credentials_checking_policy(&self) -> &'static Self::CredentialsCheckingPolicy {
        self.credentials_checking_policy
    }
    ...
}
```

Finally, we need to use the function that checks credentials when processes are
loaded (not just loads and executes them unconditionally). This should go at the
end of `main()`, replacing the existing call to
`kernel::process::load_processes`:

```rust
kernel::process::load_and_check_processes(
        board_kernel,
        &platform, // note this function requires providing the platform.
        chip,
        core::slice::from_raw_parts(
            &_sapps as *const u8,
            &_eapps as *const u8 as usize - &_sapps as *const u8 as usize,
        ),
        core::slice::from_raw_parts_mut(
            &mut _sappmem as *mut u8,
            &_eappmem as *const u8 as usize - &_sappmem as *const u8 as usize,
        ),
        &mut PROCESSES,
        &FAULT_RESPONSE,
        &process_management_capability,
    )
    .unwrap_or_else(|err| {
        debug!("Error loading processes!");
        debug!("{:?}", err);
    });
```

Compile and install the updated kernel.

> **SUCCESS:** We now have a kernel that can check credentials!

### Installing Apps and Verifying Credentials

Now, our kernel will only run an app if it has a valid SHA256 credential. To
verify this, recompile and install the blink app but do not add credentials:

```
cd libtock-c/examples/blink
touch main.c
make
tockloader install --erase
```

> **TODO** FIGURE OUT PROCESS CONSOLE ON TUTORIAL BOARD ISSUE!!

Now, if we list the processes on the board with the process console. Note we
need to run the `console-start` command to active the tock process console.

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
console-start
tock$
```

Now we can list the processes:

```
tock$ list
 PID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      blink                    0         0         0   0/16   CredentialsFailed
tock$
```

> Tip: You can re-disable the process console by using the `console-stop`
> command.

You can see our app is in the state `CredentialsFailed` meaning it will not
execute (and the LEDs are not blinking).

To fix this, we can add the SHA256 credential.

```
cd libtock-c/examples/blink
tockloader tbf credential add sha256
tockloader install
```

Now when we list the processes, we see:

```
tock$ list
 PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      0x3be6efaa blink                    0       323         0   1/16   Yielded
```

And we can verify the app is both running and now has a specifically assigned
short ID.

### Permitting Both Credentialed and Non-Credentialed Apps

The default operation is not quite what we want. We want all apps to run, but
only credentialed apps to have access to the syscalls.

To allow all apps to run, even if they don't pass the credential check, we need
to configure our checker. Doing that is actually quite simple. We just need to
modify the credential checker we are using to not require credentials.

In `tock/kernel/src/process_checker/basic.rs`, modify the
`require_credentials()` function to not require credentials:

```rust
impl AppCredentialsChecker<'static> for AppCheckerSha256 {
    fn require_credentials(&self) -> bool {
        false // change from true to false
    }
    ...
}
```

Then recompile and install. Now even a non-credentialed process should run:

```
tock$ list
 PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      Unique     c_hello                  0         8         0   1/16   Yielded
```

> **SUCCESS:** We now can determine if an app is credentialed or not!

## Step 2: Permitting Syscalls for only Credentialed Apps

Our second step is to implement a policy that permits syscall access to the
encryption capsule only for credentialed apps. All other syscalls should be
permitted.

Tock provides the `SyscallFilter` trait to do this. An object that implements
this trait is used on every syscall to check if that syscall should be executed
or not. By default all syscalls are permitted.

The interface looks like this:

```rust
pub trait SyscallFilter {
    // Return Ok(()) to permit the syscall, and any Err() to deny.
    fn filter_syscall(
        &self, process: &dyn process::Process, syscall: &syscall::Syscall,
    ) -> Result<(), errorcode::ErrorCode> {
        Ok(())
    }
}

```

We need to implement the single `filter_syscall()` function with out desired
behavior.

To do this, create a new file in the board's `src/` directory. Then insert the
code below as a starting point:

```rust
use kernel::platform::platform::SyscallFilter;
use kernel::process;
use kernel::process::Process;

pub struct TrustedSyscallFilter {}

impl SyscallFilter for TrustedSyscallFilter {
    fn filter_syscall(&self, process: &dyn process::Process, syscall: &syscall::Syscall)
        -> Result<(), errorcode::ErrorCode> {

        // To determine if the process has credentials we can use the
        // `process.get_credentials()` function.

        // Now inspect the `syscall` the app is calling. If the `driver_numer`
        // is not XXXXXX, then return `Ok(())` to permit the call. Otherwise, if
        // the process is not credentialed, return `Err(ErrorCode::NOSUPPORT)`. If
        // the process is credentialed return `Ok(())`.

    }
}
```

Documentation for the `Syscall` type is
[here](https://docs.tockos.org/kernel/syscall/enum.syscall).

Save this file and include it from the board's main.rs.

Now to put our new policy into effect we need to use it when we configure the
kernel via the `KernelResources` trait.

```rust
impl KernelResources for Platform {
    ...
    type SyscallFilter = TrustedSyscallFilter;
    ...
    fn syscall_filter(&self) -> &'static Self::SyscallFilter {
        self.syscall_filter
    }
    ...
}
```

Also you need to instantiate the `TrustedSyscallFilter` and add it to the
`Platform` struct.

> **SUCCESS:** We now have a custom syscall filter based on app credentials.

## Verifying HOTP Now Needs Credentials

Now you should be able to install your HOTP app to the board without adding the
SHA256 credential and verify that it is no longer able to access the encryption
capsule.

If you use tockloader to add credentials
(`tockloader tbf credential add sha256`) and then re-install your app it should
run as expected

> ### Wrap-up
>
> You now have implemented access control on important kernel resources and
> enabled your app to use it. This provides platform builders robust flexibility
> in architecting the security framework for their devices.
