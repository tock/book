# Tock Robustness

Setting Tock apart from many other embedded operating systems is security
design: applications are generally mutually distrustful. In practice, this means
that any misbehavior in one application should not affect other applications.
This includes both faults (such as invalid pointer dereferences, etc.), and
excessive resource utilization.

Take for instance a standard network application that implements all logic
within one application unit (i.e. links OpenThread directly to the platform
implementation). We consider two illustrative scenarios below of what may go
wrong and how Tock guards against such outcomes.

## Scenario 1 - Faulting Application

OpenThread is a large code base and interacts with a number of buffers.
Furthermore, our OpenThread app adds the complexity of sharing buffers across
IPC. Given the challenges in writing C code, it is likely that some aspect of
the application will fault at somepoint in the future.

In a traditional embedded platform, a fault in the OpenThread app or OpenThread
code base would in turn result in the platform itself faulting. Tock guards
against this by isolating different applications and the kernel using memory
protection. Subsequently, a faulting app can be handled by the kernel and the
broader system is left unharmed.

In practice, developers have the option to specify how the kernel should handle
such faults through a _fault policy_. Such policies can be user-defined, and
[Tock includes some by default](https://docs.tockos.org/kernel/?search=kernel%3A%3Aprocess%3A%3AFaultPolicy),
such as:

- `StopFaultPolicy`: stops the process upon a fault,
- `PanicFaultPolicy`: causes the entire platform to panic upon any process fault
  (useful for debugging), or
- `RestartWithDebugFaultPolicy`: restarts a process after it has faulted, and
  prints a message to the console informing users of this restart.

In this tutorial, our board-definition comes
[pre-configured with the `PanicFaultPolicy`](https://github.com/tock/tock/tree/master/boards/tutorials/nrf52840dk-thread-tutorial).

## Scenario 2 - Buggy Behavior

Alternatively, a bug in the controller app results in it entering some form of
infinite loop (be it deadlock or busy waiting). In a non-preemptive platform,
the system will be disabled due to this bug. However, because Tock preempts
applications, such a buggy application will no longer function, but the broader
system will be unharmed.

## Tock Kernel

Up to this juncture, we have exclusively worked within userspace. To demonstrate
Tock's ability to recover from faulting applications, we will first modify our
application and deliberately introduce a fault -- this will cause the kernel to
panic and print useful debug information. We then modify the kernel's fault
policy to instead restart the application.

We can see the fault policy that is in use with the kernel by looking at the
`tock/boards/tutorials/nrf52840dk-thread-tutorial/src/main.rs` file. It defines
a `FAULT_RESPONSE` variable with an instance of the fault policy that we want to
use:

```rust
// How should the kernel respond when a process faults.
const FAULT_RESPONSE: kernel::process::PanicFaultPolicy =
    kernel::process::PanicFaultPolicy {};
```

We can also artificially fault a process through Tock's process console. For
instance, when faulting our controller app, this can look like:

```
tock$ list
 PID    ShortID    Name                Quanta  Syscalls  Restarts  Grants  State
 0      Unique     thread_controller        1       130         0   5/18   Yielded
 1      Unique     org.tockos.thread-tutorial.sensor     0        91         0   3/18   Yielded
tock$ fault thread_controller

---| No debug queue found. You can set it with the DebugQueue component.

panicked at kernel/src/process_standard.rs:362:17:
Process thread_controller had a fault
        Kernel version release-2.1-2908-g9d9b87d83

---| Cortex-M Fault Status |---
No Cortex-M faults detected.

---| App Status |---
𝐀𝐩𝐩: thread_controller   -   [Faulted]
 Events Queued: 0   Syscall Count: 262   Dropped Upcall Count: 0
 Restart Count: 0
 Last Syscall: Yield { which: 1, address: 0x0 }
 Completion Code: None


 ╔═══════════╤══════════════════════════════════════════╗
 ║  Address  │ Region Name    Used | Allocated (bytes)  ║
 ╚0x2000E000═╪══════════════════════════════════════════╝
             │ Grant Ptrs      144
             │ Upcalls         320
```

## Injecting a Fault into the Application

For the purposes of this tutorial, we will dedicate one button (Button 4) to
inject an artificial fault into the control application. We can do this, for
instance, by simply dereferencing the NULL pointer: even on chips where this is
a valid memory location, Tock's memory protection will never expose this address
to an application.

> **EXERCISE:** Implement a button callback handler that dereferences the null
> pointer. You can do so with, for example:
>
> ```
> *((char*) NULL) = 42;
> ```
>
> Do not forget to register a callback handler for Button 4, too!

Now, whenever you press Button 4, your board should print output similar to the
above. Because the kernel panics, it will loop forever and blink LED1 in a
recognizable pattern. You will need to reset the board to restart the Tock
kernel and all applications.

## Switching the Fault Handler

With this application fault implemented, we can now switch the kernel's fault
policy to restart the offending application, instead of panicing the overall
kernel:

```diff
  // How should the kernel respond when a process faults.
- const FAULT_RESPONSE: kernel::process::PanicFaultPolicy = kernel::process::PanicFaultPolicy {};
+ const FAULT_RESPONSE: kernel::process::RestartWithDebugFaultPolicy =
+     kernel::process::RestartWithDebugFaultPolicy {};
```

After making this change, you will need to recompile the kernel, like so:

```
$ cd tock/boards/tutorials/nrf52840dk-thread-tutorial
$ make
   [...]
   Compiling nrf52_components v0.1.0 (/home/leons/proj/tock/kernel/boards/nordic/nrf52_components)
   Compiling nrf52840dk v0.1.0 (/home/leons/proj/tock/kernel/boards/nordic/nrf52840dk)
    Finished `release` profile [optimized + debuginfo] target(s) in 11.09s
   text    data     bss     dec     hex filename
 233474      36   41448  274958   4320e tock/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial
cb0df7abb1...d47b383aaf  tock/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial.bin
```

Finally, flash the new kernel using `make install`:

```
$ make install
tockloader  flash --address 0x00000 --board nrf52dk --jlink tock/kernel/target/thumbv7em-none-eabi/release/nrf52840dk-thread-tutorial.bin
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[STATUS ] Flashing binary to board...
[INFO   ] Finished in 9.901 seconds
```

Now, when you re-connect to the board, you should see that the application is
automatically being restarted every time it encounters a fault:

```
$ tockloader listen
tock$
Process thread_controller faulted and will be restarted.
[controller] Discovered sensor service: 1
Process thread_controller faulted and will be restarted.
[controller] Discovered sensor service: 1
Process thread_controller faulted and will be restarted.
[controller] Discovered sensor service: 1
```

## Conclusion

This concludes our tutorial on using Tock to build a Thread-connected HVAC
control system. We hope you enjoyed it!

We covered the following topics:

- how to build the Tock kernel, applications, and use Tockloader to install both
  onto a development board,
- placing system calls to interact with hardware peripherals, such as the
  temperature sensor, buttons, a screen, etc.,
- using existing C-based libraries in the `libtock-c` userspace library,
- programming asynchronously and interacting between applications with IPC,
- and communicating between boards using the OpenThread library running within a
  Tock process.

Tock is an operating system applicable to a broad set of application domains,
such as low-power and security-critical systems. We provide a broad set of
guides and documentation:

- This book: [https://book.tockos.org](https://book.tockos.org)
- Tock code documentation: [https://docs.tockos.org](https://docs.tockos.org)
- Reference documentation:
  [https://github.com/tock/tock/tree/master/doc](https://github.com/tock/tock/tree/master/doc)

We also provide some community resources, which you can find here:
[https://tockos.org/community/](https://tockos.org/community/)
