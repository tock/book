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
`process.



