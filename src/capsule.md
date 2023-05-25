# Create a "Hello World" capsule

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
