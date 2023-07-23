# Encryption Oracle Capsule

Our HOTP security key works by storing a number of secrets on the device, and
using these secrets together with some _moving factor_ (e.g., a counter value or
the current time) in an HMAC operation. This implies that our device needs some
way to store these secrets, for instance in its internal flash.

However, storing such secrets in plaintext in ordinary flash is not particularly
secure. For instance, many microcontrollers offer debug ports which can be used
to gain read and write access to flash. Even if these ports can be locked down,
[such protection mechanisms have been broken in the past](https://blog.includesecurity.com/2015/11/firmware-dumping-technique-for-an-arm-cortex-m0-soc/).
Apart from that, disallowing external flash access makes debugging and updating
our device much more difficult.

To circumvent these issues, we will build an _encryption oracle capsule_: this
Tock kernel module will allow applications to request decryption of some
ciphertext, using a kernel-internal key not exposed to applications themselves.
By only storing an encrypted version of their secrets, applications are free to
use unprotected flash storage, or store them even external to the device itself.
This is a commonly used paradigm in _root of trust_ systems such as TPMs or
[OpenTitan](https://opentitan.org/), which feature hardware-embedded keys that
are unique to a chip and hardened against key-readout attacks.

Our kernel module will use a hard-coded symmetric encryption key (AES-128
CTR-mode), embedded in the kernel binary. While this does not actually
meaningfully increase the security of our example application, it demonstrates
some important concepts in Tock:

- How custom userspace drivers are implemented, and the different types of
  system calls supported.
- How Tock implements asynchronous APIs in the kernel.
- Tock's hardware-interface layers (HILs), which provide abstract interfaces for
  hardware or software implementations of algorithms, devices and protocols.

## Capsules – Tock's Kernel Modules

Most of Tock's functionality is implemented in the form of capsules – Tock's
equivalent to kernel modules. Capsules are Rust modules contained in Rust crates
under the `capsules/` directory within the Tock kernel repository. They can be
used to implement userspace drivers, hardware drivers (for example, a driver for
an I²C-connected sensor), or generic reusable code snippets.

What makes capsules special is that they are _semi-trusted_: they are not
allowed to contain any `unsafe` Rust code, and thus can never violate Tock's
memory safety guarantees. They are only trusted with respect to _liveness_ and
_correctness_ – meaning that they must not block the kernel execution for long
periods of time, and should behave correctly according to their specifications
and API contracts.

We start our encryption oracle driver by creating a new capsule called
`encryption_oracle`. Create a file under
`capsules/tutorials/src/encryption_oracle.rs` in the Tock kernel repository with
the following contents:

```rust
// Licensed under the Apache License, Version 2.0 or the MIT License.
// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright Tock Contributors 2022.

pub static KEY: &'static [u8; kernel::hil::symmetric_encryption::AES128_KEY_SIZE] =
    b"InsecureAESKey12";

pub struct EncryptionOracleDriver {}

impl EncryptionOracleDriver {
    /// Create a new instance of our encryption oracle userspace driver:
    pub fn new() -> Self {
        EncryptionOracleDriver {}
    }
}

```

We will be filling this module with more interesting contents soon. To make this
capsule accessible to other Rust modules and crates, add it to
`capsules/tutorials/src/lib.rs`:

```diff
+ TODO
```

> **EXERCISE:** Make sure your new capsule compiles by running `cargo check` in
> the `capsules/tutorials/` folder.

The `capsules/tutorial` crate already contains checkpoints of the encryption
oracle capsule we'll be writing here. Feel free to use them if you're stuck. We
indicate that your capsule should have reached an equivalent state to one of our
checkpoints through blocks such as the following:

> **CHECKPOINT:** `encryption_oracle_chkpt0.rs`

> **BACKGROUND:** While a single "capsule" is generally self-contained in a Rust
> _module_ (`.rs` file), these modules are again grouped into Rust crates such
> as `capsules/core` and `capsules/extra`, depending on certain policies. For
> instance, capsules in `core` have stricter requirements regarding their code
> quality and API stability. Neither `core` nor the `extra` `extra` capsules
> crates allow for external dependencies (outside of the Tock repository).
> [The document on external dependencies](https://github.com/tock/tock/blob/master/doc/ExternalDependencies.md)
> further explains these policies.

## Userspace Drivers

Now that we have a basic capsule skeleton, we can think about how this code is
going to interact with userspace applications. Not every capsule needs to offer
a userspace API, but those that do must implement
[the `SyscallDriver` trait](https://docs.tockos.org/kernel/syscall/trait.syscalldriver).

Tock supports different types of application-issued systems calls, four of which
are relevant to userspace drivers:

- _subscribe_: An application can issue a _subscribe_ system call to register
  _upcalls_, which are functions being invoked in response to certain events.
  These upcalls are similar in concept to UNIX signal handlers. A driver can
  request an application-provided upcall to be invoked. Every system call driver
  can provide multiple "subscribe slots", each of which the application can
  register a upcall to.

- _read-only allow_: An application may expose some data for drivers to read.
  Tock provides the _read-only allow_ system call for this purpose: an
  application invokes this system call passing a buffer, the contents of which
  are then made accessible to the requested driver. Every driver can have
  multiple "allow slots", each of which the application can place a buffer in.

- _read-write allow_: Works similarly to read-only allow, but enables drivers to
  also mutate the application-provided buffer.

- _command_: Applications can use _command_-type system calls to signal
  arbitrary events or send requests to the userspace driver. A common use-case
  for command-style systems calls is, for instance, to request that a driver
  start some long-running operation.

All Tock system calls are synchronous, which means that they should immediately
return to the application. In fact, _subscribe_ and _allow_-type system calls
are transparently handled by the kernel, as we will see below. Capsules must not
implement long-running operations by blocking on a command system call, as this
prevents other applications or kernel routines from running – kernel code is
never preempted.

## Application Grants

Now there's just one key part missing to understanding Tock's system calls: how
drivers store application-specific data. Tock differs significantly from other
operating systems in this regard, which typically simply allocate some memory on
demand through a _heap allocator_.

However, on resource constraint platforms such as microcontrollers, allocating
from a pool of (limited) memory can inevitably become a prominent source of
resource exhaustion errors: once there's no more memory available, Tock wouldn't
be able to service new allocation requests, without revoking some prior
allocations. This is especially bad when this memory pool is shared between
kernel resources belonging to multiple processes, as then one process could
potentially starve another.

To avoid these issues, Tock uses _grants_. A grant is a memory allocation
belonging to a process, and is located within a process-assigned memory
allocation, but reserved for use by the kernel. Whenever a kernel component must
keep track of some process-related information, it can use a grant to hold this
information. By allocating memory from a process-specific memory region it is
impossible for one process to starve another's memory allocations, independent
of whether those allocations are in the process itself or in the kernel. As a
consequence, Tock can avoid implementing a kernel heap allocator entirely.

Ultimately, our encryption oracle driver will need to keep track of some
per-process state. Thus we extend the above driver with a Rust struct to be
stored within a grant, called `App`. For now, we just keep track of whether a
process has requested a decryption operation. Add the following code snippet to
your capsule:

```rust
#[derive(Default)]
pub struct ProcessState {
    request_pending: bool,
}
```

By implementing `Default`, grant types can be allocated and initialized on
demand. We integrate this type into our `EncryptionOracleDriver` by adding a
special `process_grants` variable of
[type `Grant`](https://docs.tockos.org/kernel/grant/struct.grant). This `Grant`
struct takes a generic type parameter `T` (which we set to our `ProcessState`
struct above) next to some constants: as a driver's subscribe upcall and allow
buffer slots also consume some memory, we store them in the process-specific
grant as well. Thus, `UpcallCount`, `AllowRoCont`, and `AllowRwCount` indicate
how many of these slots should be allocated respectively. For now we don't use
any of these slots, so we set their counts to zero. Add the `process_grants`
variable to your `EncryptionOracleDriver`:

```rust
use kernel::grant::{Grant, UpcallCount, AllowRoCount, AllowRwCount};

pub struct EncryptionOracleDriver {
    process_grants: Grant<
        ProcessState,
        UpcallCount<0>,
        AllowRoCount<0>,
        AllowRwCount<0>,
    >,
}
```

> **EXERCISE:** The `Grant` struct will be provided as an argument to
> constructor of the `EncryptionOracleDriver`. Extend `new` to accept it as an
> argument. Afterwards, make sure your code compiles by running `cargo check` in
> the `capsules/tutorials/` directory.

## Implementing a System Call

Now that we know about grants we can start to implement a proper system call. We
start with the basics and implement a simple _command_-type system call: upon
request by the application, the Tock kernel will call a method in our capsule.

For this, we implement the following `SyscallDriver` trait for our
`EncryptionOracleDriver` struct. This trait contains two important methods:

- [`command`](https://docs.tockos.org/kernel/syscall/trait.syscalldriver#method.command):
  this method is called whenever an application issues a _command_-type system
  call towards this driver, and
- [`allocate_grant`](https://docs.tockos.org/kernel/syscall/trait.syscalldriver#tymethod.allocate_grant):
  this is a method required by Tock to allocate some space in the process'
  memory region. The implementation of this method always looks the same, and
  while it must be implemented by every userspace driver, it's exact purpose is
  not important right now.

```rust
use kernel::ProcessId;
use kernel::syscall::{SyscallDriver, CommandReturn};

impl SyscallDriver for EncryptionOracleDriver {
    fn command(
        &self,
        command_num: usize,
        _data1: usize,
        _data2: usize,
        processid: ProcessId,
    ) -> CommandReturn {
        // Syscall handling code here!
        unimplemented!()
    }

    // Required by Tock for grant memory allocation.
    fn allocate_grant(&self, processid: ProcessId) -> Result<(), kernel::process::Error> {
        self.process_grants.enter(processid, |_, _| {})
    }
}
```

The function signature of `command` tells us a lot about what we can do with
this type of system call:

- Applications can provide a `command_num`, which indicates what type of
  _command_ they are requesting to be handled by a driver, and
- they can optionally pass up to two `usize` data arguments.
- The kernel further provides us with a unique identifier of the calling
  process, through a type called `ProcessId`.

Our driver can respond to this system call using a `CommandReturn` struct. This
struct allows for returning either a _success_ or a _failure_ indication, along
with some data (at most four `usize` return values). For more details, you can
look at its definition and API
[here](https://docs.tockos.org/kernel/syscall/struct.commandreturn).

In our encryption oracle driver we only need to handle a single application
request: to decrypt some ciphertext into its corresponding plaintext. As we are
missing the actual cryptographic operations still, let's simply store that a
process has made such a request. Because this is per-process state, we store it
in the `request_pending` field of the process' grant region. To obtain a
reference to this memory, we can conveniently use the `ProcessId` type provided
to us by the kernel. The following code snippet shows how an implementation of
the `command` could look like. Replace your `command` method body with this
snippet:

```rust
match command_num {
    // Check whether the driver is present:
    0 => CommandReturn::success(),

    // Request the decryption operation:
    1 => {
        self
            .process_grants
            .enter(processid, |app, _kernel_data| {
			    kernel::debug!("Received request from process {:?}", processid);
                app.request_pending = true;
                CommandReturn::success()
            })
            .unwrap_or_else(|err| err.into())
    },

    // Unknown command number, return a NOSUPPORT error
    _ => CommandReturn::failure(ErrorCode::NOSUPPORT),
}
```

There's a lot to unpack here: first, we match on the passed `command_num`. By
convention, command number `0` is reserved to check whether a driver is loaded
on a kernel. If our code is executing, then this must be the case, and thus we
simply return `success`. For all other unknown command numbers, we must instead
return a `NOSUPPORT` error.

Command number `1` is assigned to start the decryption operation. To get a
reference to our process-local state stored in its grant region, we can use the
`enter` method: it takes a `ProcessId`, and in return will call a provided _Rust
closure_ that provides us access to the process' own `ProcessState` instance.
Because entering a grant can fail (for instance when the process does not have
sufficient memory available), we handle any errors by converting them into a
`CommandReturn`.

> **EXERCISE:** Make sure that your `EncryptionOracleDriver` implements the
> `SyscallDriver` trait as shown above. Then, verify that your code compiles by
> running `cargo check` in the `capsules/tutorials/` folder.

> **CHECKPOINT:** `encryption_oracle_chkpt1.rs`

Congratulations, you have implemented your first Tock system call! Next, we will
look into how to to integrate this driver into a kernel build.

## Adding a Capsule to a Tock Kernel

To actually make our driver available in a given build of the kernel, we need to
add it to a _board crate_. Board crates tie the kernel, a given _chip_, and a
set of drivers together to create a binary build of the Tock operating system,
which can then be loaded into a physical board. For the purposes of this
section, we assume to be targeting the Nordic Semiconductor nRF52840DK board,
and thus will be working in the `boards/nordic/nrf52840dk/` directory.

> **EXERCISE:** Enter the `boards/nordic/nrf52840dk/` directory and compile a
> kernel by typing `make`. A successful build should end with a message that
> looks like the following:
>
>         Finished release [optimized + debuginfo] target(s) in 20.34s
>        text    data     bss     dec     hex filename
>      176132       4   33284  209420   3320c /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk
>     [Hash ommitted]  /home/tock/tock/target/thumbv7em-none-eabi/release/nrf52840dk.bin

Applications interact with our driver by passing a "driver number" alongside
their system calls. The `capsules/core/src/driver.rs` module acts as a registry
for driver numbers. For the purposes of this tutorial we'll use an unassigned
driver number in the _misc_ range, `0x99999`.

### Accepting an AES Engine in the Driver

Before we start adding our driver to the board crate, we'll modify it slightly
to acceppt an instance of an `AES128` cryptography engine. This is to avoid
modifying our driver's instantiation later on. We provide the
`encryption_oracle_chkpt2.rs` checkpoint which has these changes integrated,
feel free to use this code. We make the following mechanical changes to our
types and constructor – don't worry about them too much right now.

First, we change our `EncryptionOracleDriver` struct to hold a reference to some
generic type `A`, which must implement the `AES128` and the `AESCtr` traits:

```diff
+ use kernel::hil::symmetric_encryption::{AES128Ctr, AES128};

- pub struct EncryptionOracleDriver {
+ pub struct EncryptionOracleDriver<'a, A: AES128<'a> + AES128Ctr {
+     aes: &'a A,
      process_grants: Grant<
          ProcessState,
          UpcallCount<0>,
```

Then, we change our constructor to accept this `aes` member as a new argument:

```diff
- impl EncryptionOracleDriver {
+ impl<'a, A: AES128<'a> + AES128Ctr> EncryptionOracleDriver<'a, A> {
      /// Create a new instance of our encryption oracle userspace driver:
      pub fn new(
+         aes: &'a A,
+         _source_buffer: &'static mut [u8],
+         _dest_buffer: &'static mut [u8],
          process_grants: Grant<ProcessState, UpcallCount<0>, AllowRoCount<0>, AllowRwCount<0>>,
      ) -> Self {
          EncryptionOracleDriver {
              process_grants: process_grants,
+             aes: aes,
          }
      }
  }
```

And finally we update our implementation of `SyscallDriver` to match these new
types:

```diff
- impl SyscallDriver for EncryptionOracleDriver {
+ impl<'a, A: AES128<'a> + AES128Ctr> SyscallDriver for EncryptionOracleDriver<'a, A> {
      fn command(
          &self,
```

Finally, make sure that your modified capsule still compiles.

> **CHECKPOINT:** `encryption_oracle_chkpt2.rs`

### Instantiating the System Call Driver

Now, open the board's main file (`boards/nordic/nrf52840dk/src/main.rs`) and
scroll down to the line that reads "_PLATFORM SETUP, SCHEDULER, AND START KERNEL
LOOP_". We'll instantiate our encryption oracle driver right above that, with
the following snippet:

```rust
const CRYPT_SIZE: usize = 7 * kernel::hil::symmetric_encryption::AES128_BLOCK_SIZE;
let aes_src_buffer = kernel::static_init!([u8; 16], [0; 16]);
let aes_dst_buffer = kernel::static_init!([u8; CRYPT_SIZE], [0; CRYPT_SIZE]);

let oracle = static_init!(
    capsules_tutorials::encryption_oracle::EncryptionOracleDriver<
        'static,
        nrf52840::aes::AesECB<'static>,
    >,
    // Call our constructor:
    capsules_tutorials::encryption_oracle::EncryptionOracleDriver::new(
        &base_peripherals.ecb,
        aes_src_buffer,
        aes_dst_buffer,
		// Magic incantation to create our `Grant` struct:
        board_kernel.create_grant(
            0x99999, // our driver number
            &create_capability!(capabilities::MemoryAllocationCapability)
        ),
    ),
);

// Leave commented out for now:
// kernel::hil::symmetric_encryption::AES128::set_client(&base_peripherals.ecb, oracle);
```

Now that we instantiated our capsule, we need to wire it up to Tock's system
call handling facilities. This involves two steps: first, we need to store our
instance in our `Platform` struct. That way, we can refer to our instance while
the kernel is running. Then, we need to route system calls to our driver number
(`0x99999`) to be handled by this driver.

Add the following line to the very bottom of the `pub struct Platform {`
declaration:

```diff
  pub struct Platform {
      [...],
      systick: cortexm4::systick::SysTick,
+     oracle: &'static capsules_tutorials::encryption_oracle::EncryptionOracleDriver<
+         'static,
+         nrf52840::aes::AesECB<'static>,
+     >,
  }
```

Furthermore, add our instantiated oracle to the `let platform = Platform {`
instantiation:

```diff
  let platform = Platform {
      [...],
      systick: cortexm4::systick::SysTick::new_with_calibration(64000000),
+     oracle: oracle,
  };
```

Finally, to handle received system calls in our driver, add the following line
to the `match` block in the `with_driver` method of the `SyscallDriverLookup`
trait implementation:

```diff
  impl SyscallDriverLookup for Platform {
      fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
      where
          F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
      {
          match driver_num {
              capsules_core::console::DRIVER_NUM => f(Some(self.console)),
              [...],
              KEYBOARD_HID => f(Some(self.keyboard_hid_driver)),
+             0x99999 => f(Some(self.oracle)),
              _ => f(None),
          }
      }
  }
```

That's it! We have just added a new driver to the nRF52840DK's Tock kernel
build.

> **EXERCISE:** Make sure your board compiles by running `make`. If you want,
> you can test your driver with a libtock-c application which executes the
> following:
>
>     command(
>         0x99999, // driver number
>         1,       // command number
>         0, 0     // optional data arguments
>     );
>
> Upon receiving this system call, the capsule should print the "Received
> request from process" message.

## Interacting with HILs

**TODO: intro to HILs** (this should cover asynchronicity and buffer passing)

While our underlying `AES128` implementation can only handle one request at a
time, multiple processes may wish to use this driver. Thus our capsule
implements a queueing system: even when another process is already using our
capsule to decrypt some ciphertext, another process can still initate such a
request. We remember these requests through the `request_pending` flag in our
`ProcessState` grant, and we've already implemented the logic to set this flag!

Now, to actually implement our asynchronous decryption operation, it is further
important to keep track of which process' request we are currently working on.
We add an additional state field to our `EncryptionOracleDriver` holding an
[`OptionalCell`](https://docs.tockos.org/kernel/utilities/cells/struct.optionalcell):
this is a container whose stored value can be modified even if we only hold an
immutable Rust reference to it. The _optional_ indicates that it behaves similar
to an `Option` – it can either hold a value, or be empty.

```diff
  use kernel::utilities::cells::OptionalCell;

  pub struct EncryptionOracleDriver<'a, A: AES128<'a> + AES128Ctr> {
      aes: &'a A,
      process_grants: Grant<ProcessState, UpcallCount<0>, AllowRoCount<0>, AllowRwCount<0>>,
+     current_process: OptionalCell<ProcessId>,
  }
```

In practice, we simply want to find the next process request to work on, and
then store its ID in the field we just added. For this, we add a helper method
to the `impl` of our `EncryptionOracleDriver`:

```rust
/// Return either the current process (in case of an ongoing operation), or
/// a process which has a request pending (if there is some).
///
/// When returning a process which has a request pending, this method
/// further marks this as the new current process.
fn next_process(&self) -> Option<ProcessId> {
    unimplemented!()
}
```

> **EXERCISE:** Try to implement this method according to its specification. If
> you're stuck, see whether the documentation of the
> [`OptionalCell`](https://docs.tockos.org/kernel/utilities/cells/struct.optionalcell)
> and [`Grant`](https://docs.tockos.org/kernel/grant/struct.grant) types help.
> Hint: to do something with the `ProcessState` of all processes, you can use
> the
> [`iter` method on a `Grant`](https://docs.tockos.org/kernel/grant/struct.grant#method.iter):
> the returned `Iter` type then has an `enter` method access the contents of an
> invidiual process' grant.

> **CHECKPOINT:** `encryption_oracle_chkpt3.rs`

## Final Steps

**TODO!**
