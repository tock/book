# Tock Kernel Policies

As a kernel for a security-focused operating system, the Tock kernel is
responsible for implementing various policies on how the kernel should handle
processes. Examples of the types of questions these policies help answer are:
What happens when a process has a hardfault? Is the process restarted? What
syscalls are individual processes allowed to call? Which process should run
next? Different systems may need to answer these questions differently, and Tock
includes a robust platform for configuring each of these policies.

## Background on Relevant Tock Design Details

If you are new to this aspect of Tock, this section provides a quick primer on
the key aspects of Tock which make it possible to implement process policies.

### The `KernelResources` Trait

The central mechanism for configuring the Tock kernel is through the
`KernelResources` trait. Each board must implement `KernelResources` and provide
the implementation when starting the main kernel loop.

The general structure of the `KernelResources` trait looks like this:

```rust
/// This is the primary method for configuring the kernel for a specific board.
pub trait KernelResources<C: Chip> {
    /// How driver numbers are matched to drivers for system calls.
    type SyscallDriverLookup: SyscallDriverLookup;

    /// System call filtering mechanism.
    type SyscallFilter: SyscallFilter;

    /// Process fault handling mechanism.
    type ProcessFault: ProcessFault;

    /// Credentials checking policy.
    type CredentialsCheckingPolicy: CredentialsCheckingPolicy<'static> + 'static;

    /// Context switch callback handler.
    type ContextSwitchCallback: ContextSwitchCallback;

    /// Scheduling algorithm for the kernel.
    type Scheduler: Scheduler<C>;

    /// Timer used to create the timeslices provided to processes.
    type SchedulerTimer: scheduler_timer::SchedulerTimer;

    /// WatchDog timer used to monitor the running of the kernel.
    type WatchDog: watchdog::WatchDog;

    // Getters for each policy/mechanism.

    fn syscall_driver_lookup(&self) -> &Self::SyscallDriverLookup;
    fn syscall_filter(&self) -> &Self::SyscallFilter;
    fn process_fault(&self) -> &Self::ProcessFault;
    fn credentials_checking_policy(&self) -> &'static Self::CredentialsCheckingPolicy;
    fn context_switch_callback(&self) -> &Self::ContextSwitchCallback;
    fn scheduler(&self) -> &Self::Scheduler;
    fn scheduler_timer(&self) -> &Self::SchedulerTimer;
    fn watchdog(&self) -> &Self::WatchDog;
}
```

Many of these resources can be effectively no-ops by defining them to use the
`()` type. Every board that wants to support processes must provide:

1. A `SyscallDriverLookup`, which maps the `DRIVERNUM` in system calls to the
   appropriate driver in the kernel.
2. A `Scheduler`, which selects the next process to execute. The kernel provides
   several common schedules a board can use, or boards can create their own.

### Application Identifiers

The Tock kernel can implement different policies based on different levels of
trust for a given app. For example, a trusted core app written by the board
owner may be granted full privileges, while a third-party app may be limited in
which system calls it can use or how many times it can fail and be restarted.

To implement per-process policies, however, the kernel must be able to establish
a persistent identifier for a given process. To do this, Tock supports _process
credentials_ which are hashes, signatures, or other credentials attached to the
end of a process's binary image. With these credentials, the kernel can
cryptographically verify that a particular app is trusted. The kernel can then
establish a persistent identifier for the app based on its credentials.

A specific process binary can be appended with zero or more credentials. The
per-board `KernelResources::CredentialsCheckingPolicy` then uses these
credentials to establish if the kernel should run this process and what
identifier it should have. The Tock kernel design does not impose any
restrictions on how applications or processes are identified. For example, it is
possible to use a SHA256 hash of the binary as an identifier, or a RSA4096
signature as the identifier. As different use cases will want to use different
identifiers, Tock avoids specifying any constraints.

However, long identifiers are difficult to use in software. To enable more
efficiently handling of application identifiers, Tock also includes mechanisms
for a per-process `ShortID` which is stored in 32 bits. This can be used
internally by the kernel to differentiate processes. As with long identifiers,
ShortIDs are set by `KernelResources::CredentialsCheckingPolicy` and are chosen
on a per-board basis. The only property the kernel enforces is that ShortIDs
must be unique among processes installed on the board. For boards that do not
need to use ShortIDs, the ShortID type includes a `LocallyUnique` option which
ensures the uniqueness invariant is upheld without the overhead of choosing
distinct, unique numbers for each process.

```rust
pub enum ShortID {
    LocallyUnique,
    Fixed(core::num::NonZeroU32),
}
```

## Module Overview

In this module, we are going to experiment with using the `KernelResources`
trait to implement per-process restart policies. We will create our own
`ProcessFaultPolicy` that implements different fault handling behavior based on
whether the process was cryptographically signed using our RSA private key.



### Custom Process Fault Policy

A process fault policy decides what the kernel does with a process when it
crashes (i.e. hardfaults). The policy is implemented as a Rust module that
implements the following trait:

```rust
pub trait ProcessFaultPolicy {
    /// `process` faulted, now decide what to do.
    fn action(&self, process: &dyn Process) -> process::FaultAction;
}
```

When a process faults, the kernel will call the `action()` function and then
take the returned action on the faulted process. The available actions are:

```rust
pub enum FaultAction {
    /// Generate a `panic!()` with debugging information.
    Panic,
    /// Attempt to restart the process.
    Restart,
    /// Stop the process.
    Stop,
}
```

Let's create a custom process fault policy that restarts signed processes up to
a configurable maximum number of times, and immediately stops unsigned
processes.

We start by defining a `struct` for this policy:

```rust
pub struct RestartTrustedAppsFaultPolicy {
	/// Number of times to restart trusted apps.
    threshold: usize,
}
```

We then create a constructor:

```rust
impl RestartTrustedAppsFaultPolicy {
    pub const fn new(threshold: usize) -> RestartTrustedAppsFaultPolicy {
        RestartTrustedAppsFaultPolicy { threshold }
    }
}
```

Now we can add a template implementation for the `ProcessFaultPolicy` trait:

```rust
impl ProcessFaultPolicy for RestartTrustedAppsFaultPolicy {
    fn action(&self, process: &dyn Process) -> process::FaultAction {
        process::FaultAction::Stop
    }
}
```

To determine if a process is trusted, we will use its `ShortID`. A `ShortID` is
a type as follows:

```rust
pub enum ShortID {
	/// No specific ID, just an abstract value we know is unique.
    LocallyUnique,
    /// Specific 32 bit ID number guaranteed to be unique.
    Fixed(core::num::NonZeroU32),
}
```

If the app has a short ID of `ShortID::LocallyUnique` then it is untrusted (i.e.
the kernel could not validate its signature or it was not signed). If the app
has a concrete number as its short ID (i.e. `ShortID::Fixed(u32)`), then we
consider the app to be trusted.

To determine how many times the process has already been restarted we can use
`process.get_restart_count()`.

Putting this together, we have an outline for our custom policy:

```rust
use kernel::process;
use kernel::process::Process;
use kernel::process::ProcessFaultPolicy;

pub struct RestartTrustedAppsFaultPolicy {
	/// Number of times to restart trusted apps.
    threshold: usize,
}

impl RestartTrustedAppsFaultPolicy {
    pub const fn new(threshold: usize) -> RestartTrustedAppsFaultPolicy {
        RestartTrustedAppsFaultPolicy { threshold }
    }
}

impl ProcessFaultPolicy for RestartTrustedAppsFaultPolicy {
    fn action(&self, process: &dyn Process) -> process::FaultAction {
    	let restart_count = process.get_restart_count();
    	let short_id = process.short_app_id();

    	// Check if the process is trusted. If so, return the restart action
    	// if the restart count is below the threshold. Otherwise return stop.

    	// If the process is not trusted, return stop.
        process::FaultAction::Stop
    }
}
```

> **TASK:** Finish implementing the custom process fault policy.

Save your completed custom fault policy in your board's `src/` directory as
`trusted_fault_policy.rs`. Then add `mod trusted_fault_policy;` to the top of
the board's `main.rs` file.

### Testing Your Custom Fault Policy

First we need to configure your kernel to use your new fault policy.

1. Find where your `fault_policy` was already defined. Update it to use your new
   policy:

    ```rust
    let fault_policy = static_init!(
        trusted_fault_policy::RestartTrustedAppsFaultPolicy,
        trusted_fault_policy::RestartTrustedAppsFaultPolicy::new(3)
    );
    ```

2. We need to add the policy to our board object by making sure the types match.
   Edit the main board struct to the new policy:

    ```rust
    struct Platform {
    	...
        fault_policy: &'static trusted_fault_policy::RestartTrustedAppsFaultPolicy,
    }
    ```

3. Now we need to configure the `KernelResources` struct to use the policy.

    ```rust
    impl KernelResources<...> for Platform {
        ...
        type ProcessFaultPolicy = trusted_fault_policy::RestartTrustedAppsFaultPolicy;
        fn process_fault_policy(&self) -> &Self::ProcessFaultPolicy {
            &self.fault_policy
        }
    }
    ```

4. Now we can compile the updated kernel and flash it to the board:

    ```
    # in your board directory:
    make install
    ```

Now we need an app to actually crash so we can observe its behavior. Tock has a
test app called `crash_dummy` that causes a hardfault when a button is pressed.
Compile that and load it on to the board:

1. Compile the app:

    ```
    cd libtock-c/examples/tests/crash_dummy
    make
    ```

2. Install it on the board:

    ```
    tockloader install
    ```

With the new kernel installed and the test app loaded, we can inspect the status
of the board. Use tockloader to connect to the serial port:

```
tockloader listen
```

> Note: if multiple serial port options appear, generally the lower numbered
> port is what you want to use.

Now we can use the onboard console to inspect which processes we have on the
board. Run the list command:

```
tock$ list
 PID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      crash_dummy              0         6         0   1/15   Yielded
```

Note that `crash_dummy` is in the `Yielded` state. This means it is just waiting
for a button press.

Press the first button on your board (it is "Button 1" on the nRF52840-dk). This
will cause the process to fault. You won't see any output, and since the app was
not signed it was just stopped. Now run the list command again:

```
tock$ list
 PID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      crash_dummy              0         6         0   0/15   Faulted
```

Now the process is in the `Faulted` state! This means the kernel will not try to
run it. Our policy is working! Next we have to verify signed apps so that we can
restart trusted apps.


## Trusting Apps

With our custom fault policy, we can implement different responses based on
whether an app is trusted or not. Now we need to configure the kernel to verify
apps, and check if we trust them or not.

This will require a couple pieces:

- We need to actually sign the apps with our private key and include the
  signature when we load apps to the board so the kernel can check the
  signature.
- We need a mechanism in the kernel to check the signatures.
- We need the kernel to know the matching public key to verify the signatures.

### Signing Apps

We can use Tockloader to sign a compiled app. But first, we need RSA keys to use
for the signature. We can generate suitable keys with `openssl`:

```
$ openssl genrsa -aes128 -out tockkey.private.pem 2048
$ openssl rsa -in tockkey.private.pem -outform der -out tockkey.private.der
$ openssl rsa -in tockkey.private.pem -outform der -pubout -out tockkey.public.der
```

You should now have three key files (although we only need the `.der` files):

- `tockkey.private.pem`
- `tockkey.private.der`
- `tockkey.public.der`

Now, to add an RSA signature to an app, we first build the app and then add the
`rsa2048` credential. It shouldn't matter which app you want to use, but for
simplicity we'll use `blink` as an example.

First, compile the app:

```
$ cd libtock-c/examples/blink
$ make
```

Now, add the credential:

```
$ tockloader tbf credential add rsa2048 --private-key tockkey.private.der --public-key tockkey.public.der
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
  header_size           :         76         0x4c
  total_size            :       8192       0x2000
  checksum              :              0x6e3c4aff
  flags                 :          1          0x1
    enabled             : Yes
    sticky              : No
  TLV: Main (1)                                   [0x10 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       4604       0x11fc
  TLV: Program (9)                                [0x20 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       4604       0x11fc
    binary_end_offset   :       1780        0x6f4
    app_version         :          0          0x0
  TLV: Package Name (3)                           [0x38 ]
    package_name        : blink
  TLV: Kernel Version (8)                         [0x44 ]
    kernel_major        : 2
    kernel_minor        : 0
    kernel version      : ^2.0

TBF Footers
  Footer
    footer_size         :       6412       0x190c
  Footer TLV: Credentials (128)
    Type: RSA2048 (10)
    Length: 256
  Footer TLV: Credentials (128)
    Type: Reserved (0)
    Length: 6140
```

Note at the bottom, there is a `Footer TLV` with RSA2048 credentials! To verify
they were added correctly, we can run `tockloader inspect-tab` with
`--verify-credentials`:

```
$ tockloader inspect-tab --verify-credentials tockkey.private.der
```

There will now be a `✓ verified` next to the RSA2048 credential showing that the
stored credential matches what it should compute to.

> **SUCCESS:** We now have a signed app!


