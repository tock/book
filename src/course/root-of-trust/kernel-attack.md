# Kernel Attacks on the Encryption Service

In this last submodule of the HWRoT course, we'll explore how Tock's
kernel-level isolation mechanisms help protect sensitive operations in a HWRoT
context.

Our last attempt at an attack on the HWRoT encryption service--an SRAM dumping
attack--assumed that we were able to load a malicious application in the first
place. To give our attacker even more of an advantage this time, let's assume
that a hypothetical attacker of our HWRoT might try slip some questionable logic
into a kernel driver, and see how Tock provides defense-in-depth via
language-based isolation at the driver level.

> **NOTE:** For a full description of Tock's threat model and what forms of
> isolation it's intended to provide, see the Tock
> [Threat Model](https://book.tockos.org/doc/threat_model/threat_model) page
> elsewhere in the Tock Book.

## Background

### Rust Traits and Generics

The Rust programming language (which the Tock kernel is written in) allows for
defining methods on structs and enums, similar to class methods in many
languages.

Following this analogy, Rust _traits_ are approximately like interfaces in other
languages: they let you specify shared behavior between types. For instance, the
`Clone` trait in Rust roughly looks like

```
pub trait Clone {
  fn clone(&self) -> Self;
}
```

which indicates that any type that implements the `Clone` trait needs to provide
an implementation of `clone` returning something of its own type (`Self`) given
a reference to itself (`&self`).

Types can be bound by traits: for instance, a function signature like

```
fn duplicate<C: Clone>(value: C) { ... }
```

indicates that `duplicate()` is defined to be generic over any type `C` such
that `C` implements the `Clone` trait, and that the input to `duplicate()` will
be of this type `C`.

As a last note, traits can be marked as `unsafe` to denote that any
implementation of such a trait may need to rely on invariants that the Rust
compiler can't verify. One common example is the `Sync` trait, which types can
implement to indicate that they're safe to share between threads.

Because such traits can't be compiler-verified, the Rust compiler requires
implementations of them to be marked as `unsafe` as well, e.g.

```
struct MyStruct { ... }

unsafe impl Send for MyStruct {}
```

## Submodule Overview

We additionally have two small milestones in this section, one to add a driver
to our Tock kernel, and then one to add an application which uses it.

1. Milestone one adds a minimal driver which a userspace application can use to
   fault all running applications, but with the caveat that it requires the
   board definition to explicitly give it that permission.
2. Milestone two adds a userspace application to trigger this driver, and then
   demonstrates how Tock performs language-level access control to
   _capabilities_ which the Tock board definition has to explicitly grant.

## Setup

No additional setup is needed beyond the previous section.

## Starter Code

Again as in the previous section, we have some starter code in libtock-c. The
only new directory we'll use is the `quesitonable_service/` subdirectory in
`libtock-c/examples/tutorials/root_of_trust`.

To launch this 'questionable' service which we'll use to trigger the "fault all
processes" driver, simply navigate as per the previous submodules to the
"Questionable service" in the on-device menu, select it, and then select "Start"
as usual.

## Milestone One: Adding the "Fault All Processes" Driver

As a first step, we'll need to create a new capsule. For simplicity, since the
capsule is only a few lines, we simply provide it for you in
`tock/capsules/extra/src/tutorials/fault_all_processes.rs` and reproduce it
piece by piece here. First, we import everything and define a driver number to
identify our driver with. Since our encryption oracle uses `0x99999`, we'll use
`0x99998`.

```
use kernel::capabilities::ProcessManagementCapability;
use kernel::syscall::{CommandReturn, SyscallDriver};
use kernel::{ErrorCode, Kernel, ProcessId};

pub const DRIVER_NUM: usize = 0x99998;
```

Next, we'll define the Rust struct which defines our driver. We'll need it to
have a reference to the kernel, as well as a _capability_ of generic type `C`.
This capability will be necessary in a second, but for now we take it for
granted.

```
pub struct FaultAllProcesses<C: ProcessManagementCapability> {
    kernel: &'static Kernel,
    capability: C,
}
```

We then define a constructor which simply takes in a reference to the Tock
kernel and the capability itself we want.

```
impl<C: ProcessManagementCapability> FaultAllProcesses<C> {
    pub fn new(kernel: &'static Kernel, capability: C) -> Self {
        FaultAllProcesses { kernel, capability }
    }
}
```

Then, lastly, we implement Tock's `SyscallDriver` trait to specify how our
capsule should reply to Command syscalls from applications, using a `match` over
`command_num` to dispatch different actions for each command. Command number 0
for every Tock driver should return success to indicate that the driver in
question exists.

We select command number 1 to actually perform our "fault all applications"
action, using the Tock kernel's `hardfault_all_apps()` method. All other
commands (the `_ => ...` arm of the `match`) return a failure with error code
`NOSUPPORT`, indicating we only support command numbers 0 and 1.

```
impl<C: ProcessManagementCapability> SyscallDriver for FaultAllProcesses<C> {
    fn command(&self, command_num: usize, _: usize, _: usize, _: ProcessId) -> CommandReturn {
        match command_num {
            0 => CommandReturn::success(),
            1 => {
                kernel::debug!("Hardfaulting all applications...");
                self.kernel.hardfault_all_apps(&self.capability);
                kernel::debug!("All applications hardfaulted.");
                CommandReturn::success()
            }
            _ => CommandReturn::failure(ErrorCode::NOSUPPORT),
        }
    }
    ...
}
```

If we take a look at the implementation of `Kernel::hardfault_all_apps()`, we'll
see that it has signature

```
pub fn hardfault_all_apps<C: capabilities::ProcessManagementCapability>(&self, _c: &C) { ... }
```

which indicates that to be called, it needs to accept an input of generic type
`C` which implements the trait `capabilities::ProcessManagementCapability`.

As such, we'll need to do two things when modifying our board definition:

1. Create a new type (say `FaultAllProcessesCapability`) implementing the
   `capabilities::ProcessManagementCapability` trait.
2. Instantiate our new driver and provide it with an instance of our
   `FaultAllProcessesCapability` type

Opening `boards/tutorials/nrf52840dk-root-of-trust-tutorial/src/main.rs`, we can
get started.

1. First, let's define our new `FaultAllProcessesCapability` type. In Tock, the
   `ProcessManagementCapability` we need to implement is defined as follows:

   ```
   /// The `ProcessManagementCapability` allows the holder to control
   /// process execution, such as related to creating, restarting, and
   /// otherwise managing processes.
   pub unsafe trait ProcessManagementCapability {}
   ```

   This is an unsafe trait with no methods, so we won't have to do much to
   implement it. Add the following right above the definition of
   `struct Platform` in our `main.rs`:

   ```
   struct FaultAllProcessesCapability;
   unsafe impl capabilities::ProcessManagementCapability for FaultAllProcessesCapability {}
   ```

   Note that if you don't include the `unsafe` in the second line, `rustc` will
   error, stating that the trait in question "requires an `unsafe impl`
   declaration."

2. Now, let's actually add our driver to our platform. We'll want to add a new
   member `fault_all` to our `Platform` struct as follows

   ```
   struct Platform {
       ...
       fault_all: &'static capsules_extra::tutorials::fault_all_processes::FaultAllProcesses<
           FaultAllProcessesCapability,
       >,
   }
   ```

3. Lastly, in the actual `main()` function just above the block comment
   indicating "PLATFORM SETUP, SCHEDULER, AND KERNEL LOOP," define an instance
   of our driver using Tock's `static_init!` macro

   ```
   let fault_all = static_init!(
       capsules_extra::tutorials::fault_all_processes::FaultAllProcesses<
           FaultAllProcessesCapability,
       >,
       capsules_extra::tutorials::fault_all_processes::FaultAllProcesses::new(
           board_kernel,
           FaultAllProcessesCapability {},
       )
   );
   ```

   and add it into our instantiation of the `Platform` struct below

   ```
   let platform = Platform {
     ...
     fault_all,
   };
   ```

   You should now be able to build and install the kernel as usual; not much
   should be noticably different until the next step.

## Milestone Two: Triggering the "Fault All Processes" Driver

To actually trigger the driver, we'll need to send it a Command syscall with
command ID 1. We'll do this in two simple steps. To start, back in libtock-c,
rename `questionable_service_starter/` to just `questionable_service/`.

If you get stuck, see `questionable_service_milestone_one/`.

1. First, as with the previous submodules, copy your implementations of
   `wait_for_start()`, `setup_logging()`, and `log_to_screen()`, and call
   `wait_for_start()` and `setup_logging()` at the top of `main()`.

2. Now, change main to perform the following:

- Log to the screen that all apps are about to be hardfaulted
- Trigger the hardfault driver using `command()`, i.e.

  ```
  syscall_return_t cr = command(/* driver num */ 0x99998, /* command num */ 1, 0, 0);
  ```

- Add another log to screen (can be anything; this should never be reached, as
  the app should have already faulted)

Install and run the application. You should see that the first log appears, but
the second one never does. A fault dump should instead appear over the
`tockloader listen` console.

Now that we have a working setup, one quesiton might be whether we can make do
without adding a noisy `unsafe impl` in our board definition file `main.rs`,
likely the first file someone would inspect.

One idea might be to move the `unsafe impl` into our driver code. Unfortunately,
if we try that, e.g. by moving the struct definition into
`fault_all_proceses.rs` and changing our `Kernel::hardfault_all_apps()` call to

```
struct FaultAllProcessesCapability;
unsafe impl capabilities::ProcessManagementCapability for FaultAllProcessesCapability {}

impl SyscallDriver for FaultAllProcesses {
    fn command(&self, command_num: usize, _: usize, _: usize, _: ProcessId) -> CommandReturn {
        ...
        self.kernel.hardfault_all_apps(FaultAllProcessesCapability {});
        ...
    }
```

then `rustc` will error, noting "implementation of an `unsafe` trait." Indeed,
Tock drivers (and capsules in general!) _cannot_ make use of unsafe constructs,
so any capabilities given to them _must_ come from the board definition where
they can be more carefully audited. This makes following expected access control
policy a prerequisite for the kernel to compile.

Along with capabilities, disallowing `unsafe` code in drivers has many other
positive isolation effects. For instance, without access to `unsafe`, drivers
cannot use core functions like `core::slice::from_raw_parts()` to construct
slices to directly access memory, meaning they can only make use of memory
explicitly granted to them.

For more details on Tock's isolation mechanisms, see the
[Tock Design](https://tockos.org/documentation/design/) page on the website, as
well as the EuroSec 2022 paper
[_Tiered Trust for Useful Embedded Systems Security_](https://tockos.org/assets/papers/tock-security-model-EuroSec2022.pdf).
