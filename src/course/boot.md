# Kernel Boot and Setup

The goal of this module is to make you comfortable with the Tock kernel, how it
is structured, how the kernel is setup at boot, and how capsules provide
additional kernel functionality.

During this you will:

1. Learn how Tock uses Rust's memory safety to provide isolation for free
2. Read the Tock boot sequence, seeing how Tock uses static allocation
3. Learn about Tock's event-driven programming

## The Tock Boot Sequence

The _very_ first thing that runs on a Tock board is an assembly function called
`initialize_ram_jump_to_main()`. Rust requires that memory is configured before
any Rust code executes, so this must run first. As the function name implies,
control is then transferred to the `main()` function in the board's `main.rs`
file. Tock intentionally tries to give the board as much control over the
operation of the system as possible, hence why there is very little between
reset and the board's main function being called.

Open the `main.rs` file for your board in your favorite editor. This file
defines the board's platform: how it boots, what capsules it uses, and what
system calls it supports for userland applications.

### How is everything organized?

Find the declaration of "platform" `struct`. This is typically called
`struct Platform` or named based on the name of the board (it's pretty early in
the file). This declares the structure representing the platform. It has many
fields, many of which are capsules that make up the board's platform. These
fields are resources that the board needs to maintain a reference to for future
use, for example for handling system calls or implementing kernel policies.

Recall that everything in the kernel is statically allocated. We can see that
here. Every field in the platform `struct` is a reference to an object with a
static lifetime.

Many capsules themselves take a lifetime as a parameter, which is currently
always `'static`.

The boot process is primarily the construction of this platform structure. Once
everything is set up, the board will pass the constructed platform object to
`kernel::kernel_loop` and we're off to the races.

### How do things get started?

After RAM initialization, the reset handler invokes the `main()` function in the
board main.rs file. `main()` is typically rather long as it must setup and
configure all of the drivers and capsules the board needs. Many capsules depend
on other, lower layer abstractions that need to be created and initialized as
well.

Take a look at the first few lines of `main()`. The boot sequence generally sets
up any low-level microcontroller configuration, initializes the MCU peripherals,
and sets up debugging capabilities.

### How do capsules get created?

The bulk of `main()` create and initializes capsules which provide the main
functionality of the Tock system. For example, to provide userspace applications
with ability to display serial data, boards typically create a `console`
capsule. An example of this looks like:

```rust

pub unsafe fn main() {
    ...

    // Create a virtualizer on top of an underlying UART device. Use 115200 as
    // the baud rate.
    let uart_mux = components::console::UartMuxComponent::new(channel, 115200)
        .finalize(components::uart_mux_component_static!());

    // Instantiate the console capsule. This uses the virtualized UART provided
    // by the uart_mux.
    let console = components::console::ConsoleComponent::new(
        board_kernel,
        capsules_core::console::DRIVER_NUM,
        uart_mux,
    )
    .finalize(components::console_component_static!());

    ...
}
```

Eventually, once all of the capsules have been created, we will populate the
platform structure with them:

```rust
pub unsafe fn main() {
    ...

    let platform = Platform {
        console: console,
        gpio: gpio,
        ...
    }

}
```

#### What Are Components?

When setting up the capsules (such as `console`), we used objects in the
`components` crate to help. In Tock, components are helper objects that make it
easier to correctly create and initialize capsules.

For example, if we look under the hood of the `console` component, the main
initialization of console looks like:

```rust
impl Component for ConsoleComponent {
    fn finalize(self, s: Self::StaticInput) -> Console {
        let grant_cap = create_capability!(capabilities::MemoryAllocationCapability);

        let write_buffer = static_init!([u8; DEFAULT_BUF_SIZE], [0; DEFAULT_BUF_SIZE]);
        let read_buffer = static_init!([u8; DEFAULT_BUF_SIZE], [0; DEFAULT_BUF_SIZE]);

        let console_uart = static_init!(
            UartDevice,
            UartDevice::new(self.uart_mux, true)
        );
        // Don't forget to call setup() to register our new UartDevice with the
        // mux!
        console_uart.setup();

        let console = static_init!(
            Console<'static>,
            console::Console::new(
                console_uart,
                write_buffer,
                read_buffer,
                self.board_kernel.create_grant(self.driver_num, &grant_cap),
            )
        );
        // Very easy to figure to set the client reference for callbacks!
        hil::uart::Transmit::set_transmit_client(console_uart, console);
        hil::uart::Receive::set_receive_client(console_uart, console);

        console
    }
}
```

Much of the code within components is boilerplate that is copied for each board
and easy to subtlety miss an important setup step. Components encapsulate the
setup complexity and can be reused on each board Tock supports.

The `static_init!` macro is simply an easy way to allocate a static variable
with a call to `new`. The first parameter is the type, the second is the
expression to produce an instance of the type.

Components end up looking somewhat complex because they can be re-used across
multiple boards and different microcontrollers. More detail
[here](https://github.com/tock/tock/blob/master/kernel/src/component.rs).

> #### A brief aside on buffers:
>
> Notice that the console needs both a read and write buffer for it to use.
> These buffers have to have a `'static` lifetime. This is because low-level
> hardware drivers, especially those that use DMA, require `'static` buffers.
> Since we don't know exactly when the underlying operation will complete, and
> we must promise that the buffer outlives the operation, we use the one
> lifetime that is assured to be alive at the end of an operation: `'static`.
> Other code with buffers without a `'static` lifetime, such as userspace
> processes, use capsules like `Console` by copying data into internal `'static`
> buffers before passing them to the console. The buffer passing architecture
> looks like this:
>
> ![Console/UART buffer lifetimes](../imgs/console.svg)

### Let's Make a Tock Board!

The code continues on, creating all of the other capsules that are needed by the
platform. Towards the end of `main()`, we've created all of the capsules we
need, and it's time to create the actual platform structure
(`let platform = Platform {...}`).

Boards must implement two traits to successfully run the Tock kernel:
`SyscallDriverLookup` and `KernelResources`.

#### `SyscallDriverLookup`

The first, `SyscallDriverLookup`, is how the kernel maps system calls from
userspace to the correct capsule within the kernel. The trait requires one
function:

```rust
trait SyscallDriverLookup {
    /// Mapping of syscall numbers to capsules.
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn SyscallDriver>) -> R;
}
```

The `with_driver()` function executes the provided function `f()` by passing it
the correct capsule based on the provided `driver_num`. A brief example of an
implementation of `SyscallDriverLookup` looks like:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
            capsules_core::console::DRIVER_NUM => f(Some(self.console)),
            capsules_core::gpio::DRIVER_NUM => f(Some(self.gpio)),
            ...
            _ => f(None),
        }
    }
}
```

Why require each board to provide this mapping? Why not implement this mapping
centrally in the kernel? Tock requires boards to implement this mapping as we
consider the assignment of driver numbers to specific capsules as a
platform-specific decisions. While Tock does have a default mapping of driver
numbers, boards are not obligated to use them. This flexibility allows boards to
expose multiple copies of the same capsule to userspace, for example.

#### `KernelResources`

The `KernelResources` trait is the main method for configuring the operation of
the core Tock kernel. Policies such as the syscall mapping described above,
syscall filtering, and watchdog timers are configured through this trait. More
information is contained in a separate course module.

### Loading processes

Once the platform is all set up, the board is responsible for loading processes
into memory:

```rust
pub unsafe fn main() {
    ...

    kernel::process::load_processes(
        board_kernel,
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

    ...
}
```

A Tock process is represented by a `kernel::Process` struct. In principle, a
platform could load processes by any means. In practice, all existing platforms
write an array of Tock Binary Format (TBF) entries to flash. The kernel provides
the `load_processes` helper function that takes in a flash address and begins
iteratively parsing TBF entries and making `Process`es.

> #### A brief aside on capabilities:
>
> To call `load_processes()`, the board had to provide a reference to a
> `&process_management_capability`. The `load_processes()` function internally
> requires significant direct access to memory, and it should only be called in
> very specific places. To prevent its misuse (for example from within a
> capsule), calling it requires a capability to be passed in with the arguments.
> To create a capability, the calling code must be able to call `unsafe`, Code
> (i.e. capsules) which cannot use `unsafe` therefore has no way to create a
> capability and therefore cannot call the restricted function.

### Starting the kernel

Finally, the board passes a reference to the current platform, the chip the
platform is built on (used for interrupt and power handling), and optionally an
IPC capsule to start the main kernel loop:

```rust
board_kernel.kernel_loop(&platform, chip, Some(&platform.ipc), &main_loop_capability);

```

From here, Tock is initialized, the kernel event loop takes over, and the system
enters steady state operation.
