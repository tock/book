# Userspace Attacks on the Encryption Service

Now that the userspace application has been completed, we can attempt to perform
some attacks on it and demonstrate how Tock stops them.

The primary theme we'll see is that Tock takes a two-fold approach to security
though isolation; for everything above the syscall layer, isolation between apps
is guaranteed at runtime using hardware protection, whereas below the syscall
layer, isolation between components is guaranteed at compile-time via careful
use of Rust's type system. This allows for the flexibility of dynamically
loading applications while simultaneously providing the highest degree of
security for the kernel: if isolation is violated, the kernel simply won't
build.

In this submodule, we'll explore the runtime isolation between applications, and
in the next we'll dive into the kernel to see an example of compile-time
isolation in the kernel.

## Background

### Memory Protection in Embedded Systems

In non-embedded contexts, a CPU will usually have a memory management unit (MMU)
which handles all memory accesses to memory pages. Embedded contexts usually
don't provide enough memory to justify paging, so a much simpler piece of
hardware--the memory protection unit (MPU)--is used instead.

The MPU's sole job is to maintain a series of contiguous memory regions which
the processor should currently be allowed to access to provide hardware-level
runtime isolation guarantees. For instance, when an application is running, the
MPU typically allows the processor read-execute access to the `.text` section of
the application and read-write access to the corresponding section in SRAM. Each
context switch in Tock is paired with a reconfiguration of the MPU to ensure
that out-of-bounds accesses don't allow applications to access memory belonging
to the kernel or other applications.

## Submodule Overview

We have two small milestones in this section, one of which builds upon supplied
starter code for an application, and the other of which builds upon the board
definition we've been using for our kernel this whole time.

1. Milestone one adds an application which attempts to dump its own memory,
   followed by the memory of the encryption oracle application--we use this as
   an example of a potential userspace attack on a root of trust.
2. Milestone two customizes Tock's response to this attack at the board
   definition level.

## Setup

No additional setup is needed beyond the previous section.

## Starter Code

The code in `libtock-c/examples/tutorials/root_of_trust/` for `screen/` remains
the same, and starter code for the userspace attack application is in the
`suspicious_service/` subdirectory.

To launch this 'suspicious' service which we'll use to dump userspace memory,
simply navigate as per the previous submodule to the "Suspicious service" in the
on-device menu, select it, and then select "Start" as usual.

## Milestone One: Attempting to Dump Memory from SRAM

To start, we first need to set up our attack application to attempt to dump
memory from SRAM. If you get stuck, an implementation of this milestone is
available at `suspicious_service_milestone_one/`.

1. If you haven't yet, install the `suspicious_service` as previous using `make`
   then `tockloader install`.

2. Next, obtain the start addresses of our attack service and the encryption
   service we installed previously. To do this, we'll rebuild the kernel and add
   an additional feature. Under our board definition in
   `tock/boards/tutorials nrf52840dk-root-of-trust-tutorial/`, you'll want to
   make the following change so that the process load debugging is enabled for
   the kernel:

   ```
   --- a/boards/tutorials/nrf52840dk-root-of-trust-tutorial/Cargo.toml
   +++ b/boards/tutorials/nrf52840dk-root-of-trust-tutorial/Cargo.toml
   @@ -10,7 +10,7 @@ build = "../../build.rs"
    edition.workspace = true

    [features]
   -default = ["screen_ssd1306"]
   +default = ["screen_ssd1306", "kernel/debug_load_processes"]
    screen_ssd1306 = []
    screen_sh1106 = []
   ```

3. After making this change, run (in the same directory) `make` and
   `make install` so that the new kernel is uploaded. From there, press the
   "RESET" button on the board, and look at your `tockloader listen` console; it
   should show something like

   ```
   [INFO   ] Using "/dev/ttyACM0 - J-Link - CDC".
   [INFO   ] Listening for serial output.
   Initialization complete. Entering main loop
   NRF52 HW INFO: Variant: AAF0, Part: N52840, Package: QI, Ram: K256, Flash: K1024
   ...
   Loading: org.tockos.tutorials.attestation.encryption [1] flash=0x00048000-0x0004C000 ram=0x2000A000-0x2000BFFF
   ...
   No more processes to load: Could not find TBF header.
   ```

   These debug statements are from Tock's application loader. Reviewing the line
   starting with `Loading:`, we can clearly see that the SRAM range for the
   encryption service is `0x2000A000-0x2000BFFF`.

4. Now that we know where the applications SRAM ranges are, we can attempt to
   dump them. In `libtock-c/examples/tutorials/root_of_trust/`, rename the
   directory `suspicious_service_starter/` to just `suspicious_service/`.

5. Inside `suspicious_service/main.c`, we'll want to start by adding everything
   we needed from the previous step for interacting with the main screen
   application. Copy over `wait_for_start()`, `setup_logging()`, and
   `log_to_screen()` along with the IPC callbacks and global variables they rely
   upon from the previous submodule to `suspicious_serivce/main.c`.

6. Now, in `suspicious_service/main.c`, add a function `dump_memory()` that
   takes in a `uint32_t *start` word pointer, a `uint32_t *end` word pointer,
   and a label string, and loops over each address from start to end while
   printing out over UART e.g. `[<LABEL>] <address>: <value>` to show the value
   at each memory address.

7. In main, call `dump_memory()` to dump the first 16KiB (`0x1000` words of
   memory) of the "suspicious" SRAM dumping service you're modifying right now.

   To get the address that our SRAM dumping applications's memory starts at,
   Tock supplies a
   [`Memop`](https://book.tockos.org/trd/trd104-syscalls.html#46-memop-class-id-5)
   class of syscalls we can use, which are nicely wrapped in utility functions
   such as `tock_app_memory_begins_at()` in libtock-c.

   If desired, use `log_to_screen()` to log when the memory dump starts/stops.
   You should (when selecting the "Suspicious service" in the on-device menu)
   successfully be able to retrieve the bytes of code of the running SRAM
   dumping service.

8. After that, try adding another `dump_memory()` call to dump the first
   `0x1000` words of the encryption application. Because applications should
   never need to access each other's memory, you'll need to get this address
   from the debug output you collected in step 3. Once you've done this, your
   code should compile fine, but when you check the `tockloader listen` UART
   console, you should see a fault dump.

With any luck, the fault dump you receive should look something like this:

```
...
---| Cortex-M Fault Status |---
Data Access Violation:              true
Forced Hard Fault:                  true
Faulting Memory Address:            0x2000A000
...

𝐀𝐩𝐩: org.tockos.tutorials.attestation.suspicious   -   [Faulted]
 Events Queued: 0   Syscall Count: 4118   Dropped Upcall Count: 0
 Restart Count: 0
 Last Syscall: Yield { which: 1, param_a: 0, param_b: 0 }
 Completion Code: None


 ╔═══════════╤══════════════════════════════════════════╗
 ║  Address  │ Region Name    Used | Allocated (bytes)  ║
 ╚0x2000E000═╪══════════════════════════════════════════╝
             │ Grant Ptrs      120
             │ Upcalls         320
             │ Process         768
  0x2000DB48 ┼───────────────────────────────────────────
             │ ▼ Grant         216
  0x2000DA70 ┼───────────────────────────────────────────
             │ Unused
  0x2000CF3C ┼───────────────────────────────────────────
             │ ▲ Heap         1468 |   4336               S
  0x2000C980 ┼─────────────────────────────────────────── R
             │ Data            384 |    384               A
  0x2000C800 ┼─────────────────────────────────────────── M
             │ ▼ Stack         416 |   2048
  0x2000C660 ┼───────────────────────────────────────────
             │ Unused
  0x2000C000 ┴───────────────────────────────────────────
             .....
  0x00050000 ┬─────────────────────────────────────────── F
             │ App Flash     16272                        L
  0x0004C070 ┼─────────────────────────────────────────── A
             │ Protected       112                        S
  0x0004C000 ┴─────────────────────────────────────────── H

...
```

Indeed, when we tried to access the first address from the encryption service's
SRAM, the nRF52840's MPU triggered a hard fault, which passed control to Tock's
hard fault handler and allowed Tock to halt the application.

If we look even further down the debug dump, we can actually even see the MPU
configuration Tock set up at the time of the fault:

```
 Cortex-M MPU
  Region 0: [0x2000C000:0x2000D000], length: 4096 bytes; ReadWrite (0x3)
    Sub-region 0: [0x2000C000:0x2000C200], Enabled
    Sub-region 1: [0x2000C200:0x2000C400], Enabled
    Sub-region 2: [0x2000C400:0x2000C600], Enabled
    Sub-region 3: [0x2000C600:0x2000C800], Enabled
    Sub-region 4: [0x2000C800:0x2000CA00], Enabled
    Sub-region 5: [0x2000CA00:0x2000CC00], Enabled
    Sub-region 6: [0x2000CC00:0x2000CE00], Enabled
    Sub-region 7: [0x2000CE00:0x2000D000], Enabled
  Region 1: Unused
  Region 2: [0x0004C000:0x00050000], length: 16384 bytes; UnprivilegedReadOnly (0x2)
    Sub-region 0: [0x0004C000:0x0004C800], Enabled
    Sub-region 1: [0x0004C800:0x0004D000], Enabled
    Sub-region 2: [0x0004D000:0x0004D800], Enabled
    Sub-region 3: [0x0004D800:0x0004E000], Enabled
    Sub-region 4: [0x0004E000:0x0004E800], Enabled
    Sub-region 5: [0x0004E800:0x0004F000], Enabled
    Sub-region 6: [0x0004F000:0x0004F800], Enabled
    Sub-region 7: [0x0004F800:0x00050000], Enabled
  Region 3: Unused
  Region 4: Unused
  Region 5: Unused
  Region 6: Unused
  Region 7: Unused
```

This indicates that our application had read-write access to the range
`0x2000C000 - 0x2000D000` (the SRAM dump application's allotted SRAM) and
read-only access to the range `0x0004F800 - 0x00050000` (the SRAM dump
application's code) but that an attempted access to any other region of memory
would result in a hard fault, as we just saw. As such, even when the kernel is
configured to accept arbitrary applications, runtime application isolation can
be enforced.

## Milestone Two: Modifying our Kernel's Fault Policy

When a system faults, it can be very useful to dump as much information as
possible to the console to aid in debugging. In some secure production contexts
though, it might be useful to keep dumped information on system state to a
minimum. As an example of this in Tock, we will modify the kernel's application
fault policy to provide less information while still alerting the user that an
application has faulted, keeping the more potentially sensitive details like MPU
configurations for e.g. protected logs.

To start, we'll need to open up our board definition in Tock:

1. Open `tock/boards/tutorials/nrf52840dk-root-of-trust-tutorial/main.rs`, and
   note where it says

   ```
   const FAULT_RESPONSE: capsules_system::process_policies::PanicFaultPolicy =
       capsules_system::process_policies::PanicFaultPolicy {};
   ```

   This is the part of the board configuration file that indicates how the Tock
   kernel should respond to an application faulting. The `PanicFaultPolicy`
   simply causes the whole system to panic upon an application faulting; while
   this is helpful for debugging, it does allow malicious applications to deny
   service in production and can reveal information regarding MPU configuration
   that might be best kept to device logs.

2. To implement our own fault policy, we'll add a new Rust `struct` which
   represents our policy: above the line displayed above, add a line

   ```
   struct LogThenStopFaultPolicy {}
   ```

3. Next, we'll want to define how our policy works when a fault happens. To do
   this, we'll add an implementation for a Rust _trait_ `ProcessFaultPolicy`
   which requires us to add an `action()` method that the kernel can call whan a
   running app faults.

   ```
   impl kernel::process::ProcessFaultPolicy for LogThenStopFaultPolicy {
       fn action(&self, process: &dyn process::Process) -> process::FaultAction {
           kernel::debug!(
               "CRITICAL: process {} encountered a fault!",
               process.get_process_name()
           );

           match process.get_credential() {
               Some(c) => kernel::debug!("Credentials checked for app: {:?}", c.credential),
               None => kernel::debug!("WARNING: no credentials verified for faulted app!"),
           }

           kernel::debug!("Process has been stopped. Review logs.");

           process::FaultAction::Stop
       }
   }
   ```

   This now just indicates which process faulted, indicates the credentials
   (i.e. a code signing signature) that the application was loaded with, and
   then instructs the user to check the HWRoT logs.

4. Finally, to register this as the fault response we want, replace the previous
   line starting with `const FAULT_RESPONSE: ...` with one that defines
   `FAULT_RESPONSE` as an instance of our new `LogThenStopFaultPolicy`:

   ```
   const FAULT_RESPONSE: LogThenStopFaultPolicy = LogThenStopFaultPolicy {};
   ```

5. Finally, run `make` and then `make install` in our
   `tock/boards/tutorials/nrf52840dk-root-of-trust-tutorial/` directory.

Now, when you run the suspicious SRAM dump service, you should see something
like the following:

```
CRITICAL: process org.tockos.tutorials.attestation.suspicious encountered a fault!
WARNING: no credentials verified for faulted app!
Process has been stopped. Review logs.
```

Out of the box, Tock was able to provide runtime application isolation between
our encryption service and a malicious SRAM dumping application, and in just a
few lines of code, we were able to customize our kernel's response to
application faults to match our production HWRoT use caes.

In the next submodule, we'll explore one aspect of Tock's compile-time
kernel-level isolation guarantees: _capabilities_.
