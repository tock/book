# Kernel Attacks on the Encryption Service

In this last submodule of the HWRoT course, we'll explore how Tock's
kernel-level isolation mechanisms help protect sensitive operations in a HWRoT
context.

Our previous attempt at an attack on the HWRoT encryption service—an SRAM
dumping attack—assumed that we were able to load a malicious application. As we
saw, Tock's process-level isolation guarantees prevented the malicious
application from being able to compromise other processes.

But what if the attacker tries to compromise the kernel itself? To give our
attacker even more of an advantage this time, let's assume that a hypothetical
attacker of our HWRoT might try slip some questionable logic into a kernel
driver, and see how Tock provides defense-in-depth via language-based isolation
at the driver level.

> **NOTE:** For a full description of Tock's threat model and what forms of
> isolation it's intended to provide, see the Tock
> [Threat Model](https://book.tockos.org/doc/threat_model/threat_model) page
> elsewhere in the Tock Book.

## Background

### Rust Traits and Generics

The Rust programming language (which the Tock kernel is written in) allows for
defining methods on structs and enums, similar to class methods in many
languages.

Following this analogy, Rust _traits_ are like interfaces in other languages:
they let you specify shared behavior between types. For instance, the `Clone`
trait in Rust roughly looks like

```rust
pub trait Clone {
  fn clone(&self) -> Self;
}
```

which indicates that any type that implements the `Clone` trait needs to provide
an implementation of `clone` returning something of its own type (`Self`) given
a reference to itself (`&self`). Implementations are provided in `impl` blocks:
for instance, to implement the above trait, you might write something like

```rust
struct MyStruct { ... }

impl Clone for MyStruct {
    fn clone(&self) -> Self {
        ...
    }
}
```

Types can be bound by traits: for instance, a function signature like

```rust
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

```rust
struct MyStruct { ... }

unsafe impl Send for MyStruct {}
```

## Submodule Overview

Our goal in this submodule is to modify an existing kernel capsule to "slip in"
a function call that a (malicious) userspace app can trigger that compromises
the overall system integrity. To make this a subtle attack, the attacker wants
to hide this new function call in the kernel so that when the board maintainer
updates to a new version of Tock the attack is present in the kernel.

For demonstration, we will insert a call to `hardfault_all_apps()`. This is of
course a sensitive API designed exclusively for testing. This API should not be
accessible to userspace, but we will see if an attacker can expose this to
userspace without the board maintainer knowing about the change.

### Milestones

We additionally have two small milestones in this section: one to sneak some
logic into our encryption oracle driver, and then one to add an application
which uses it.

1. Milestone one adds a minimal bit of logic to the encryption oracle driver
   which a userspace application can use to fault all running applications, but
   with the caveat that it requires the board definition to explicitly give it
   that permission.
2. Milestone two adds a userspace application to trigger this driver, and then
   demonstrates how Tock performs language-level access control to
   _capabilities_ which the Tock board definition has to explicitly grant.

## Starter Code

Again as in the previous section, we have some starter code in libtock-c. The
only new directory we'll use is the `questionable_service/` subdirectory in
`libtock-c/examples/tutorials/root_of_trust/`.

To launch this 'questionable' service which we'll use to trigger the
`fault all processes` driver, simply navigate as per the previous submodules to
the `Questionable service` in the on-device menu, select it, and then select
`Start` as usual.

## Milestone One: Adding the `Fault All Processes` Driver

As a first step, we'll need to add some logic to our encryption oracle capsule.
Open `tock/capsules/extra/src/tutorials/encryption_oracle_chkpt5.rs` (the
completed encryption oracle driver) and do the following:

1. First, we need to ensure our compromised driver has a reference to the
   kernel, as well as a _capability_ of generic type `C`. This capability will
   be necessary in a second, but for now we take it for granted. Down where the
   `EncryptionOracleDriver` struct is, add a new type parameter
   `C: ProcessManagerCapability`, and then a `kernel` and `capability` member:

   ```rust
   pub struct EncryptionOracleDriver<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> {
       kernel: &'static kernel,
       capability: C,
       aes: &'a A,
       process_grants: Grant<
           ProcessState,
           ...
       >,
       ...
   }
   ```

   Don't forget to add an import for
   `kernel::capabilities::ProcessManagementCapability` and `kernel::Kernel` as
   well at the top of the file:

   ```rust
   use core::cell::Cell;

   use kernel::capabilities::ProcessManagementCapability;
   use kernel::grant::{AllowRoCount, AllowRwCount, Grant, UpcallCount};
   ...
   use kernel::{ErrorCode, Kernel};
   ...
   ```

2. Next, now that we've added a new type parameter to `EncryptionOracleDriver`,
   we'll need to change the implementations of each `impl` block so that enough
   type parameters are provided to it. In the `impl` block just below our
   newly-modified struct definition, we'll change

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr> EncryptionOracleDriver<'a, A> {
      ...
   }
   ```

   to

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> EncryptionOracleDriver<'a, A, C> {
      ...
   }
   ```

   Later in the file, you'll also want to change

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr> SyscallDriver for EncryptionOracleDriver<'a, A> {
       ...
   }
   ```

   to

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> SyscallDriver
       for EncryptionOracleDriver<'a, A, C>
   {
       ...
   }
   ```

   and

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr> Client<'a> for EncryptionOracleDriver<'a, A> {
       ...
   }
   ```

   to

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> Client<'a>
       for EncryptionOracleDriver<'a, A, C>
   {
       ...
   }
   ```

3. Now, we need to change our `new()` associated function to accept a reference
   to the kernel as well as an instance of our desired capability. Add `kernel`
   and `capability` as new arguments to `new()`, and use them to construct the
   returned `EncryptionOracleDriver`:

   ```rust
       /// Create a new instance of our encryption oracle userspace driver:
       pub fn new(
           kernel: &'static kernel,
           capability: C,
           aes: &'a A,
           source_buffer: &'static mut [u8],
           ...
       ) -> Self {
           EncryptionOracleDriver {
               kernel,
               capability,
               process_grants,
               aes,
               ...
           }
       }
       ...
   ```

4. Lastly, we want to sneak in our new logic. In the definition of `command()`
   is a large `match` statement that causes our `EncryptionOracleDriver` to
   exhibit different behavior when it receives a command based on the value of
   `command_num`. We'll add a new branch for command number 2 to fault every
   application.

   ```rust
   impl<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> SyscallDriver
       for EncryptionOracleDriver<'a, A, C>
   {
       fn command(
           &self,
           command_num: usize,
           ...
       ) -> CommandReturn {
           match command_num {
               ...

               // Request the decryption operation:
               1 => {
                   ...
               }

               // Hardfault all applications
               2 => {
                   self.kernel.hardfault_all_apps(&self.capability);
                   CommandReturn::success()
               }

               // Unknown command number, return a NOSUPPORT error
               _ => CommandReturn::failure(ErrorCode::NOSUPPORT),
           }
       }
   }
   ```

With this, our changes to the driver are complete! Whenever it receives a
Command syscall with command number 2, it should fault every application.

If we take a look at the implementation of the `Kernel::hardfault_all_apps()`
function we used, we'll see that it has signature

```rust
pub fn hardfault_all_apps<C: capabilities::ProcessManagementCapability>(&self, _c: &C) { ... }
```

which indicates that to be called, it needs to accept an input of generic type
`C` which implements the trait `capabilities::ProcessManagementCapability`.

As such, we'll need to do two things when modifying our board definition:

1. Create a new type (say `EncryptionOracleCapability`) implementing the
   `capabilities::ProcessManagementCapability` trait.
2. Instantiate our new driver and provide it with an instance of our
   `EncryptionOracleCapability` type

Opening `boards/tutorials/nrf52840dk-root-of-trust-tutorial/src/main.rs`, we can
get started.

1.  First, let's define our new `EncryptionOracleCapability` type. In Tock, the
    `ProcessManagementCapability` we need to implement is defined as follows:

    ```rust
    /// The `ProcessManagementCapability` allows the holder to control
    /// process execution, such as related to creating, restarting, and
    /// otherwise managing processes.
    pub unsafe trait ProcessManagementCapability {}
    ```

    This is an unsafe trait with no methods, so we won't have to do much to
    implement it. Add the following right above the definition of
    `struct Platform` in our `main.rs`:

    ```rust
    struct EncryptionOracleCapability;
    unsafe impl capabilities::ProcessManagementCapability for EncryptionOracleCapability {}
    ```

    Note that if you don't include the `unsafe` in the second line, `rustc` will
    error, stating that the trait in question
    ``requires an `unsafe impl` declaration.``

2.  Now, let's tweak our platform to indicate that the oracle driver takes in an
    `EncryptionOracleCapability`. You'll want to modify the `Platform` struct
    definition to read as follows:

    ```rust
    struct Platform {
        base: nrf52840dk_lib::Platform,
        screen: &'static ScreenDriver,
        oracle: &'static capsules_extra::tutorials::encryption_oracle_chkpt5::EncryptionOracleDriver<
            'static,
            nrf52840::aes::AesECB<'static>,
            EncryptionOracleCapability,
        >,
    }
    ```

3.  Lastly, in the actual `main()` function just above the block comment
    indicating `PLATFORM SETUP, SCHEDULER, AND KERNEL LOOP,` you'll want to
    modify the initialization of the encryption oracle driver to include our
    reference to the kernel and an instance of our capability.

    ```rust
    let oracle = static_init!(
        capsules_extra::tutorials::encryption_oracle_chkpt5::EncryptionOracleDriver<
            'static,
            nrf52840::aes::AesECB<'static>,
            EncryptionOracleCapability,
        >,
        capsules_extra::tutorials::encryption_oracle_chkpt5::EncryptionOracleDriver::new(
            board_kernel,
            EncryptionOracleCapability {},
            &nrf52840_peripherals.nrf52.ecb,
            aes_src_buffer,
            ...
        ),
    );
    ```

    You should now be able to build and install the kernel as usual; not much
    should be noticeably different until the next step.

## Milestone Two: Triggering the `Fault All Processes` Driver

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

  ```c
  syscall_return_t cr = command(/* driver num */ 0x99999, /* command num */ 2, 0, 0);
  ```

- Add another log to screen (can be anything; this should never be reached, as
  the app should have already faulted)

Install and run the application. You should see that the first log appears, but
the second one never does. A fault dump should instead appear over the
`tockloader listen` console.

Now that we have a working setup, one question might be whether we can make do
without adding a noisy `unsafe impl` in our board definition file `main.rs`,
likely the first file someone would inspect.

One idea might be to move the `unsafe impl` into our driver code. Unfortunately,
if we try that, e.g. by moving the struct definition into
`fault_all_proceses.rs` and changing our `Kernel::hardfault_all_apps()` call to

```rust
struct EncryptionOracleCapability;
unsafe impl capabilities::ProcessManagementCapability for FaultAllProcessesCapability {}

impl<'a, A: AES128<'a> + AES128Ctr, C: ProcessManagementCapability> SyscallDriver
   for EncryptionOracleDriver<'a, A, C>
{
   fn command(
       &self,
       command_num: usize,
       ...
   ) -> CommandReturn {
       match command_num {
           ...
           // Hardfault all applications
           2 => {
               self.kernel.hardfault_all_apps(EncryptionOracleCapability {});
               CommandReturn::success()
           }
           ...
       }
   }
}
```

then `rustc` will error, noting ``implementation of an `unsafe` trait.`` Indeed,
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
