# Implementing a Component

Each Tock [board](https://github.com/tock/tock/tree/master/boards) defines the
peripherals, capsules, kernel settings, and syscall drivers to customize Tock
for that board. Often, instantiating different resources (particularly capsules
and drivers) requires subtle setup steps that are easy to get wrong. The setup
steps are often shared from board-to-board. Together, this makes configuring a
board redundant and easy to make a mistake.

Components are the Tock mechanism to help address this. Each component includes
the static memory allocations and setup steps required to implement a particular
piece of kernel functionality (i.e. a capsule). You can read more technical
documentation [here](https://docs.tockos.org/kernel/component/).

In this guide we will create a component for a hypothetical system call driver
called `Notifier`. Our system call driver is going to use an alarm as a resource
and requires just one other parameter: a delay value in milliseconds. The steps
should be the same for any capsule you want to create a component for.

## Setup

This guide assumes you already have the capsule created, and ideally that you
have set it up with a board to test. Making a component then just makes it
easier to include on a new board and share among boards.

## Overview

The high-level steps required are:

1. Define the static memory required for all objects used.
2. Create a struct that holds all of the resources and configuration necessary
   for the capsules.
3. Implement `finalize()` to initialize memory and perform setup.

## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Define the static memory required for all objects used.**

   All objects in the kernel are statically allocated, so we need to statically
   allocate memory for the objects to live in. Due to [constraints](https://github.com/tock/tock/blob/b41ecd33a361d90820df1e290086d1b22e192e54/kernel/src/utilities/static_init.rs#L56-L80) on the macros
   Tock provides for statically allocating memory, we must contain all calls to
   allocate this memory within another macro.

   Create a file in `boards/components/src` to hold the component.

   We need to define a macro to setup our state. We will use the `static_buf!()`
   macro to help with this. In the file, create a macro with the name
   `<your capsule>_component_static`. This naming convention must be followed.

   In our hypothetical case, we need to allocate room for the notifier capsule
   and a buffer. Each capsule might need slightly different resources.

   ```rust
   #[macro_export]
   macro_rules! notifier_driver_component_static {
       ($A:ty $(,)?) => {{
           let notifier_buffer = kernel::static_buf!([u8; 16]);
           let notifier_driver = kernel::static_buf!(
               capsules_extra::notifier::NotifierDriver<'static, $A>
           );

           (notifier_buffer, notifier_driver)
       };};
   }
   ```

   Notice how the macro uses the type `$A` which is the type of the underlying
   alarm. We also use full paths to avoid errors when the macro is used. The
   macro then "returns" the two statically allocated resources.

2. **Create a struct that holds all of the resources and configuration necessary
   for the capsules.**

   Now we create the actual component object which collects all of the resources
   and any configuration needed to successfully setup this capsule.

   ```rust
   pub struct NotifierDriverComponent<A: 'static + time::Alarm<'static>> {
       board_kernel: &'static kernel::Kernel,
       driver_num: usize,
       alarm: &'static A,
       delay_ms: usize,
   }
   ```

   The component needs a reference to the board as well as the driver number to
   be used for this driver. This is to setup the grant, as we will see. If you
   are not setting up a syscall driver you will not need this. Finally we also
   need to keep track of the delay the kernel wants to use with this capsule.

   Next we can create a constructor for this component object:

   ```rust
   impl<A: 'static + time::Alarm<'static>> NotifierDriverComponent<A> {
       pub fn new(
           board_kernel: &'static kernel::Kernel,
           driver_num: usize,
           alarm: &'static A,
           delay_ms: usize,
       ) -> AlarmDriverComponent<A> {
           AlarmDriverComponent {
               board_kernel,
               driver_num,
               alarm,
               delay_ms,
           }
       }
   }
   ```

   Note, all configuration that is required must be passed in to this `new()`
   constructor.

3. **Implement `finalize()` to initialize memory and perform setup.**

   The last step is to implement the `Component` trait and the `finalize()`
   method to actually setup the capsule.

   The general format looks like:

   ```rust
   impl<A: 'static + time::Alarm<'static>> Component for NotifierDriverComponent<A> {
       type StaticInput = (...);
       type Output = ...;

       fn finalize(self, static_buffer: Self::StaticInput) -> Self::Output {}
   }
   ```

   We need to define what statically allocated types we need, and what this
   method will produce:

   ```rust
   impl<A: 'static + time::Alarm<'static>> Component for AlarmDriverComponent<A> {
       type StaticInput = (
           &'static mut MaybeUninit<[u8; 16]>,
           &'static mut MaybeUninit<NotifierDriver<'static, $A>>,
       );
       type Output = &'static NotifierDriver<'static, A>;

       fn finalize(self, static_buffer: Self::StaticInput) -> Self::Output {}
   }
   ```

   Notice that the static input types must match the output of the macro. The
   output type is what we are actually creating.

   Inside the `finalize()` method we need to initialize the static memory and
   configure/setup the capsules:

   ```rust
   impl<A: 'static + time::Alarm<'static>> Component for AlarmDriverComponent<A> {
       type StaticInput = (
           &'static mut MaybeUninit<[u8; 16]>,
           &'static mut MaybeUninit<NotifierDriver<'static, $A>>,
       );
       type Output = &'static NotifierDriver<'static, A>;

       fn finalize(self, static_buffer: Self::StaticInput) -> Self::Output {
       	 let grant_cap = create_capability!(capabilities::MemoryAllocationCapability);

       	 let buf = static_buffer.0.write([0; 16]);

       	 let notifier = static_buffer.1.write(NotifierDriver::new(
       	     self.alarm,
       	     self.board_kernel.create_grant(self.driver_num, &grant_cap),
       	     buf,
       	     self.delay_ms,
       	 ));

         // Very important we set the callback client correctly.
       	 self.alarm.set_client(notifier);

       	 notifier
       }
   }
   ```

   We initialize the memory for the static buffer, create the grant for the
   syscall driver to use, provide the driver with the alarm resource, and
   pass in the delay value to use. Lastly, we return a reference to the
   actual notifier driver object.

## Summary

Our full component looks like:

```rust
use core::mem::MaybeUninit;

use capsules_extra::notifier::NotifierDriver;
use kernel::capabilities;
use kernel::component::Component;
use kernel::create_capability;
use kernel::hil::time::{self, Alarm};

#[macro_export]
macro_rules! notifier_driver_component_static {
    ($A:ty $(,)?) => {{
        let notifier_buffer = kernel::static_buf!([u8; 16]);
        let notifier_driver = kernel::static_buf!(
            capsules_extra::notifier::NotifierDriver<'static, $A>
        );

        (notifier_buffer, notifier_driver)
    };};
}

pub struct NotifierDriverComponent<A: 'static + time::Alarm<'static>> {
    board_kernel: &'static kernel::Kernel,
    driver_num: usize,
    alarm: &'static A,
    delay_ms: usize,
}

impl<A: 'static + time::Alarm<'static>> NotifierDriverComponent<A> {
    pub fn new(
        board_kernel: &'static kernel::Kernel,
        driver_num: usize,
        alarm: &'static A,
        delay_ms: usize,
    ) -> AlarmDriverComponent<A> {
        AlarmDriverComponent {
            board_kernel,
            driver_num,
            alarm,
            delay_ms,
        }
    }
}

impl<A: 'static + time::Alarm<'static>> Component for AlarmDriverComponent<A> {
    type StaticInput = (
        &'static mut MaybeUninit<[u8; 16]>,
        &'static mut MaybeUninit<NotifierDriver<'static, $A>>,
    );
    type Output = &'static NotifierDriver<'static, A>;

    fn finalize(self, static_buffer: Self::StaticInput) -> Self::Output {
		let grant_cap = create_capability!(capabilities::MemoryAllocationCapability);

		let buf = static_buffer.0.write([0; 16]);

		let notifier = static_buffer.1.write(NotifierDriver::new(
			self.alarm,
			self.board_kernel.create_grant(self.driver_num, &grant_cap),
			buf,
			self.delay_ms,
		));

		// Very important we set the callback client correctly.
		self.alarm.set_client(notifier);

		notifier
    }
}
```

## Usage

In a board's main.rs file to use the component:

```rust
let notifier = components::notifier::NotifierDriverComponent::new(
    board_kernel,
    capsules_core::notifier::DRIVER_NUM,
    alarm,
    100,
)
.finalize(components::notifier_driver_component_static!(nrf52840::rtc::Rtc));
```

## Wrap-Up

Congratulations! You have created a component to easily create a resource in the
Tock kernel! We encourage you to submit a pull request to upstream this to the
Tock repository.
