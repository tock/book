# Implementing an in-kernel Virtualization Layer

This guide provides an overview and walkthrough on how to add an in-kernel virtualization
layer, such that a given hardware interface can be used simultaneously by multiple
kernel capsules, or used simultaneously by a single kernel capsule and userspace.
Ideally, virtual interfaces will be available for all hardware interfaces in Tock. 
Some example interfaces which have already been virtualized include Alarm, SPI, Flash,
UART, I2C, ADC, and others.

In this guide we will use a running example of virtualizing a single hardware SPI peripheral
and bus for use as a SPI Master.

## Setup

This guide assumes you already have existing kernel code that needs to be virtualized.
There should be an existing HIL for the resource you are virtualizing.

We will assume there is a `trait SpiMaster {...}` already defined and implemented
that includes all of the logic needed to interface with the underlying SPI.
We also assume there is a `trait SpiMasterClient` that determines the interface a client
of the SPI exposes to the underlying resource. In most cases, equivalent traits will
represent a necessary precursor to virtualization.

## Overview

The high-level steps required are:

1. Create a capsule file for your virtualizer
2. Determine what portions of this interface should be virtualized.
3. Create a `MuxXXX` struct, which will serve as the lone client of the underlying resource.
4. Create a `VirtualXXXDevice` which will implement the underlying HIL trait, allowing for the appearance
   of multiple of the lone resource.
5. Implement the logic for queuing requests from capsules.
6. Implement the logic for dispatching callbacks from the underlying resource to the appropriate client.
7. Document the interface.
8. (Optional) Write tests for the virtualization logic.

![](../imgs/virtual.svg)

## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Create a capsule file for your virtualizer**

    This step is easy. Navigate to the `capsules/src/` directory and create a new file
    named `virtual_xxx`, where `xxx` is the name of the underlying resource being virtualized.
    All of the code you will write while following this guide belongs in that file.
    Additionally, open `capsules/src/lib.rs` and add `pub mod virtual_xxx;` to the list
    of modules.

2. **Determine what portions of this interface should be virtualized**

    Generally, this step requires looking at the HIL being virtualized, and
    determining what portions of the HIL require additional logic to handle
    multiple concurrent clients. Lets take a look at the SPIMaster HIL:

    ```rust
    pub trait SpiMaster {
        fn set_client(&self, client: &'static dyn SpiMasterClient);

        fn init(&self);
        fn is_busy(&self) -> bool;

        /// Perform an asynchronous read/write operation, whose
        /// completion is signaled by invoking SpiMasterClient on
        /// the initialized client.
        fn read_write_bytes(
            &self,
            write_buffer: &'static mut [u8],
            read_buffer: Option<&'static mut [u8]>,
            len: usize,
        ) -> ReturnCode;
        fn write_byte(&self, val: u8);
        fn read_byte(&self) -> u8;
        fn read_write_byte(&self, val: u8) -> u8;

        /// Tell the SPI peripheral what to use as a chip select pin.
        fn specify_chip_select(&self, cs: Self::ChipSelect);

        /// Returns the actual rate set
        fn set_rate(&self, rate: u32) -> u32;
        fn get_rate(&self) -> u32;
        fn set_clock(&self, polarity: ClockPolarity);
        fn get_clock(&self) -> ClockPolarity;
        fn set_phase(&self, phase: ClockPhase);
        fn get_phase(&self) -> ClockPhase;

        // These two functions determine what happens to the chip
        // select line between transfers. If hold_low() is called,
        // then the chip select line is held low after transfers
        // complete. If release_low() is called, then the chip select
        // line is brought high after a transfer completes. A "transfer"
        // is any of the read/read_write calls. These functions
        // allow an application to manually control when the
        // CS line is high or low, such that it can issue multi-byte
        // requests with single byte operations.
        fn hold_low(&self);
        fn release_low(&self);
    }
    ```

    For some of these functions, it is clear that no virtualization is required.
    For example, `get_rate()`, `get_phase()` and `get_polarity()` simply request
    information on the current configuration of the underlying hardware. Implementations
    of these can simply pass the call straight through the mux.

    Some other functions are not appropriate to expose to virtual clients at all.
    For example, `hold_low()`, `release_low()`, and `specify_chip_select()` are
    not suitable for use when the underlying bus is shared. `init()` does not make sense
    when it is unclear which client should call it. The mux should queue operations,
    so clients should not need access to `is_busy()`.

    For other functions, it is clear that virtualization *is* necessary. For example,
    it is clear that if multiple clients are using the Mux, they cannot all be allowed
    set the rate of the underlying hardware at arbitrary times, as doing so could
    break an ongoing operation initiated by an underlying client. However, it is
    important to expose this functionality to clients. Thus `set_rate()`, `set_clock()`
    and `set_phase()` need to be virtualized, and provided to virtual clients.
    `set_client()` needs to be adapted to support multiple simultaneous clients.

    Finally, virtual clients need a way to send and receive on the bus. Singly byte
    writes and reads are typically only used under the assumption that a single client
    is going to make multiple single byte reads/writes consecutively, and thus are inappropriate to
    virtualize. Instead, the virtual interface should only include `read_write_bytes()`,
    as that encapsulates the entire transaction that would be desired by a virtual client.

    Given that not all parts of the original HIL trait (`SpiMaster`) are appropriate for
    virtualization, we should create a new trait in the SPI HIL that will represent the
    interface provided to clients of the Virtual SPI:

    ```rust
    //! kernel/src/hil/spi.rs
    ...
    /// SPIMasterDevice provides a chip-specific interface to the SPI Master
    /// hardware. The interface wraps the chip select line so that chip drivers
    /// cannot communicate with different SPI devices.
    pub trait SpiMasterDevice {
        /// Perform an asynchronous read/write operation, whose
        /// completion is signaled by invoking SpiMasterClient.read_write_done on
        /// the provided client.
        fn read_write_bytes(
            &self,
            write_buffer: &'static mut [u8],
            read_buffer: Option<&'static mut [u8]>,
            len: usize,
        ) -> ReturnCode;

        /// Helper function to set polarity, clock phase, and rate all at once.
        fn configure(&self, cpol: ClockPolarity, cpal: ClockPhase, rate: u32);
        fn set_polarity(&self, cpol: ClockPolarity);
        fn set_phase(&self, cpal: ClockPhase);
        fn set_rate(&self, rate: u32);

        fn get_polarity(&self) -> ClockPolarity;
        fn get_phase(&self) -> ClockPhase;
        fn get_rate(&self) -> u32;
    }
    ```

    Not all virtualizers will require a new trait to provide virtualization! For example,
    `VirtualMuxDigest` exposes the same `Digest` HIL as the underlying hardware. Same for
    `VirtualAlarm`, `VirtualUart`, and `MuxFlash`. `VirtualI2C` does use a different trait, similarly
    to SPI, and `VirtualADC` introduces an `AdcChannel` trait to enable virtualization that
    is not possible with the ADC interface implemented by hardware.

    There is no fixed algorithm for deciding exactly how to virtualize a given interface,
    and doing so will require thinking carefully about the requirements of the clients and
    nature of the underlying resource. Tock's [threat model](https://github.com/tock/tock/tree/master/doc/threat_model)
    describes several requirements for virtualizers in its [virtualization section](https://github.com/tock/tock/blob/master/doc/threat_model/Virtualization.md).

    > Note: You should read these requirements!! They discuss things
    > like the confidentiality and fairness requirements for virtualizers.

    Beyond the threat model, you should think carefully about how virtual clients will use
    the interface, the overhead (in cycles / code size / RAM use) of different approaches,
    and how the interface will work in the face of multiple concurrent requests. It is also
    important to consider the potential for two layers of virtualization, when one of the
    clients of the virtualization capsule is a userspace driver that will also be virtualizing
    that same resource. In some cases (see: UDP port reservations) special casing the userspace
    driver may be valuable.

    Frequently the best approach will involve looking for an already virtualized resource that
    is qualitatively similar to the resource you are working with, and using its virtualization
    as a template.

3. **Create a `MuxXXX` struct, which will serve as the lone client of the underlying resource.**

    In order to virtualize a hardware resource, we need to create some object that has
    a reference to the underlying hardware resource and that will hold the multiple "virtual"
    devices which clients will interact with. For the SPI interface, we call this struct
    `MuxSpiMaster`:

    ```rust
    /// The Mux struct manages multiple Spi clients. Each client may have
    /// at most one outstanding Spi request.
    pub struct MuxSpiMaster<'a, Spi: hil::spi::SpiMaster> {
        // The underlying resource being virtualized
        spi: &'a Spi,

        // A list of virtual devices which clients will interact with.
        // (See next step for details)
        devices: List<'a, VirtualSpiMasterDevice<'a, Spi>>,

        // Additional data storage needed to implement virtualization logic
        inflight: OptionalCell<&'a VirtualSpiMasterDevice<'a, Spi>>,
    }
    ```

    Here we use Tock's built-in `List` type, which is a LinkedList of statically
    allocated structures that implement a given trait. This type is required because
    Tock does not allow heap allocation in the Kernel.

    Typically, this struct will implement some number of private helper functions used
    as part of virtualization, and provide a public constructor. For now we will just
    implement the constructor:

    ```rust
    impl<'a, Spi: hil::spi::SpiMaster> MuxSpiMaster<'a, Spi> {
        pub const fn new(spi: &'a Spi) -> MuxSpiMaster<'a, Spi> {
            MuxSpiMaster {
                spi: spi,
                devices: List::new(),
                inflight: OptionalCell::empty(),
            }
        }

        // TODO: Implement virtualization logic helper functions
    }
    ```

4. **Create a `VirtualXXXDevice` which will implement the underlying HIL trait**

    In the previous step you probably noticed the list of virtual devices referencing a
    `VirtualSpiMasterDevice`, which we had not created yet. We will define and implement that
    struct here. In practice, both must be defined simultaneously because each type references
    the other. The `VirtualSpiMasterDevice` should have a reference to the mux, a `ListLink`
    field (required so that lists of `VirtualSpiMasterDevice`s can be constructed),
    and other fields for data that needs to be stored *for each client* of the virtualizer.

    ```rust
    pub struct VirtualSpiMasterDevice<'a, Spi: hil::spi::SpiMaster> {
        //reference to the mux
        mux: &'a MuxSpiMaster<'a, Spi>,

        // Pointer to next element in the list of devices
        next: ListLink<'a, VirtualSpiMasterDevice<'a, Spi>>,

        // Per client data that must be stored across calls
        chip_select: Cell<Spi::ChipSelect>,
        txbuffer: TakeCell<'static, [u8]>,
        rxbuffer: TakeCell<'static, [u8]>,
        operation: Cell<Op>,
        client: OptionalCell<&'a dyn hil::spi::SpiMasterClient>,
    }

    impl<'a, Spi: hil::spi::SpiMaster> VirtualSpiMasterDevice<'a, Spi> {
        pub const fn new(
            mux: &'a MuxSpiMaster<'a, Spi>,
            chip_select: Spi::ChipSelect,
        ) -> VirtualSpiMasterDevice<'a, Spi> {
            VirtualSpiMasterDevice {
                mux: mux,
                chip_select: Cell::new(chip_select),
                txbuffer: TakeCell::empty(),
                rxbuffer: TakeCell::empty(),
                operation: Cell::new(Op::Idle),
                next: ListLink::empty(),
                client: OptionalCell::empty(),
            }
        }

        // Most virtualizers will use a set_client method that looks exactly like this
        pub fn set_client(&'a self, client: &'a dyn hil::spi::SpiMasterClient) {
            self.mux.devices.push_head(self);
            self.client.set(client);
        }
    }
    ```

    This is the struct that will implement whatever HIL trait we decided on in step 1.
    In our case, this is the `SpiMasterDevice` trait:

    ```rust
    // Given that there are multiple types of operations we might need to queue,
    // create an enum that can represent each operation and the data that operation
    // needs to store.
    #[derive(Copy, Clone, PartialEq)]
    enum Op {
        Idle,
        Configure(hil::spi::ClockPolarity, hil::spi::ClockPhase, u32),
        ReadWriteBytes(usize),
        SetPolarity(hil::spi::ClockPolarity),
        SetPhase(hil::spi::ClockPhase),
        SetRate(u32),
    }

    impl<Spi: hil::spi::SpiMaster> hil::spi::SpiMasterDevice for VirtualSpiMasterDevice<'_, Spi> {
        fn configure(&self, cpol: hil::spi::ClockPolarity, cpal: hil::spi::ClockPhase, rate: u32) {
            self.operation.set(Op::Configure(cpol, cpal, rate));
            self.mux.do_next_op();
        }

        fn read_write_bytes(
            &self,
            write_buffer: &'static mut [u8],
            read_buffer: Option<&'static mut [u8]>,
            len: usize,
        ) -> ReturnCode {
            self.txbuffer.replace(write_buffer);
            self.rxbuffer.put(read_buffer);
            self.operation.set(Op::ReadWriteBytes(len));
            self.mux.do_next_op();
            ReturnCode::SUCCESS
        }

        fn set_polarity(&self, cpol: hil::spi::ClockPolarity) {
            self.operation.set(Op::SetPolarity(cpol));
            self.mux.do_next_op();
        }

        fn set_phase(&self, cpal: hil::spi::ClockPhase) {
            self.operation.set(Op::SetPhase(cpal));
            self.mux.do_next_op();
        }

        fn set_rate(&self, rate: u32) {
            self.operation.set(Op::SetRate(rate));
            self.mux.do_next_op();
        }

        fn get_polarity(&self) -> hil::spi::ClockPolarity {
            self.mux.spi.get_clock()
        }

        fn get_phase(&self) -> hil::spi::ClockPhase {
            self.mux.spi.get_phase()
        }

        fn get_rate(&self) -> u32 {
            self.mux.spi.get_rate()
        }
    }
    ```

    Now we can begin to see the virtualization logic. Each `get_x()` method just forwards calls
    directly to the underlying hardware driver, as these operations are synchronous and non-blocking.
    But the `set()` calls and the read/write calls
    are queued as operations. Each client can have only a single outstanding operation (a common
    requirement for virtualizers in Tock given the lack of dynamic allocation). These operations
    are "queued" by each client simply setting the operation field of its `VirtualSpiMasterDevice`
    to whatever operation it would like to perform next. The Mux can iterate through the list
    of devices to choose a pending operation. Clients learn about the completion of operations
    via callbacks, informing them that they can begin new operations.

5. **Implement the logic for queuing requests from capsules.**

    So far, we have sketched out a skelton for how we will queue requests from capsules, but
    not yet implemented the `do_next_op()` function that will handle the order in which operations
    are performed, or how operations are translated into calls by the actual hardware driver.

    We know that all operations in Tock are asynchronous, so it is always possible that
    the underlying hardware device is busy when `do_next_op()` is called -- accordingly,
    we need some mechanism for tracking if the underlying device is currently busy. We also
    need to restore the state expected by the device performing a given operaion (e.g. the chip
    select pin in use). Beyond that, we just forward calls to the hardware driver:

    ```rust
    fn do_next_op(&self) {
        if self.inflight.is_none() {
            let mnode = self
                .devices
                .iter()
                .find(|node| node.operation.get() != Op::Idle);
            mnode.map(|node| {
                self.spi.specify_chip_select(node.chip_select.get());
                let op = node.operation.get();
                // Need to set idle here in case callback changes state
                node.operation.set(Op::Idle);
                match op {
                    Op::Configure(cpol, cpal, rate) => {
                        // The `chip_select` type will be correct based on
                        // what implemented `SpiMaster`.
                        self.spi.set_clock(cpol);
                        self.spi.set_phase(cpal);
                        self.spi.set_rate(rate);
                    }
                    Op::ReadWriteBytes(len) => {
                        // Only async operations want to block by setting
                        // the devices as inflight.
                        self.inflight.set(node);
                        node.txbuffer.take().map(|txbuffer| {
                            let rxbuffer = node.rxbuffer.take();
                            self.spi.read_write_bytes(txbuffer, rxbuffer, len);
                        });
                    }
                    Op::SetPolarity(pol) => {
                        self.spi.set_clock(pol);
                    }
                    Op::SetPhase(pal) => {
                        self.spi.set_phase(pal);
                    }
                    Op::SetRate(rate) => {
                        self.spi.set_rate(rate);
                    }
                    Op::Idle => {} // Can't get here...
                }
            });
        }
    }
    ```

    Notably, the SPI driver does not implement any fairness schemes, despite the requirements of
    the threat model. As of this writing, the threat model is still aspirational, and not followed
    for all virtualizers. Eventually, this driver should be updated to use round robin queueing of
    clients, rather than always giving priority to whichever client was added to the List first.

6. **Implement the logic for dispatching callbacks from the underlying resource to the appropriate client.**

    We are getting close! At this point, we have a mechanism for adding clients to the virtualizer,
    and for queueing and making calls. However, we have not yet addressed how to handle callbacks
    from the underlying resource (usually used to forward interrupts up to the appropriate client).
    Additionally, our queueing logic is still incomplete, as we have not yet seen when subsequent
    operations are triggered if an operation is requested while the underlying device is in use.

    Handling callbacks in virtualizers requires two layers of handling. First, the `MuxXXX` device
    must implement the appropriate `XXXClient` trait such that it can subscribe to callbacks
    from the underlying resource, and dispatch them to the appropriate `VirtualXXXDevice`:

    ```rust
    impl<Spi: hil::spi::SpiMaster> hil::spi::SpiMasterClient for MuxSpiMaster<'_, Spi> {
        fn read_write_done(
            &self,
            write_buffer: &'static mut [u8],
            read_buffer: Option<&'static mut [u8]>,
            len: usize,
        ) {
            self.inflight.take().map(move |device| {
                self.do_next_op();
                device.read_write_done(write_buffer, read_buffer, len);
            });
        }
    }
    ```

    This takes advantage of the fact that we stored a reference to device that initiated
    the inflight operation, so we can dispatch the callback directly to that device.
    One thing to note is that the call to `take()` sets `inflight` to `None`, and then 
    the callback calls `do_next_op()`, triggering any still queued operations. This ensures that
    all queued operations will take place.
    This all requires that the device also has implemented the callback:

    ```rust
    impl<Spi: hil::spi::SpiMaster> hil::spi::SpiMasterClient for VirtualSpiMasterDevice<'_, Spi> {
    fn read_write_done(
        &self,
        write_buffer: &'static mut [u8],
        read_buffer: Option<&'static mut [u8]>,
        len: usize,
    ) {
        self.client.map(move |client| {
            client.read_write_done(write_buffer, read_buffer, len);
        });
    }
    ```

    Finally, we have dispatched the callback all the way up to the client of the virtualizer,
    completing the round trip process.

7. **Document the interface.**

    Finally, you need to document the interface. Do so by placing a comment at the top
    of the file describing what the file does:

    ```rust
    //! Virtualize a SPI master bus to enable multiple users of the SPI bus.

    ```

    and add doc comments (`/// doc comment example`) to any new traits created in `kernel/src/hil`.

8. **(Optional) Write tests for the virtualization logic.**

    Some virtualizers provide additional stress tests of virtualization logic, which can be run on
    hardware to perform correct operation in edge cases. For examples of such tests, look at
    `capsules/src/test/virtual_uart.rs` or `capsules/src/test/random_alarm.rs`.

## Wrap-Up

Congratulations! You have virtualized a resource in the Tock kernel!
We encourage you to submit a pull request to upstream
this to the Tock repository.
