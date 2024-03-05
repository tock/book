# Implementing a Kernel Test

This guide covers how to write in-kernel tests of hardware functionality. For
example, if you have implemented a chip peripheral, you may want to write
in-kernel tests of that peripheral to test peripheral-specific functionality
that will not be exposed via the HIL for that peripheral. This guide outlines
the general steps for implementing kernel tests.

## Setup

This guide assumes you have existing chip, board, or architecture specific code
that you wish to test from within the kernel.

> Note: If you wish to test kernel code with no hardware dependencies at all,
> such as a ring buffer implementation, you can use cargo's test framework
> instead. These tests can be run by simply calling `cargo test` within the
> crate that the test is located, and will be executed during CI for all tests
> merged into upstream Tock. An example of this approach can be found in
> `kernel/src/collections/ring_buffer.rs`.

## Overview

The general steps you will follow are:

1. Determine the board(s) you want to run your tests on
2. Add a test file in `boards/{board}/src/tests/`
3. Determine where to write actual tests -- in the test file or a capsule test
4. Write your tests
5. Call the test from `main.rs`
6. Document the expected output from the test at the top of the test file

This guide will walk through how to do each of these steps.

## Background

Kernel tests allow for testing of hardware-specific functionality that is not
exposed to userspace, and allows for fail-fast tests at boot that otherwise
would not be exposed until apps are loaded. Kernel tests can be useful to test
chip peripherals prior to exposing these peripherals outside the Kernel. Kernel
tests can also be included as required tests run prior to releases, to ensure
there have been no regressions for a particular component. Additionally, kernel
tests can be useful for testing capsule functionality from within the kernel,
such as when `unsafe` is required to verify the results of tests, or for testing
virtualization capsules in a controlled environment.

Kernel tests are generally implemented on an as-needed basis, and are not
required for all chip peripherals in Tock. In general, they are not expected to
be run in the default case, though they should always be included from `main.rs`
so they are compiled. These tests are allowed to use `unsafe` as needed, and are
permitted to conflict with normal operation, by stealing callbacks from drivers
or modifying global state.

Notably, your specific use case may differ some from the one outline here. It is
always recommended to attempt to copy from existing Tock code when developing
your own solutions. A good collection of kernel tests can be found in
`boards/imix/src/tests/` for that purpose.

## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Determine the board(s) you want to run your test on.**

   If you are testing chip or architecture specific functionality, you simply
   need to choose a board that uses that chip or architecture. For board
   specific functionality you of course need to choose that board. If you are
   testing a virtualization capsule, then any board that implements the
   underlying resource being virtualized is acceptable. Currently, most kernel
   tests are implemented for the Imix platform, and can be found in
   `boards/imix/src/tests/`

   **Checkpoint**: You have identified the board you will implement your test
   for.

2. **Add a test file in `boards/{board}/src/tests/`**

   To start implementing the test, you should create a new source file inside
   the `boards/{board}/src/tests` directory and add the file to the
   `tests/mod.rs` file. The name of this test file generally should indicate the
   functionality being tested.

   > Note: If the board you select is one of the nrf52dk variants
   > (nrf52840_dongle, nrf52840dk, or nrf52dk), tests should be moved into the
   > `nrf52dk_base/src/` folder, and called from `lib.rs`.

   **Checkpoint**: You have chosen a board for your test and created a test
   file.

3. **Determine where to write actual tests -- in the test file or a capsule
   test.**

   Depending on what you are testing, it may be best practice to write a capsule
   test that you call from the test file you created in the previous step.

   Writing a capsule test is best practice if your test meets the following
   criteria:

   1. Test does not require `unsafe`
   2. The test is for a peripheral available on multiple boards
   3. A HIL or capsule exists for that peripheral, so it is accessible from the
      `capsules` crate
   4. The test relies only on functionality exposed via the HIL or a capsule
   5. You care about being able to call this test from multiple boards

   Examples:

   - UART Virtualization (all boards support UART, there is a HIL for UART
     devices and a capsule for the `virtual_uart`)
   - Alarm test (all boards will have some form of hardware alarm, there is an
     Alarm HIL)
   - Other examples: see `capsules/core/src/test`

   If your test meets the criteria for writing a capsule test, follow these
   steps:

   Add a file in `capsules/extra/src/test/`, and then add the filename to
   `capsules/extra/src/mod.rs` like this:

   ```rust
   pub mod virtual_uart;
   ```

   Next, create a test struct in this file that can be instantiated by any board
   using this test capsule. This struct should implement a `new()` function so
   it can be instantiated from the test file in `boards`, and a `run()` function
   that will run the actual tests. The test should implement `CapsuleTest` and
   hold a `CapsuleTestClient` to notify when the test has finished.

   An example for UART follows:

   ```rust
   //! capsules/src/test/virtual_uart.rs

   pub struct TestVirtualUartReceive {
       device: &'static UartDevice<'static>,
       buffer: TakeCell<'static, [u8]>,
       client: OptionalCell<&'static dyn CapsuleTestClient>,
   }

   impl TestVirtualUartReceive {
       pub fn new(device: &'static UartDevice<'static>, buffer: &'static mut [u8]) -> Self {
           TestVirtualUartReceive {
               device: device,
               buffer: TakeCell::new(buffer),
               client: OptionalCell::empty(),
           }
       }

       pub fn run(&self) {
           // TODO: See Next Step
       }
   }

   impl CapsuleTest for TestVirtualUartReceive {
       fn set_client(&self, client: &'static dyn CapsuleTestClient) {
           self.client.set(client);
       }
   }
   ```

If your test does not meet the above requirements, you can simply implement your
tests in the file that you created in step 2. This can involve creating a test
structure with test methods. The UDP test file takes this approach, by defining
a number of self-contained tests. One such example follows:

```rust
//! boards/imix/src/test/udp_lowpan_test.rs

pub struct LowpanTest {
    port_table: &'static UdpPortManager,
    // ...
}

impl LowpanTest {

    // This test ensures that an app and capsule cant bind to the same port
    // but can bind to different ports
    fn bind_test(&self) {
        let create_cap = create_capability!(NetworkCapabilityCreationCapability);
        let net_cap = unsafe {
            static_init!(
                NetworkCapability,
                NetworkCapability::new(AddrRange::Any, PortRange::Any, PortRange::Any, &create_cap)
            )
        };
        let mut socket1 = self.port_table.create_socket().unwrap();
        // Attempt to bind to a port that has already been bound by an app.
        let result = self.port_table.bind(socket1, 1000, net_cap);
        assert!(result.is_err());
        socket1 = result.unwrap_err(); // Get the socket back

        //now bind to an open port
        let (_send_bind, _recv_bind) = self
            .port_table
            .bind(socket1, 1001, net_cap)
            .expect("UDP Bind fail");

        debug!("bind_test passed");
    }
    // ...
}
```

**Checkpoint**: There is a test capsule with `new()` and `run()`
implementations.

4. **Write your tests**

   The first part of this step takes place in the test file you just created --
   writing the actual tests. This part is highly dependent on the functionality
   being verified. If you are writing your tests in test capsule, this should
   all be triggered from the `run()` function.

   Depending on the specifics of your test, you may need to implement additional
   functions or traits in this file to make your test functional. One example is
   implementing a client trait on the test struct so that the test can receive
   the results of asynchronous operations. Our UART example requires
   implementing the `uart::RecieveClient` on the test struct.

   When finished, the test should call the `CapsuleTestClient` with the result
   (pass/fail) of the test. If the test succeed, the callback should be passed
   `Ok(())`. If the test failed, the callback should be called with
   `Err(CapsuleTestError)`.

   ```rust
   //! boards/imix/src/test/virtual_uart_rx_test.rs

   impl TestVirtualUartReceive {
       // ...

       pub fn run(&self) {
           let buf = self.buffer.take().unwrap();
           let len = buf.len();
           debug!("Starting receive of length {}", len);
           let (err, _opt) = self.device.receive_buffer(buf, len);
           if err != ReturnCode::SUCCESS {
               debug!(
                   "Calling receive_buffer() in virtual_uart test failed: {:?}",
                   err
               );
               self.client.map(|client| {
                   client.done(Err(CapsuleTestError::ErrorCode(ErrorCode::FAIL)));
               });
           }
       }
   }

   impl uart::ReceiveClient for TestVirtualUartReceive {
       fn received_buffer(
           &self,
           rx_buffer: &'static mut [u8],
           rx_len: usize,
           rcode: ReturnCode,
           _error: uart::Error,
       ) {
           debug!("Virtual uart read complete: {:?}: ", rcode);
           for i in 0..rx_len {
               debug!("{:02x} ", rx_buffer[i]);
           }
           debug!("Starting receive of length {}", rx_len);
           let (err, _opt) = self.device.receive_buffer(rx_buffer, rx_len);
           if err != ReturnCode::SUCCESS {
               debug!(
                   "Calling receive_buffer() in virtual_uart test failed: {:?}",
                   err
               );
               self.client.map(|client| {
                   client.done(Err(CapsuleTestError::ErrorCode(ErrorCode::FAIL)));
               });
           }
       }
   }
   ```

   The next step in this process is determining all of the parameters that need
   to be passed to the test. It is preferred that all logically related tests be
   called from a single `pub unsafe fn run(/* optional args */)` to maintain
   convention. This ensures that all tests can be run by adding a single line to
   `main.rs`. Many tests require a reference to an alarm in order to separate
   tests in time, or a reference to a virtualization capsule that is being
   tested. Notably, the `run()` function should initialize any components itself
   that would not have already been created in `main.rs`. As an example, the
   below function is a starting point for the `virtual_uart_receive` test for
   Imix:

   ```rust
   pub unsafe fn run_virtual_uart_receive(mux: &'static MuxUart<'static>) {
       debug!("Starting virtual reads.");
   }
   ```

   Next, a test function should initialize any objects required to run tests.
   This is best split out into subfunctions, like the following:

   ```rust
   unsafe fn static_init_test_receive_small(
       mux: &'static MuxUart<'static>,
   ) -> &'static TestVirtualUartReceive {
       static mut SMALL: [u8; 3] = [0; 3];
       let device = static_init!(UartDevice<'static>, UartDevice::new(mux, true));
       device.setup();
       let test = static_init!(
           TestVirtualUartReceive,
           TestVirtualUartReceive::new(device, &mut SMALL)
       );
       device.set_receive_client(test);
       test
   }
   ```

   This initializes an instance of the test capsule we constructed earlier.
   Simpler tests (such as those not relying on capsule tests) might simply use
   `static_init!()` to initialize normal capsules directly and test them. The
   log test does this, for example:

   ```rust
   //! boards/imix/src/test/log_test.rs

   pub unsafe fn run(
       mux_alarm: &'static MuxAlarm<'static, Ast>,
       deferred_caller: &'static DynamicDeferredCall,
   ) {
       // Set up flash controller.
       flashcalw::FLASH_CONTROLLER.configure();
       static mut PAGEBUFFER: flashcalw::Sam4lPage = flashcalw::Sam4lPage::new();

       // Create actual log storage abstraction on top of flash.
       let log = static_init!(
           Log,
           log::Log::new(
               &TEST_LOG,
               &mut flashcalw::FLASH_CONTROLLER,
               &mut PAGEBUFFER,
               deferred_caller,
               true
           )
       );
       flash::HasClient::set_client(&flashcalw::FLASH_CONTROLLER, log);
       log.initialize_callback_handle(
           deferred_caller
               .register(log)
               .expect("no deferred call slot available for log storage"),
       );

       // ...
   }
   ```

   Finally, your `run()` function should call the actual tests. This may involve
   simply calling a `run()` function on a capsule test, or may involve calling
   test functions written in the board specific test file. The virtual UART test
   `run()` looks like this:

   ```rust
   pub unsafe fn run_virtual_uart_receive(mux: &'static MuxUart<'static>) {
       debug!("Starting virtual reads.");
       let small = static_init_test_receive_small(mux);
       let large = static_init_test_receive_large(mux);
       small.run();
       large.run();
   }
   ```

   As you develop your kernel tests, you may not immediately know what functions
   are required in your test capsule -- this is okay! It is often easiest to
   start with a basic test and expand this file to test additional functionality
   once basic tests are working.

   **Checkpoint**: Your tests are written, and can be called from a single
   `run()` function.

5. **Call the test from `main.rs`, and iterate on it until it works**

   Next, you should run your test by calling it from the `reset_handler()` in
   `main.rs`. In order to do so, you will also need it import it into the file
   by adding a line like this:

   ```rust
   #[allow(dead_code)]
   mod virtual_uart_test;
   ```

   However, if your test is located inside a `test` module this is not needed --
   your test will already be included.

   Typically, tests are called after completing setup of the board, immediately
   before the call to `load_processes()`:

   ```rust
   virtual_uart_rx_test::run_virtual_uart_receive(uart_mux);
   debug!("Initialization complete. Entering main loop");

   extern "C" {
       /// Beginning of the ROM region containing app images.
       static _sapps: u8;

       /// End of the ROM region containing app images.
       ///
       /// This symbol is defined in the linker script.
       static _eapps: u8;
   }
   kernel::procs::load_processes(
     // ...
   ```

   Observe your results, and tune or add tests as needed.

   Before you submit a PR including any kernel tests, however, please remove or
   comment out any lines of code that call these tests.

   **Checkpoint**: You have a functional test that can be called in a single
   line from `main.rs`

6. **Document the expected output from the test at the top of the test file**

   For tests that will be merged to upstream, it is good practice to document
   how to run a test and what the expected output of a test is. This is best
   done using\ document level comments (`//!`) at the top of the test file. The
   documentation for the virtual UART test follows:

   ````rust
   //! Test reception on the virtualized UART by creating two readers that
   //! read in parallel. To add this test, include the line
   //! ```
   //!    virtual_uart_rx_test::run_virtual_uart_receive(uart_mux);
   //! ```
   //! to the imix boot sequence, where `uart_mux` is a
   //! `capsules::virtual_uart::MuxUart`.  There is a 3-byte and a 7-byte
   //! read running in parallel. Test that they are both working by typing
   //! and seeing that they both get all characters. If you repeatedly
   //! type 'a', for example (0x61), you should see something like:
   //! ```
   //! Starting receive of length 3
   //! Virtual uart read complete: CommandComplete:
   //! 61
   //! 61
   //! 61
   //! 61
   //! 61
   //! 61
   //! 61
   //! Starting receive of length 7
   //! Virtual uart read complete: CommandComplete:
   //! 61
   //! 61
   //! 61
   //! ```
   ````

   **Checkpoint**: You have documented your tests

## Wrap-Up

Congratulations! You have written a kernel test for Tock! We encourage you to
submit a pull request to upstream this to the Tock repository.
