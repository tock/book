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
`AppCredentialsPolicy` then uses these credentials to establish if the kernel
should run this process. If the credentials policy approves the process, the
`AppIdPolicy` determines what identifier it should have. The Tock kernel design
does not impose any restrictions on how applications or processes are
identified. For example, it is possible to use a SHA256 hash of the binary as an
identifier, or a RSA4096 signature as the identifier. As different use cases
will want to use different identifiers, Tock avoids specifying any constraints.

However, long identifiers are difficult to use in software. To enable more
efficiently handling of application identifiers, Tock also includes mechanisms
for a per-process `ShortId` which is stored in 32 bits. This can be used
internally by the kernel to differentiate processes. As with long identifiers,
ShortIds are set by `AppIdPolicy` (specifically the `Compress` trait) and are
chosen on a per-board basis. The only property the kernel enforces is that
ShortIDs must be unique among processes installed on the board. For boards that
do not need to use ShortIDs, the ShortID type includes a `LocallyUnique` option
which ensures the uniqueness invariant is upheld without the overhead of
choosing distinct, unique numbers for each process.

```rust
pub enum ShortId {
    LocallyUnique,
    Fixed(core::num::NonZeroU32),
}
```

## Module Overview

In this module, we are going to experiment with using the `KernelResources`
trait to implement per-process restart policies. We will create our own
`ProcessFaultPolicy` that implements different fault handling behavior based on
whether the process included a hash in its credentials footer.

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

To determine if a process is trusted, we will use its `ShortId`. A `ShortId` is
a type as follows:

```rust
pub enum ShortId {
	/// No specific ID, just an abstract value we know is unique.
    LocallyUnique,
    /// Specific 32 bit ID number guaranteed to be unique.
    Fixed(core::num::NonZeroU32),
}
```

If the app has a short ID of `ShortId::LocallyUnique` then it is untrusted (i.e.
the kernel could not validate its signature or it was not signed). If the app
has a concrete number as its short ID (i.e. `ShortId::Fixed(u32)`), then we
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

2. Now we need to configure the process loading mechanism to use this policy for
   each app.

   ```rust
   kernel::process::load_processes(
       board_kernel,
       chip,
       flash,
       memory,
       &mut PROCESSES,
       fault_policy, // this is where we provide our chosen policy
       &process_management_capability,
   )
   ```

3. Now we can compile the updated kernel and flash it to the board:

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

## App Credentials

With our custom fault policy, we can implement different responses based on
whether an app is trusted or not. Now we need to configure the kernel to verify
apps, and check if we trust them or not. For this example we will use a simple
credential: a sha256 hash. This credential is simple to create, and serves as a
stand-in for more useful credentials such as cryptographic signatures.

This will require a couple pieces:

- We need to actually include the hash in our app.
- We need a mechanism in the kernel to check the hash exists and is valid.

### Signing Apps

We can use Tockloader to add a hash to a compiled app.

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
    package_name        : kv_interactive
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

In `main.rs`, we need to create the app checker. Tock includes a basic SHA256
credential checker, so we can use that:

```rust
// Create the software-based SHA engine.
let sha = components::sha::ShaSoftware256Component::new()
    .finalize(components::sha_software_256_component_static!());

// Create the credential checker.
let checking_policy = components::appid::checker_sha::AppCheckerSha256Component::new(sha)
    .finalize(components::app_checker_sha256_component_static!());

// Create the AppID assigner.
let assigner = components::appid::assigner_name::AppIdAssignerNamesComponent::new()
    .finalize(components::appid_assigner_names_component_static!());

// Create the process checking machine.
let checker = components::appid::checker::ProcessCheckerMachineComponent::new(checking_policy)
    .finalize(components::process_checker_machine_component_static!());
```

To use the checker, we must switch to asynchronous process loading. Many boards
by default use a synchronous loader which iterates through flash discovering
processes. However, to verify credentials, we need asynchronous operations
during loading and therefore need an asynchronous process loader.

```rust
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
        &mut *addr_of_mut!(PROCESSES),
        process_binary_array,
        board_kernel,
        chip,
        core::slice::from_raw_parts(
            core::ptr::addr_of!(_sapps),
            core::ptr::addr_of!(_eapps) as usize - core::ptr::addr_of!(_sapps) as usize,
        ),
        core::slice::from_raw_parts_mut(
            core::ptr::addr_of_mut!(_sappmem),
            core::ptr::addr_of!(_eappmem) as usize - core::ptr::addr_of!(_sappmem) as usize,
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

(Instead of the `kernel::process::load_processes(...)` function.)

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

Now, if we list the processes on the board with the process console:

```
$ tockloader listen
Initialization complete. Entering main loop
NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
tock$ list
 PID    Name                Quanta  Syscalls  Restarts  Grants  State
tock$
```

You can see our app does not show up. That is because it did not pass the
credential check.

We can see this more clearly by updating the kernel to use the
`ProcessLoadingAsyncClient` client. We can implement this client for `Platform`:

```rust
impl kernel::process::ProcessLoadingAsyncClient for Platform {
    fn process_loaded(&self, result: Result<(), kernel::process::ProcessLoadError>) {
        match result {
            Ok(()) => {},
            Err(e) => {
                kernel::debug!("Process failed to load: {:?}", e);
            }
        }
    }

    fn process_loading_finished(&self) { }
}
```

And then configure it with the loader:

```rust
loader.set_client(platform);
```

Now re-compiling and flashing the kernel and we will see the process load error
when the kernel boots.

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

### Implementing the Privileged Behavior

The default operation is not quite what we want. We want all apps to run, but
only credentialed apps to be restarted.

First, we need to allow all apps to run, even if they don't pass the credential
check. Doing that is actually quite simple. We just need to modify the
credential checker we are using to not require credentials.

In `tock/capsules/system/src/process_checker/basic.rs`, modify the
`require_credentials()` function to not require credentials:

```rust
impl AppCredentialsChecker<'static> for AppCheckerSha256 {
    fn require_credentials(&self) -> bool {
        false // change from true to false
    }
    ...
}
```

Then recompile and install. Now both processes should run:

```
tock$ list
 PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      0x3be6efaa blink                    0       193         0   1/16   Yielded
 1      Unique     c_hello                  0         8         0   1/16   Yielded
```

But note, only the credential app (blink) has a specific short ID.

Second, we need to use the presence of a specific short ID in our fault policy
to only restart credentials apps. We just need to check if the short ID is fixed
or not:

```rust
impl ProcessFaultPolicy for RestartTrustedAppsFaultPolicy {
    fn action(&self, process: &dyn Process) -> process::FaultAction {
        let restart_count = process.get_restart_count();
        let short_id = process.short_app_id();

        // Check if the process is trusted based on whether it has a fixed short
        // ID. If so, return the restart action if the restart count is below
        // the threshold. Otherwise return stop.
        match short_id {
            kernel::process::ShortId::LocallyUnique => process::FaultAction::Stop,
            kernel::process::ShortId::Fixed(_) => {
                if restart_count < self.threshold {
                    process::FaultAction::Restart
                } else {
                    process::FaultAction::Stop
                }
            }
        }
    }
}
```

That's it! Now we have the full policy: we verify application credentials, and
handle process faults accordingly.

> ### Task
>
> Compile and install multiple applications, including the crash dummy app, and
> verify that only credentialed apps are successfully restarted.

> **SUCCESS:** We now have implemented an end-to-end security policy in Tock!
