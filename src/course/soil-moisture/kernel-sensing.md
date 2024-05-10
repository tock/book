Soil Moisture Sensor Kernel
================

In this submodule we will configure a Tock kernel to support reading the soil
moisture sensor. This will enable the `soil-moisture-sensor` app from the next
section.

Prerequisites
---------

This guide assumes you already have a working Tock kernel for your board. We
will extend the kernel with the necessary features to support soil moisture
sensing.

Syscall 1: GPIO
---------------

We will start with adding support for GPIO pins in userspace. We need one GPIO
pin to power on the soil moisture sensor.

> Note: your kernel may already have GPIO configured. In that case you will only
> need to modify it to support the correct pin.

First, we need to define the pin. This is the GPIO pin you attached to the red
wire on the soil moisture sensor. On my board I connected it to pin 1.10. Edit
this for your setup and add it to the top of `main.rs`.

```rust
const GPIO_SOIL_SENSOR_POWER: Pin = Pin::P1_10;
```

Now, define a capsule for GPIO, using that pin. Map that pin to index 0. You
will need to change the types to match your microcontroller if you are not using
an nRF52840.

```rust
//--------------------------------------------------------------------------
// GPIO
//--------------------------------------------------------------------------

let gpio = components::gpio::GpioComponent::new(
    board_kernel,
    capsules_core::gpio::DRIVER_NUM,
    components::gpio_component_helper!(
        nrf52840::gpio::GPIOPin,
        0 => &nrf52840_peripherals.gpio_port[GPIO_SOIL_SENSOR_POWER],
    ),
)
.finalize(components::gpio_component_static!(nrf52840::gpio::GPIOPin));
```

Then we need to connect that capsule to userspace. This requires a couple setup steps.

First, add the `gpio` type to the `Platform` struct:

```rust
type GpioDriver = components::gpio::GpioComponentType<nrf52840::gpio::GPIOPin<'static>>;

pub struct Platform {
    ...
    gpio: &'static GpioDriver,
    ...
}
```

and make sure the `gpio` object is added to the platform struct.

```rust
let platform = Platform {
    ...
    gpio,
    ...
};
```

Then make sure that userspace system calls can access the `gpio` capsule:

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where
        F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R,
    {
        match driver_num {
        	...
            capsules_core::gpio::DRIVER_NUM => f(Some(self.gpio)),
            ...
        }
    }
}
```

Syscall 2: ADC
---------------

The second syscall we need to add is for the analog-to-digital (ADC) converter.
This will nearly directly mirror adding GPIO.

First we add the ADC capsule configured with a single ADC pin that we connected
to the soil moisture sensor data pin.

```rust
//--------------------------------------------------------------------------
// ADC
//--------------------------------------------------------------------------

base_peripherals.adc.calibrate();

let adc = components::adc::AdcDedicatedComponent::new(
    &base_peripherals.adc,
    static_init!(
        [nrf52840::adc::AdcChannelSetup; 1],
        [nrf52840::adc::AdcChannelSetup::new(nrf52840::adc::AdcChannel::AnalogInput1)]
    ),
    board_kernel,
    capsules_core::adc::DRIVER_NUM,
)
.finalize(components::adc_dedicated_component_static!(nrf52840::adc::Adc));
```

And connect the ADC capsule to the rest of the system:


```rust
type AdcDriver = components::adc::AdcDedicatedComponentType<nrf52840::adc::Adc<'static>>;

pub struct Platform {
    ...
    adc: &'static AdcDriver,
    ...
}
```

```rust
impl SyscallDriverLookup for Platform {
    fn with_driver<F, R>(&self, driver_num: usize, f: F) -> R
    where F: FnOnce(Option<&dyn kernel::syscall::SyscallDriver>) -> R {
        match driver_num {
        	...
            capsules_core::adc::DRIVER_NUM => f(Some(self.adc)),
            ...
        }
    }
}
```


```rust
let platform = Platform {
    ...
    adc,
    ...
};
```



Compile and Install
--------------------

You can now compile the kernel and load it on the board:

```
$ make
$ make install
```

This will enable the `soil-moisture-sensor` app from the next module.









