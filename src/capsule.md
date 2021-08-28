# Capsule

The goal of this part of the course is to make you comfortable with the Tock
kernel and writing code for it. By the end of this part, you'll have written a
new capsule that reads a humidity sensor and outputs its readings over the
serial port.

During this you will:

1. Learn how Tock uses Rust's memory safety to provide isolation for free
2. Read the Tock boot sequence, seeing how Tock uses static allocation
3. Learn about Tock's event-driven programming
4. Write a new capsule that reads a humidity sensor and prints it over serial

## Read the Tock boot sequence (20m)

Open `imix/src/main.rs` in your favorite editor. This file defines the imix
platform: how it boots, what capsules it uses, and what system calls it supports
for userland applications.

### How is everything organized?

Find the declaration of `struct Imix` (it's pretty early in the file). This
declares the structure representing the platform. It has many fields, all of
which are capsules. These are the capsules that make up the imix platform. For
the most part, these map directly to hardware peripherals, but there are
exceptions such as `IPC` (inter-process communication).

Recall the discussion about how everything in the kernel is statically
allocated? We can see that here. Every field in `struct Imix` is a reference to
an object with a static lifetime.

The capsules themselves take a lifetime as a parameter, which is currently
always `` `static``. The implementations of these capsules, however, do not rely
on this assumption.

The boot process is primarily the construction of this `Imix` structure. Once
everything is set up, the board will pass the constructed `imix` to
`kernel::kernel_loop` and we're off to the races.

### How do things get started?

The method `reset_handler` is invoked when the chip resets (i.e., boots). It's
pretty long because imix has a lot of drivers that need to be created and
initialized, and many of them depend on other, lower layer abstractions that
need to be created and initialized as well.

Take a look at the first few lines of the `reset_handler`. The boot sequence
initializes memory (copies initialized variables into RAM, clears the BSS), sets
up the system clocks, and configures the GPIO pins.

### How do capsules get created?

The next lines of `reset_handler` create and initialize the system console,
which is what turns calls to `println` into bytes sent to the USB serial port:

```rust
let uart_mux = static_init!(
    MuxUart<'static>,
    MuxUart::new(
        &sam4l::usart::USART3,
        &mut capsules::virtual_uart::RX_BUF,
        115200
    )
);
uart_mux.initialize();

hil::uart::Transmit::set_transmit_client(&sam4l::usart::USART3, uart_mux);
hil::uart::Receive::set_receive_client(&sam4l::usart::USART3, uart_mux);

let console = ConsoleComponent::new(board_kernel, uart_mux).finalize();
```

Eventually, once all of the capsules have been created, we will populate a imix
structure with them:

```rust
let imix = Imix {
    console: console,
    gpio: gpio,
    ...
```

The `static_init!` macro is simply an easy way to allocate a static variable
with a call to `new`. The first parameter is the type, the second is the
expression to produce an instance of the type. This call creates a `Console`
that uses serial port 3 (`USART3`) at 115200 bits per second.

> #### A brief aside on buffers:
>
> Notice that you have to pass a write buffer to the console for it to use: this
> buffer has to have a `` `static`` lifetime. This is because low-level hardware
> drivers, especially those that use DMA, require `` `static`` buffers. Since
> Tock doesn't promise when a DMA operation will complete, and you need to be
> able to promise that the buffer outlives the operation, the one lifetime that
> is assured to be alive at the end of an operation is `` `static``. So that
> other code which has buffers without a `` `static`` lifetime, such as
> userspace processes, can use the `Console`, it copies them into its own
> internal `` `static`` buffer before passing it to the serial port. So the
> buffer passing architecture looks like this:
>
> ![Console/UART buffer lifetimes](imgs/console.svg)
>
> It's a little weird that Console's `new` method takes in a reference to
> itself. This is an ergonomics tradeoff. The Console needs a mutable static
> buffer to use internally, which the Console capsule declares. However writing
> global statics is unsafe. To avoid the unsafe operation in the Console capsule
> itself, we make it the responsibility of the instantiator to give the Console
> a buffer to use, without burdening the instantiator with sizing the buffer.

### Let's make an imix!

The code continues on, creating all of the other capsules that are needed by the
imix platform. By the time we get down to around line 360, we've created all of
the capsules we need, and it's time to create the actual imix platform structure
(`let imix = Imix {...}`).

### Capsule _initialization_

Up to this point we have been creating numerous structures and setting some
static configuration options and mappings, but nothing dynamic has occurred
(said another way, all methods invoked by `static_init!` must be `const fn`,
however Tock's `static_init!` macro predates stabilization of `const fn`'s. A
future iteration could possibly leverage these and obviate the need for the
macro).

Some capsules require _initialization_, some code that must be executed before
they can be used. For example, a few lines after creating the imix struct, we
initialize the console:

```rust
imix.nrf51822.initialize();
```

This method is responsible for actually writing the hardware registers that
configure the associated UART peripheral for use as a text console (8 data bits,
1 stop bit, no parity bit, no hardware flow control).

### Inter-capsule dependencies

Just after initializing the console capsule, we find this line:

```rust
kernel::debug::assign_console_driver(Some(imix.console), kc);
```

This configures the kernel's `debug!` macro to print messages to this console
we've just created. The `debug!` mechanism can be very helpful during
development and testing. Today we're going to use it to print output from the
capsule you create.

Let's try it out really quick:

```diff
--- a/boards/imix/src/main.rs
+++ b/boards/imix/src/main.rs
@@ -10,7 +10,7 @@
 extern crate capsules;
 extern crate cortexm4;
 extern crate compiler_builtins;
-#[macro_use(static_init)]
+#[macro_use(debug, static_init)]
 extern crate kernel;
 extern crate sam4l;

@@ -388,6 +388,8 @@ pub unsafe fn reset_handler() {
         capsules::console::App::default());
     kernel::debug::assign_console_driver(Some(imix.console), kc);

+    debug!("Testing 1, 2, 3...");
+
     imix.nrf51822.initialize();
```

Compile and flash the kernel (`make program`) then look at the output
(`tockloader listen`).

- What happens if you put the `debug!` before `assign_console_driver`?
- What happens if you put `imix.console.initialize()` after
  `assign_console_driver`?

As you can see, sometimes there are dependencies between capsules, and board
authors must take care during initialization to ensure correctness.

> **Note:** The `debug!` implementation is _asynchronous_. It copies messages
> into a buffer and the console prints them via DMA as the UART peripheral is
> available, interleaved with other console users (i.e. processes). You
> shouldn't need to worry about the mechanics of this for now.

### Loading processes

Once the platform is all set up, the board is responsible for loading processes
into memory:

```rust
kernel::process::load_processes(&_sapps as *const u8,
                                &mut APP_MEMORY,
                                &mut PROCESSES,
                                FAULT_RESPONSE);
```

A Tock process is represented by a `kernel::Process` struct. In principle, a
platform could load processes by any means. In practice, all existing platforms
write an array of Tock Binary Format (TBF) entries to flash. The kernel provides
the `load_processes` helper function that takes in a flash address and begins
iteratively parsing TBF entries and making `Process`es.

### Starting the kernel

Finally, the board passes a reference to the current platform, the chip the
platform is built on (used for interrupt and power handling), the processes to
run, and an IPC server instance to the main loop of the kernel:

```rust
kernel::main(&imix, &mut chip, &mut PROCESSES, &imix.ipc);
```

From here, Tock is initialized, the kernel event loop takes over, and the system
enters steady state operation.

### Create a "Hello World" capsule

Now that you've seen how Tock initializes and uses capsules, you're going to
write a new one. At the end of this section, your capsule will sample the
humidity sensor once a second and print the results as serial output. But you'll
start with something simpler: printing "Hello World" to the debug console once
on boot.

The `imix` board configuration you've looked through has a capsule for the this
tutorial already set up. The capsule is a separate Rust crate located in
`exercises/capsule`. You'll complete this exercise by filling it in.

In addition to a constructor, Our capsule has `start` function defined that is
currently empty. The board configuration calls this function once it has
initialized the capsule.

Eventually, the `start` method will kick off a state machine for periodic
humidity readings, but for now, let's just print something to the debug console
and return:

```rust
debug!("Hello from the kernel!");
```

```bash
$ cd [PATH_TO_BOOK]/imix
$ make program
$ tockloader listen
No device name specified. Using default "tock"                                                                         Using "/dev/ttyUSB0 - Imix IoT Module - TockOS"
Listening for serial output.
Hello from the kernel!
```

## Extend your capsule to print "Hello World" every second

In order for your capsule to keep track of time, it will need to depend on
another capsule that implements the Alarm interface. We'll have to do something
similar for reading the accelerometer, so this is good practice.

The Alarm HIL includes several traits, `Alarm`, `Client`, and `Frequency`, all
in the `kernel::hil::time` module. You'll use the `set_alarm` and `now` methods
from the `Alarm` trait to set an alarm for a particular value of the clock. Note
that both methods accept arguments in the alarm's native clock frequency, which
is available using the Alarm trait's associated `Frequency` type:

```rust
// native clock frequency in Herz
let frequency = <A::Frequency>::frequency();
```

Your capsule already implements the `alarm::Client` trait so it can receive
alarm events. The `alarm::Client` trait has a single method:

```rust
fn fired(&self)
```

Your capsule should now set an alarm in the `start` method, print the debug
message and set an alarm again when the alarm fires.

Compile and program your new kernel:

```bash
$ make program
$ tockloader listen
No device name specified. Using default "tock"                                                                         Using "/dev/ttyUSB0 - Imix IoT Module - TockOS"
Listening for serial output.
TOCK_DEBUG(0): /home/alevy/hack/helena/rustconf/tock/boards/imix/src/accelerate.rs:31: Hello World
TOCK_DEBUG(0): /home/alevy/hack/helena/rustconf/tock/boards/imix/src/accelerate.rs:31: Hello World
TOCK_DEBUG(0): /home/alevy/hack/helena/rustconf/tock/boards/imix/src/accelerate.rs:31: Hello World
TOCK_DEBUG(0): /home/alevy/hack/helena/rustconf/tock/boards/imix/src/accelerate.rs:31: Hello World
```

[Sample Solution](https://gist.github.com/alevy/73fca7b0dddcb5449088cebcbfc035f1)

## Extend your capsule to sample the humidity once a second

The steps for reading an accelerometer from your capsule are similar to using
the alarm. You'll use a capsule that implements the humidity HIL, which includes
the `HumidityDriver` and `HumidityClient` traits, both in
`kernel::hil::sensors`.

The `HumidityDriver` trait includes the method `read_accelerometer` which
initiates an accelerometer reading. The `HumidityClient` trait has a single
method for receiving readings:

```rust
fn callback(&self, humidity: usize);
```

Implement logic to initiate a accelerometer reading every second and report the
results.

![Structure of `rustconf` capsule](imgs/rustconf.svg)

Compile and program your kernel:

```bash
$ make program
$ tockloader listen
No device name specified. Using default "tock"                                                                         Using "/dev/ttyUSB0 - Imix IoT Module - TockOS"
Listening for serial output.
Humidity 2731
Humidity 2732
```

[Sample solution](https://gist.github.com/alevy/798d11dbfa5409e0aa56d870b4b7afcf)

## Some further questions and directions to explore

Your capsule used the si7021 and virtual alarm. Take a look at the code behind
each of these services:

1. Is the humidity sensor on-chip or a separate chip connected over a bus?

2. What happens if you request two humidity sensors back-to-back?

3. Is there a limit on how many virtual alarms can be created?

4. How many virtual alarms does the imix boot sequence create?

### **Extra credit**: Write a virtualization capsule for humidity sensor (∞)

If you have extra time, try writing a virtualization capsule for the `Humidity`
HIL that will allow multiple clients to use it. This is a fairly open ended
task, but you might find inspiration in the `virtua_alarm` and `virtual_i2c`
capsules.
