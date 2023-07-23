# Encryption Oracle Capsule

Our HOTP security key works by storing a number of secrets on the device, and
using these secrets together with some _moving factor_ (e.g., a counter value or
the current time) in an HMAC operation. This implies that our device needs some
way to store these secrets, for instance in its internal flash.

However, storing such secrets in plaintext in ordinary flash is often not
particularly secure. For instance, many microcontrollers offer debugging ports
which can be used to gain read and write access to flash. Commonly, these ports
can be restricted to disallow external flash access. However, this makes it
harder to debug or update devices, and such protections [have been broken in the
past](https://blog.includesecurity.com/2015/11/firmware-dumping-technique-for-an-arm-cortex-m0-soc/).

To circumvent these issues, we will build an _encryption oracle_ capsule: this
Tock kernel module will allow applications to request decryption of some
ciphertext, using some kernel-internal key not exposed to applications
themselves. This allows the applications to store their encrypted secrets in
unprotected flash, or even external to the device itself. This is a commonly
used paradigm in _root of trust_ systems such as TPMs or
[OpenTitan](https://opentitan.org/), which feature hardware-embedded keys that
are unique to a chip and hardened against readout attacks.

Our kernel module will use a hard-coded symmetric encryption (AES-128 CTR-mode)
key, embedded in the kernel binary. While this does not actually meaningfully
increase the security of our example application, it demonstrates some important
concepts in Tock:

- how to write custom userspace drivers, and the different types of system calls
  supported,
- how Tock implements asynchronous APIs in the kernel, and
- Tock's hardware-interface layers (HILs), which provide abstract interfaces for
  hardware or software implementations of algorithms, devices and protocols.

## Capusles – Tock's Kernel Modules

Most of Tock's functionality is implemented in the form of capsules capsules –
Tock's equivalent to kernel modules. Capsules are Rust modules located in crates
under `capsules/` in the Tock kernel repository. They can be used to implement
userspace drivers, hardware drivers (for example, a driver for an I²C-connected
sensor), or generic reusable code snippets.

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

This license header is just a formality, and we will be filling this module with
more interesting contents soon. To make this capsule accessible to other Rust
modules and crates, add it to `capsules/tutorials/src/lib.rs`:

```diff
+ TODO
 ```

The `capsules/tutorial` crate already contains checkpoints of the encryption
oracle capsule we'll be writing here. Feel free to use them if you're stuck. We
indicate that your capsule should have reached an equivalent state to one of our
checkpoints through messages like the following:

> **CHECKPOINT:** `encryption_oracle_chkpt0.rs`

> **BACKGROUND:** While we call individual Rust _modules_ (files) "capsules",
> these are again grouped into Rust crates such as `capsules/core` and
> `capsules/extra`, depending on a variety of factors. For instance, capsules in
> `core` have stricter requirements regarding their code quality and API
> stability. Neither `core` nor the `extra` `extra` capsules crates allow for
> external dependencies (outside of the Tock repository). [The document on
> external
> dependencies](https://github.com/tock/tock/blob/master/doc/ExternalDependencies.md)
> further explains these policies.

## Userspace Drivers

Now that we have a basic capsule skeleton, we can think about how this code is
going to interact with userspace applications. Not every capsule needs to offer
a userspace API, and capsules which do are required to implement [the
`SyscallDriver`
trait](https://docs.tockos.org/kernel/syscall/trait.syscalldriver).

Tock supports different types of application-issued systems calls, four of which
are relevant to capsules:

- _subscribe_: An application can issue a _subscribe_ system call to register
  _upcalls_, which are functions being invoked in response to certain
  events. These upcalls are similar in concept to UNIX signal handlers. A
  driver can request an application-provided upcall to be invoked. Each system
  call driver can provide multiple "subscribe slots", each of which the
  application can register a upcall to.

- _read-only allow_: An application may expose some data for drivers to
  read. Tock provides the _read-only allow_ system call for this purpose: an
  application invokes this system call passing a buffer, the contents of which
  are then made accessible to the requested driver. Each driver can have
  multiple "allow slots", each of which the application can place a buffer in.

- _read-write allow_: Works similar to read-only allow, but enables drivers to
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

Now there's just one key part missing to understanding Tock's system calls:
where the kernel keeps application-specific data.

This might seem like a silly question to ask, as surely we just allocate some
memory on demand. However, on resource constraint platforms such as
microcontrollers, allocating from a pool of (limited) memory can inevitably
become a prominent source of resource exhaustion errors: once there's no more
memory available, Tock wouldn't be able to service new allocation requests,
without revoking some prior allocations. This is especially bad when this memory
pool is shared between kernel resources belonging to multiple processes, as then
one process could potentially starve another.

To avoid these issues, Tock uses _grants_. A grant is a memory allocation
belonging to a process, and located within a process-assigned memory allocation,
but reserved for use by the kernel. Whenever a kernel component must keep track
of some process-related information, it can use a grant to hold this
information. By allocating memory from a process-specific memory region it is
impossible for one process to starve another's memory allocations, independent
of whether those are in the process itself or in the kernel. As a consequence,
Tock does not have a kernel-heap at all.

Ultimately, our encryption oracle driver will need to keep track of some
per-process state. Thus we extend the above driver with a Rust struct to be
stored in such a grant memory region, called `App`. For now, we just store
whether a process has requested a decryption operation:

```rust
#[derive(Default)]
pub struct App {
    request_pending: bool,
}
```

By implementing `Default`, grant types can be allocated and initialized on
demand. We integrate this type into our `EncryptionOracleDriver` by adding a
special `apps` variable of type `Grant`. This `Grant` struct takes a generic
type parameter `T`, which we set to our `App` struct above, next to some
constants: as a driver's subscribe upcall and allow buffer slots also consume
some memory, we store them in the process-specific grant as well. Thus,
`UpcallCount`, `AllowRoCont`, and `AllowRwCount` indicate how many of these
slots should be allocated respectively. For now we don't use any of these slots,
so we set their counts to zero:

```rust
use kernel::grant::{Grant, UpcallCount, AllowRoCount, AllowRwCount};

pub struct EncryptionOracleDriver {
    apps: Grant<
	    App,
		UpcallCount<0>,
		AllowRoCount<0>,
		AllowRwCount<0>,
	>,
}
```

> **EXERCISE:** The `Grant` struct will be provided as an argument to
> constructor of the `EncryptionOracleDriver`. Extend `new` to accept it as an
> argument.

## Implementing a System Call

Now that we know about grants we can start to implement a proper system call. We
will start with the basics and implement a simple _command_-type system call:
upon request by the application, the Tock kernel will trigger a method in our
capsule.

For this, we implement the following `SyscallDriver` trait for our
`EncryptionOracleDriver` struct. This trait contains two important methods:
- `command`: this method is called whenever an application issues a
  _command_-type system call towards this driver, and
- `allocate_grant`: this is a method required by Tock to allocate some space in
  the process' memory region. This method always looks the same, and while it
  must be implemented by every userspace driver, it's exact purpose is not
  important right now.

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
        self.apps.enter(processid, |_, _| {})
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

Our driver can respond to this system call using a `CommandReturn` structs. This
struct allows for returning either a success or an error indication, along with
some data (at most four `usize` return values). For more details, you can look
at its definition and API
[here](https://docs.tockos.org/kernel/syscall/struct.commandreturn).

In our encryption oracle driver we only need to handle a single application
request: to decrypt some ciphertext into its corresponding plaintext. As we are
missing the actually cryptography implementation still, for now let's simply
store that a process has made such a request, and store this in its
`request_pending` field in the grant region. To obtain a reference to the
process' grant region, we can conveniently use the `ProcessId` type provided to
us by the kernel. The following code snippet shows how an implementation of the
`command` could look like. Replace your `command` method body with this snippet:

```rust
match command_num {
    // Check whether the driver is present:
    0 => CommandReturn::success(),

    // Request the decryption operation:
    1 => {
        self
            .apps
            .enter(processid, |app, _kernel_data| {
                app.request_pending = true;
				CommandReturn::success()
            })
	        .unwrap_or_else(|err| err.into())
	},

    // Unknown command number, return a NOSUPPORT error
	_ => CommandReturn::failure(ErrorCode::NOSUPPORT),
}
```

Okay, there's a lot to unpack here: first, we match on the passed
`command_num`. By convention, command number `0` is reserved to check whether a
driver is loaded on a kernel. If our code is executing, then this is the case,
and we hence return `success`. For unknown commands, we must instead return a
`NOSUPPORT` error.

Command number `1` is assigned to start the decryption operation. To get a
reference to our process-local state stored in its grant region, we can use the
`enter` method: it takes a `ProcessId`, and in return will call a provided Rust
closure that provides us access to the process' own `App` instance. Because
entering a grant can fail (for instance when the process does not have
sufficient memory available), we handle any errors by converting them into a
`CommandReturn`.

> **CHECKPOINT:** `encryption_oracle_chkpt0.rs`

Congratulations, you have implemented your first Tock system call! Next, we will
look into how you can integrate this driver into your kernel build.

## Adding a Capsule to a Tock Kernel

**TODO!**

## Interacting with HILs

**TODO!** (this should cover asynchronicity and buffer passing)

## Final Steps

**TODO!**
