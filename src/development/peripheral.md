# Implementing a Chip Peripheral Driver

This guide covers how to implement a peripheral driver for a particular
microcontroller (MCU). For example, if you wanted to add an analog to digital
converter (ADC) driver for the Nordic nRF52840 MCU, you would follow the general
steps described in this guide.

## Overview

The general steps you will follow are:

1. Determine the HIL you will implement.
2. Create a register mapping for the peripheral.
3. Create a struct for the peripheral.
4. Implement the HIL interface for the peripheral.
5. Create the peripheral driver object and cast the registers to the correct
   memory location.

The guide will walk through how to do each of these steps.


## Background

Implementing a chip peripheral driver increases Tock's support for a particular
microcontroller and allows capsules and userspace apps to take more advantage of
the hardware provided by the MCU. Peripheral drivers for an MCU are generally
implemented on an as-needed basis to support a particular use case, and as such
the chips in Tock generally do not have all of the peripheral drivers
implemented already.

Peripheral drivers are included in Tock as "trusted code" in the kernel. This
means that they can use the `unsafe` keyword (in fact, they must). However, it
also means more care must be taken to ensure they are correct. The use of
`unsafe` should be kept to an absolute minimum and only used where absolutely
necessary. This guide explains the one use of `unsafe` that is required. All
other uses of `unsafe` in a peripheral driver will likely be very scrutinized
during the pull request review period.


## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Determine the HIL you will implement.**

    The HILs in Tock are the contract between the MCU-specific hardware and the
    more generic capsules which use the hardware resources. They provide a
    common interface that is consistent between different microcontrollers,
    enabling code higher in the stack to use the interfaces without needing to
    know any details about the underlying hardware. This common interface also
    allows the same higher-level code to be portable across different
    microcontrollers. HILs are implemented as
    [traits](https://doc.rust-lang.org/1.8.0/book/traits.html) in Rust.

    All HILs are defined in the `kernel/src/hil` directory. You should find a
    HIL that exposes the interface the peripheral you are writing a driver for
    can provide. There should only be one HIL that matches your peripheral.

    > Note: As of Dec 2019, the `hil` directory also contains interfaces that
    > are only provided by capsules for other capsules. For example, the ambient
    > light HIL interface is likely not something an MCU would implement.

    It is possible Tock does not currently include a HIL that matches the
    peripheral you are implementing a driver for. In that case you will also
    need to create a HIL, which is explained in a different development guide.

    **Checkpoint**: You have identified the HIL your driver will implement.


2. **Create a register mapping for the peripheral.**

    To start implementing the peripheral driver, you must create a new source
    file within the MCU-specific directory inside of `chips/src` directory. The
    name of this file generally should match the name of the peripheral in the
    the MCU's datasheet.

    Include the name of this file inside of the `lib.rs` (or potentially
    `mod.rs`) file inside the same directory. This should look like:

    ```rust
    pub mod ast;
    ```

    Inside of the new file, you will first need to define the memory-mapped
    input/output (MMIO) registers that correspond to the peripheral. Different
    embedded code ecosystems have devised different methods for doing this, and
    Tock is no different. Tock has a special library and set of Rust macros to
    make defining the register map straightforward and using the registers
    intuitive.

    The full register library is
    [here](https://github.com/tock/tock/tree/master/libraries/tock-register-interface),
    but to get started, you will first create a structure like this:

    ```rust
    use tock_registers::registers::{ReadOnly, ReadWrite, WriteOnly};

    register_structs! {
        XyzPeripheralRegisters {
            /// Control register.
            /// The 'Control' parameter constrains this register to only use
            /// fields from a certain group (defined below in the bitfields
            /// section).
            (0x000 => cr: ReadWrite<u32, Control::Register>),
            // Status register.
            (0x004 => s: ReadOnly<u8, Status::Register>),
            /// spacing between registers in memory
            (0x008 => _reserved),
            /// Another register with no meaningful fields.
            (0x014 => word: ReadWrite<u32>),

            // Etc.

            // The end of the struct is marked as follows.
            (0x100 => @END),
        }
    }
    ```

    You should replace `XyzPeripheral` with the name of the peripheral you are
    writing a driver for. Then, for each register defined in the datasheet, you
    must specify an entry in the macro. For example, a register is defined like:

    ```rust
    (0x000 => cr: ReadWrite<u32, Control::Register>),
    ```

    where:
    - `0x000` is the offset (in bytes) of the register from the beginning of the
      register map.
    - `cr` is the name of the register in the datasheet.
    - `ReadWrite` is the access control of the register as defined in the
      datasheet.
    - `u32` is the size of the register.
    - `Control::Register` maps to the actual bitfields used in the register. You
      will create this type for this particular peripheral, so you can name this
      whatever makes sense at this point. Note that it will always end with
      `::Register` due to how Rust macros work. If it doesn't make sense to
      define the specific bitfields in this register, you can omit this field.
      For example, an esoteric field in the register map that the implementation
      does not use likely does not need its bitfields mapped.

    Once the register map is defined, you must specify the bitfields for any
    registers that you gave a specific type to. This looks like the following:

    ```rust
    register_bitfields! [
        // First parameter is the register width for the bitfields. Can be u8,
        // u16, u32, or u64.
        u32,

        // Each subsequent parameter is a register abbreviation, its descriptive
        // name, and its associated bitfields. The descriptive name defines this
        // 'group' of bitfields. Only registers defined as
        // ReadWrite<_, Control::Register> can use these bitfields.
        Control [
            // Bitfields are defined as:
            // name OFFSET(shift) NUMBITS(num) [ /* optional values */ ]

            // This is a two-bit field which includes bits 4 and 5
            RANGE OFFSET(4) NUMBITS(3) [
                // Each of these defines a name for a value that the bitfield
                // can be written with or matched against. Note that this set is
                // not exclusive--the field can still be written with arbitrary
                // constants.
                VeryHigh = 0,
                High = 1,
                Low = 2
            ],

            // A common case is single-bit bitfields, which usually just mean
            // 'enable' or 'disable' something.
            EN  OFFSET(3) NUMBITS(1) [],
            INT OFFSET(2) NUMBITS(1) []
        ],

        // Another example:
        // Status register
        Status [
            TXCOMPLETE  OFFSET(0) NUMBITS(1) [],
            TXINTERRUPT OFFSET(1) NUMBITS(1) [],
            RXCOMPLETE  OFFSET(2) NUMBITS(1) [],
            RXINTERRUPT OFFSET(3) NUMBITS(1) [],
            MODE        OFFSET(4) NUMBITS(3) [
                FullDuplex = 0,
                HalfDuplex = 1,
                Loopback = 2,
                Disabled = 3
            ],
            ERRORCOUNT OFFSET(6) NUMBITS(3) []
        ],
    ]
    ```

    The name in each entry of the `register_bitfields! []` list must match the
    register type provided in the register map declaration. Each register that
    is used in the driver implementation should have its bitfields declared.

    **Checkpoint**: The register map is correctly described in the driver source
    file.

3. **Create a struct for the peripheral.**

    Each peripheral driver is implemented with a struct which is later used to
    create an object that can be passed to code that will use this peripheral
    driver. The actual fields of the struct are very peripheral specific, but
    should contain any state that the driver needs to correctly function.

    An example struct looks for a timer peripheral called the AST by the MCU
    datasheet looks like:

    ```rust
    pub struct Ast<'a> {
        registers: StaticRef<AstRegisters>,
        callback: OptionalCell<&'a dyn hil::time::AlarmClient>,
    }
    ```

    The struct should contain a reference to the registers defined above (we
    will explain the `StaticRef` later). Typically, many drivers respond to
    certain events (like in this case a timer firing) and therefore need a
    reference to a client to notify when that event occurs. Notice that the type
    of the callback handler is specified in the HIL interface.

    Peripheral structs typically need a lifetime for references like the
    callback client reference. By convention Tock peripheral structs use `'a`
    for this lifetime, and you likely want to copy that as well.

    Think of what state your driver might need to keep around. This could
    include a direct memory access (DMA) reference, some configuration flags
    like the baud rate, or buffer indices. See other Tock peripheral drivers for
    more examples.

    > Note: you will most likely need to update this struct as you implement the
    > driver, so to start with this just has to be a best guess.

    > Hint: you should avoid keeping any state in the peripheral driver struct
    > that is already stored by the hardware itself. For example, if there is an
    > "enabled" bit in a register, then you do not need an "enabled" flag in the
    > struct. Replicating this state leads to bugs when those values get out of
    > sync, and makes it difficult to update the driver in the future.

    Peripheral driver structs make extensive use of different "cell" types to
    hold references to various shared state. The general wisdom is that if the
    value will ever need to be updated, then it needs to be contained in a cell.
    See the Tock cell documentation for more details on the cell types and when
    to use which one. In this example, the callback is stored in an
    `OptionalCell`, which can contain a value or not (if the callback is not
    set), and can be updated if the callback needs to change.

    With the struct defined, you should next create a `new()` function for that
    struct. This will look like:

    ```rust
    impl Ast {
        const fn new(registers: StaticRef<AstRegisters>) -> Ast {
            Ast {
                registers: registers,
                callback: OptionalCell::empty(),
            }
        }
    }
    ```

    **Checkpoint**: There is a struct for the peripheral that can be created.


4. **Implement the HIL interface for the peripheral.**

    With the peripheral driver struct created, now the main work begins. You can
    now write the actual logic for the peripheral driver that implements the HIL
    interface you identified earlier. Implementing the HIL interface is done
    just like implementing a trait in Rust. For example, to implement the `Time`
    HIL for the AST:

    ```rust
    impl hil::time::Time for Ast<'a> {
        type Frequency = Freq16KHz;

        fn now(&self) -> u32 {
            self.get_counter()
        }

        fn max_tics(&self) -> u32 {
            core::u32::MAX
        }
    }
    ```

    You should include all of the functions from the HIL and decide how to
    implement them.

    Some operations will be shared among multiple HIL functions. These should be
    implemented as functions for the original struct. For example, in the `Ast`
    example the HIL function `now()` uses the `get_counter()` function. This should be
    implemented on the main `Ast` struct:

    ```rust
    impl Ast {
        const fn new(registers: StaticRef<AstRegisters>) -> Ast {
            Ast {
                registers: registers,
                callback: OptionalCell::empty(),
            }
        }

        fn get_counter(&self) -> u32 {
            let regs = &*self.registers;
            while self.busy() {}
            regs.cv.read(Value::VALUE)
        }
    }
    ```

    Note the `get_counter()` function also illustrates how to use the register
    reference and the Tock register library. The [register
    library](https://github.com/tock/tock/tree/master/libraries/tock-register-interface)
    includes much more detail on the various register operations enabled by the
    library.

    **Checkpoint**: All of the functions in the HIL interface have MCU
    peripheral-specific implementations.


5. **Create the peripheral driver object and cast the registers to the correct
   memory location.**

    The last step is to actually create the object so that the peripheral driver
    can be used by other code. Start by casting the register map to the correct
    memory address where the registers are actually mapped to. For example:

    ```rust
    use kernel::common::StaticRef;

    const AST_BASE: StaticRef<AstRegisters> =
        unsafe { StaticRef::new(0x400F0800 as *const AstRegisters) };
    ```

    `StaticRef` is a type in Tock designed explicitly for this operation of
    casting register maps to the correct location in memory. The `0x400F0800` is
    the address in memory of the start of the registers and this location will
    be specified by the datasheet.

    > Note that creating the `StaticRef` requires using the `unsafe` keyword.
    > This is because doing this cast is a fundamentally memory-unsafe
    > operation: this allows whatever is at that address in memory to be
    > accessed through the register interface (which is exposed as a safe
    > interface). In the normal case where the correct memory address is
    > provided there is no concern for system safety as the register interface
    > faithfully represents the underlying hardware. However, suppose an
    > incorrect address was used, and that address actually points to live
    > memory used by the Tock kernel. Now kernel data structures could be
    > altered through the register interface, and this would violate memory
    > safety.

    With the address reference created, we can now create the actual driver
    object:

    ```rust
    pub static mut AST: Ast = Ast::new(AST_BASE);
    ```

    This object will be used by a board's main.rs file to pass, in this case,
    the driver for the timer hardware to various capsules and other code that
    needs the underlying timer hardware.


## Wrap-Up

Congratulations! You have implemented a peripheral driver for a microcontroller
in Tock! We encourage you to submit a pull request to upstream this to the Tock
repository.
