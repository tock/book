# Porting from `static mut` to `SingleThreadValue`

Starting in 2025 Tock is attempting to remove the use of `static mut` global
variables in Tock code. Correctly using `static mut` and avoiding unsound code
is very difficult. However, there are still valid uses of global mutable
variables, and Tock uses the
[`SingleThreadValue` type](https://docs.tockos.org/kernel/utilities/single_thread_value/struct.singlethreadvalue)
to enable safe global variables.

## How to Use `SingleThreadValue`

To enable safe shared global state, first define a static `SingleThreadValue`:

```rust
static FOO: SingleThreadValue<...> = SingleThreadValue::new(...);
```

The type parameter is the type of the global variable. For example storing
boolean flag. To enable mutability, use interior mutability. For example:

```rust
static FOO: SingleThreadValue<Cell<bool>> = SingleThreadValue::new(Cell::new(false));
```

To make the contained value accessible (in this case the `Cell<bool>`), the
`SingleThreadValue` must be _bound_ to a thread. This makes the contained value
safe to access. To do this, you need to provide an implementation of the
[`ThreadIdProvider` trait](https://docs.tockos.org/kernel/platform/chip/trait.threadidprovider).
This is commonly provided by the board's `Chip`. For many boards there is a
`ChipHw` type alias that is suitable, for example:

```rust
FOO.bind_to_thread::<<ChipHw as kernel::platform::chip::Chip>::ThreadIdProvider>();
```

This needs to be executed from the executing thread that will need to be able to
access the same state later. In single-core, single-thread CPUs there are
logically only two threads: the main execution and an interrupt context. In most
cases you will want to bind the `SingleThreadValue` to the main execution
thread.

From here, you can use the `SingleThreadValue` using the `.get()` method:

```rust
FOO.get().map(|value| {
    value.set(true);
});
```

## Porting Board `main.rs` Files

A major use case for global mutable variable is sharing state between the main
execution of the Tock kernel and the panic handler. Because panics are
asynchronous in nature, there is no intuitive method to pass state that would be
useful for a panic handler to the panic handler when it starts executing. The
workaround is to use a global variable.

Prior to `SingleThreadValue` these globals were typically defined as
`static mut` variables. With `SingleThreadValue`, we can now declare them as a
`static SingleThreadValue`.

To port from the prior `static mut` approach to the new `SingleThreadValue`
approach, follow these steps:

1. Add these imports to `main.rs`:

   ```rust
   use kernel::debug::PanicResources;
   use kernel::utilities::single_thread_value::SingleThreadValue;
   ```

2. Replace `static mut`s for process, chip, and panic printer in main.rs with
   this:

   ```rust
   /// Resources for when a board panics used by io.rs.
   static PANIC_RESOURCES: SingleThreadValue<PanicResources<ChipHw, ProcessPrinterInUse>> =
       SingleThreadValue::new(PanicResources::new());
   ```

3. If the board doesn't already have `type ChipHw`, add something like this near
   the top of main.rs:

   ```rust
   pub type ChipHw = nrf52840::chip::NRF52<'static, Nrf52840DefaultPeripherals<'static>>;
   ```

4. Add a type for `ProcessPrinterInUse`:

   ```rust
   type ProcessPrinterInUse = capsules_system::process_printer::ProcessPrinterText;
   ```

5. Near the start of `start()` add this:

   ```rust
   // Bind global variables to this thread.
   PANIC_RESOURCES.bind_to_thread::<<ChipHw as kernel::platform::chip::Chip>::ThreadIdProvider>();
   ```

6. Replace `PROCESSES = Some(processes);` with

   ```rust
   PANIC_RESOURCES.get().map(|resources| {
       resources.processes.put(processes.as_slice());
   });
   ```

7. Replace `CHIP = Some(chip);` with

   ```rust
   PANIC_RESOURCES.get().map(|resources| {
       resources.chip.put(chip);
   });
   ```

8. Replace `PROCESS_PRINTER = Some(process_printer);` with

   ```rust
   PANIC_RESOURCES.get().map(|resources| {
       resources.printer.put(process_printer);
   });
   ```

9. In io.rs, where `debug::panic(...)` is called, replace these arguments:

   ```rust
   PROCESSES.unwrap().as_slice(),
   &*addr_of!(CHIP),
   &*addr_of!(PROCESS_PRINTER),
   ```

   with:

   ```rust
   crate::PANIC_RESOURCES.get(),
   ```
