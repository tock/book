# Implementing a Sensor Driver

This guide describes the steps necessary to implement a capsule in Tock that
interfaces with an external IC, like a sensor, memory chip, or display. These
are devices which are not part of the same chip as the main microcontroller
(MCU), but are on the same board and connected via some physical connection.

> Note: to attempt to be generic, this guide will use the term "IC" to refer to
> the device the driver is for.

> Note: "driver" is a bit of an overloaded term in Tock. In this guide, "driver"
> is used in the generic sense to mean code that interfaces with the external
> IC.

To illustrate the steps, this guide will use a generic light sensor as the
running example. You will need to adapt the generic steps for your particular
use case.

Often the goal of an IC driver is to expose an interface to that sensor or other
IC to userspace applications. This guide does not cover creating that userspace
interface as that is covered in a different guide.

## Background

As mentioned, this guide describes creating a capsule. Capsules in Tock are
units of Rust code that extend the kernel to add interesting features, like
interfacing with new sensors. Capsules are "untrusted", meaning they cannot call
unsafe code in Rust and cannot use the `unsafe` keyword.

## Overview

The high-level steps required are:

1. Create a struct for the IC driver.
2. Implement the logic to interface with the IC.

Optional:

1. Provide a HIL interface for the IC driver.
2. Provide a userspace interface for the IC driver.

## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Create a struct for the IC driver.**

   The driver will be implemented as a capsule, so the first step is to create a
   new file in the `capsules/src` directory. The name of this file should be
   `[chipname].rs` where `[chipname]` is the part number of the IC you are
   writing the driver for. There are several other examples in the capsules
   folder.

   For our example we will assume the part number is `ls1234`.

   You then need to add the filename to `capsules/src/lib.rs` like:

   ```rust
   pub mod ls1234;
   ```

   Now inside of the new file you should create a struct with the fields
   necessary to implement the driver for the IC. In our example we will assume
   the IC is connected to the MCU with an I2C bus. Your IC might use SPI, UART,
   or some other standard interface. You will need to adjust how you create the
   struct based on the interface. You should be able to find examples in the
   capsules directory to copy from.

   The struct will look something like:

   ```rust
   pub struct Ls1234 {
       i2c: &'a dyn I2CDevice,
       state: Cell<State>,
       buffer: TakeCell<'static, [u8]>,
       client: OptionalCell<&'a dyn Ls1234Client>,
   }
   ```

   You can see the resources this driver requires to successfully interface with
   the light sensor:

   - `i2c`: This is a reference to the I2C bus that the driver will use to
     communicate with the IC. Notice in Tock the type is `I2CDevice`, and no
     address is provided. This is because the `I2CDevice` type wraps the address
     in internally, so that the driver code can _only_ communicate with the
     correct address.
   - `state`: Often drivers will iterate through various states as they
     communicate with the IC, and it is common for drivers to keep some state
     variable to manage this. Our `State` is defined as an enum, like so:

     ```rust
     #[derive(Copy, Clone, PartialEq)]
     enum State {
         Disabled,
         Enabling,
         ReadingLight,
     }
     ```

     Also note that the `state` variable uses a `Cell`. This is so that the
     driver can update the state.

   - `buffer`: This holds a reference to a buffer of memory the driver will use
     to send messages over the I2C bus. By convention, these buffers are defined
     statically in the same file as the driver, but then passed to the driver
     when the board boots. This provides the board flexibility on the buffer to
     use, while still allowing the driver to hint at the size required for
     successful operation. In our case the static buffer is defined as:

     ```rust
     pub static mut BUF: [u8; 3] = [0; 3];
     ```

     Note the buffer is wrapped in a `TakeCell` such that it can be passed to
     the I2C hardware when necessary, and re-stored in the driver struct when
     the I2C code returns the buffer.

   - `client`: This is the callback that will be called after the driver has
     received a reading from the sensor. All execution is event-based in Tock,
     so the caller will not block waiting for a sample, but instead will expect
     a callback via the client when the same is ready. The driver has to define
     the type of the callback by defining the `Ls1234Client` trait in this case:

     ```rust
     pub trait Ls1234Client {
     	 fn callback(light_reading: usize);
     }
     ```

     Note that the client is stored in an `OptionalCell`. This allows the
     callback to not be set initially, and configured at bootup.

   Your driver may require other state to be stored as well. You can update this
   struct as needed to for state required to successfully implement the driver.
   Note that if the state needs to be updated at runtime it will need to be
   stored in a cell type. See the cell documentation for more information on the
   various cell types in Tock.

   > Note: your driver should not keep any state in the struct that is also
   > stored by the hardware. This easily leads to bugs when that state becomes
   > out of sync, and makes further development on the driver difficult.

   The last step is to write a function that enables creating an instance of
   your driver. By convention, the function is called `new()` and looks
   something like:

   ```rust
   impl Ls1234<'a> {
       pub fn new(i2c: &'a dyn I2CDevice, buffer: &'static mut [u8]) -> Ls1234<'a> {
           Ls1234 {
               i2c: i2c,
               buffer: buffer,
               state: Cell::new(State::Disabled),
               client: OptionalCell::empty(),
           }
       }
   }
   ```

   This function will get called by the board's `main.rs` file when the driver
   is instantiated. All of the static objects or configuration that the driver
   requires must be passed in here. In this example, a reference to the I2C
   device and the static buffer for passing messages must be provided.

   **Checkpoint**: You have defined the struct which will become the driver for
   the IC.

2. **Implement the logic to interface with the IC.**

   Now, you will actually write the code that interfaces with the IC. This
   requires extending the `impl` of the driver struct with additional functions
   appropriate for your particular IC.

   With our light sensor example, we likely want to write a sample function for
   reading a light sensor value:

   ```rust
   impl Ls1234<'a> {
       pub fn new(...) -> Ls1234<'a> {...}

       pub fn start_light_reading(&self) {...}
   }
   ```

   Note that the function name is "start light reading", which is appropriate
   because of the event-driven, non-blocking nature of the Tock kernel. Actually
   communicating with the sensor will take some time, and likely requires
   multiple messages to be sent to and received from the sensor. Therefore, our
   sample function will not be able to return the result directly. Instead, the
   reading will be provided in the callback function described earlier.

   The start reading function will likely prepare the message buffer in a way
   that is IC-specific, then send the command to the IC. A rough example of that
   operation looks like:

   ```rust
   impl Ls1234<'a> {
       pub fn new(...) -> Ls1234<'a> {...}

       pub fn start_light_reading(&self) {
           if self.state.get() == State::Disabled {
               self.buffer.take().map(|buf| {
                   self.i2c.enable();

                   // Set the first byte of the buffer to the "on" command.
                   // This is IC-specific and will be described in the IC
                   // datasheet.
                   buf[0] = 0b10100000;

                   // Send the command to the chip and update our state
                   // variable.
                   self.i2c.write(buf, 1);
                   self.state.set(State::Enabling);
               });
           }
       }
   }
   ```

   The `start_light_reading()` function kicks off reading the light value from
   the IC and updates our internal state machine state to mark that we are
   waiting for the IC to turn on. Now the `Ls1234` code is finished for the time
   being and we now wait for the I2C message to finish being sent. We will know
   when this has completed based on a callback from the I2C hardware.

   ```rust
   impl I2CClient for Ls1234<'a> {
       fn command_complete(&self, buffer: &'static mut [u8], error: Error) {
           // Handle what happens with the I2C send is complete here.
       }
   }
   ```

   In our example, we have to send a new command after turning on the light
   sensor to actually read a sampled value. We use our state machine here to
   organize the code as in this example:

   ```rust
   impl I2CClient for Ls1234<'a> {
       fn command_complete(&self, buffer: &'static mut [u8], _error: Error) {
           match self.state.get() {
               State::Enabling => {
                   // Put the read command in the buffer and send it back to
                   // the sensor.
                   buffer[0] = 0b10100001;
                   self.i2c.write_read(buf, 1, 2);
                   // Update our state machine state.
                   self.state.set(State::ReadingLight);
               }
               _ => {}
           }
       }
   }
   ```

   This will send another command to the sensor to read the actual light
   measurement. We also update our `self.state` variable because when this I2C
   transaction finishes the exact same `command_complete` callback will be
   called, and we must be able to remember where we are in the process of
   communicating with the sensor.

   When the read finishes, the `command_complete()` callback will fire again,
   and we must handle the result. Since we now have the reading we can call our
   client's callback after updating out state machine.

   ```rust
   impl I2CClient for Ls1234<'a> {
       fn command_complete(&self, buffer: &'static mut [u8], _error: Error) {
           match self.state.get() {
               State::Enabling => {
                   // Put the read command in the buffer and send it back to
                   // the sensor.
                   buffer[0] = 0b10100001;
                   self.i2c.write_read(buf, 1, 2);
                   // Update our state machine state.
                   self.state.set(State::ReadingLight);
               }
               State::ReadingLight => {
                   // Extract the light reading value.
                   let mut reading: u16 = buffer[0] as 16;
                   reading |= (buffer[1] as u16) << 8;

                   // Update our state machine state.
                   self.state.set(State::Disabled);

                   // Trigger our callback with the result.
                   self.client.map(|client| client.callback(reading));
               }
               _ => {}
           }
       }
   }
   ```

   > Note: likely the sensor would need to be disabled and returned to a low
   > power state.

   At this point your driver can read the IC and return the information from the
   IC. For your IC you will likely need to expand on this general template. You
   can add additional functions to the main struct implementation, and then
   expand the state machine to implement those functions. You may also need
   additional resources, like GPIO pins or timer alarms to implement the state
   machine for the IC. There are examples in the `capsules/src` folder with
   drivers that need different resources.

## Optional Steps

1. **Provide a HIL interface for the IC driver.**

   The driver so far has a very IC-specific interface. That is, any code that
   uses the driver must be written specifically with that IC in mind. In some
   cases that may be reasonable, for example if the IC is very unusual or has a
   very unique set of features. However, many ICs provide similar functionality,
   and higher-level code can be written without knowing what specific IC is
   being used on a particular hardware platform.

   To enable this, some IC types have HILs in the `kernel/src/hil` folder in the
   `sensors.rs` file. Drivers can implement one of these HILs and then
   higher-level code can use the HIL interface rather than a specific IC.

   To implement the HIL, you must implement the HIL trait functions:

   ```rust
   impl AmbientLight for Ls1234<'a> {
       fn set_client(&self, client: &'static dyn AmbientLightClient) {

       }

       fn read_light_intensity(&self) -> ReturnCode {

       }
   }
   ```

   The user of the `AmbientLight` HIL will implement the `AmbientLightClient`
   and provide the client through the `set_client()` function.

2. **Provide a userspace interface for the IC driver.**

   Sometimes the IC is needed by userspace, and therefore needs a syscall
   interface so that userspace applications can use the IC. Please refer to a
   separate guide on how to implement a userspace interface for a capsule.

## Wrap-Up

Congratulations! You have implemented an IC driver as a capsule in Tock! We
encourage you to submit a pull request to upstream this to the Tock repository.
Tock is happy to accept capsule drivers even if no boards in the Tock repository
currently use the driver.
