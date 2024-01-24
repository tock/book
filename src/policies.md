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
whether the process included a hash in its credentials footer.

## Custom Process Fault Policy

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

### Creating Our Process Fault Policy

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
use capsules_extra::sha256::Sha256Software;
use kernel::process_checker::basic::AppCheckerSha256;

// Create the software-based SHA engine.
let sha = static_init!(Sha256Software<'static>, Sha256Software::new());
kernel::deferred_call::DeferredCallClient::register(sha);

// Create the credential checker.
static mut SHA256_CHECKER_BUF: [u8; 32] = [0; 32];
let checker = static_init!(
    AppCheckerSha256,
    AppCheckerSha256::new(sha, &mut SHA256_CHECKER_BUF)
);
sha.set_client(checker);
```

Then we need to add this to our `Platform` struct:

```rust
struct Platform {
    ...
    credentials_checking_policy: &'static AppCheckerSha256,
}
```

Add it when create the platform object:

```rust
let platform = Platform {
    ...
    credentials_checking_policy: checker,
}
```

And configure our kernel to use it:

```rust
impl KernelResources for Platform {
    ...
    type CredentialsCheckingPolicy = AppCheckerSha256;
    ...
    fn credentials_checking_policy(&self) -> &'static Self::CredentialsCheckingPolicy {
        self.credentials_checking_policy
    }
    ...
}
```

Finally, we need to use the function that checks credentials when processes are
loaded (not just loads and executes them unconditionally):

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

(Instead of just `kernel::process::load_processes(...)`.)

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
 0      blink                    0         0         0   0/16   CredentialsFailed
tock$
```

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

## Implementing a Per-App Fault Policy

The default operation of the Sha256 checker is not quite what we want. We want
all apps to run, but only credentialed apps to be restarted.

First, we need to allow all apps to run, even if they don't pass the credential
check. Doing that is actually quite simple. We just need to modify the
credential checker we are using to not require credentials.

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
            kernel::process::ShortID::LocallyUnique => process::FaultAction::Stop,
            kernel::process::ShortID::Fixed(_) => {
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

Now we have the full policy: we verify application credentials, and handle
process faults accordingly.

> ### Task
>
> Compile and install multiple applications, including the crash dummy app, and
> verify that only credentialed apps are successfully restarted.

> **SUCCESS:** We now have implemented an end-to-end security policy in Tock!

## Implementing a Syscall Filter

Another policy the kernel can enforce is limits on which system call a process
can call. To enable this, a board can configure the kernel with an object that
implements `SyscallFilter` which will be called on each system call a process
calls.

The `SyscallFilter` trait looks like the following:

```rust
trait SyscallFilter {
    /// Called on each system call to determine if it should be allowed or not.
    fn filter_syscall(
        &self, process: &dyn process::Process, syscall: &syscall::Syscall
    ) -> Result<(), errorcode::ErrorCode>;
}
```

The `filter_syscall()` returns `Ok()` if the system call is allowed, and `Err()`
with an `ErrorCode` if not.

### Syscall Filtering With TBF Headers

One method for filtering system calls is to use TBF headers which restrict the
capabilities of a process. These headers are included with the process and
specify which commands are permitted for each system call driver number.

The format of the permissions in the TBF header is as follows:

```rust
struct TbfHeaderDriverPermission {
    driver_number: u32,
    offset: u32,
    allowed_commands: u64,
}
```

Each driver number to be allowed is given its own `TbfHeaderDriverPermission`
entry and `allowed_commands` is a bitmask of which command numbers are
permitted.

#### Enable the Filter in the Kernel

To enable the kernel to filter using this header, we can use the
`kernel::platform::TbfHeaderFilterDefaultAllow` struct to implement
`SyscallFilter`. We must configure our kernel to use this like this:

Create the filter object:

```rust
let tbf_header_filter = static_init!(
    kernel::platform::TbfHeaderFilterDefaultAllow,
    kernel::platform::TbfHeaderFilterDefaultAllow {}
);
```

Add it to our `Platform` struct:

```rust
struct Platform {
    ...
    syscall_filter: &'static kernel::platform::TbfHeaderFilterDefaultAllow,
}
```

Add it when we create the platform object:

```rust
let platform = Platform {
    ...
    syscall_filter: tbf_header_filter,
}
```

And configure our kernel to use it:

```rust
impl KernelResources for Platform {
    ...
    type SyscallFilter = kernel::platform::TbfHeaderFilterDefaultAllow;
    ...
    fn syscall_filter(&self) -> &'static Self::SyscallFilter {
        self.syscall_filter
    }
    ...
}
```

Now compile and flash the kernel.

#### Run an App with Syscall Permissions

Now to test our filter we will experiment with the blink app. First, install the
normal blink app:

```
cd libtock-c/examples/blink
make
tockloader install --erase
```

As expected, you should see the LEDs blinking.

Now, add a TBF header permission for the LED driver. We can do this with
tockloader. We will grant the app permission to call the LED command 0 (check if
the LED driver is installed) but nothing else. To do this, run:

```
tockloader tbf tlv add permissions 0x00002 0
```

The arguments are:

- `0x00002`: Driver number. In this case, 0x2 is the LED driver number.
- `0`: Allow command number. We are permitting command number 0.

Now install the blink app with the modified TBF header:

```
tockloader install
```

You will notice the LEDs no longer blink. This is because the kernel is denying
the actual LED toggle command for the blink app.

If you use the process console, you can see the blink app is still active and
calling system calls:

```
tock$ list
 PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      Unique     blink                11071   2413394         0   1/16   Running
```

So it is running, it's just that its main kernel resource is being denied.

> **SUCCESS:** We can now compile and modify apps to restrict their system call
> usage.

### Syscall Filtering with Short IDs

Another method for filtering system calls is to implement a custom policy using
the `SyscallFilter` trait. In this example, we will implement a filter which
only allows one app to use the console.

First, we can implement our system call filter by creating a new implementation
of the `SyscallFilter` trait. This can be added directly in the `main.rs` file:

```rust
struct FilterConsole {}

impl kernel::platform::SyscallFilter for FilterConsole {
    fn filter_syscall(
        &self,
        process: &dyn process::Process,
        syscall: &syscall::Syscall
    ) -> Result<(), errorcode::ErrorCode> {
        match syscall {
            // We will just focus on command
            syscall::Syscall::Command {
                driver_number,
                subdriver_number,
                arg0: _,
                arg1: _,
            } => Ok(()),

            _ => Ok(()),
        }
    }
}
```

Now, we can check if the command is for the console, and only permit that
command if the process's `ShortID` is a known value (in this case 1).

```rust
struct FilterConsole {}

impl kernel::platform::SyscallFilter for FilterConsole {
    fn filter_syscall(
        &self,
        process: &dyn process::Process,
        syscall: &syscall::Syscall
    ) -> Result<(), errorcode::ErrorCode> {
        match syscall {
            // We will just focus on command
            syscall::Syscall::Command {
                driver_number,
                subdriver_number,
                arg0: _,
                arg1: _,
            } => {
                match driver_number {
                    capsules_core::console::DRIVER_NUM => {
                        match process.get_short_id() {
                            kernel::process:ShortID::Fixed(1) => Ok(()),
                            _ => Err(ErrorCode::NODEVICE)
                        }
                    }
                    _ => Ok(())
                }
            },

            _ => Ok(()),
        }
    }
}
```

Now we can put our custom filter into effect:

```rust
let console_filter = static_init!(
    FilterConsole,
    FilterConsole {}
);
```

Add it to our `Platform` struct:

```rust
struct Platform {
    ...
    syscall_filter: &'static FilterConsole,
}
```

Add it when we create the platform object:

```rust
let platform = Platform {
    ...
    syscall_filter: console_filter,
}
```

And configure our kernel to use it:

```rust
impl KernelResources for Platform {
    ...
    type SyscallFilter = FilterConsole;
    ...
    fn syscall_filter(&self) -> &'static Self::SyscallFilter {
        self.syscall_filter
    }
    ...
}
```

Now compile and flash the kernel.

To test this, install two apps: `c_hello` and `tests/hello_loop`. You should see
that only `c_hello` works because the hello_loop app does not have access to the
console.

> **SUCCESS:** You can now implement your own system call filtering policies!
