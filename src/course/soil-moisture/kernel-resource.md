# Resource Isolation Kernel Configuration

To improve our soil moisture sensor we are going to take advantage of another
Tock feature. In particular, we are going to restrict the kernel resources so
that only permitted apps can access the resources. Since we have a dedicated app
for reading the sensor, we are going to ensure that kernel permits only the
`soil-moisture-sensor` app to access the GPIO pin and ADC.

## Creating a Filter for Syscalls

To implement this, we use the `kernel::platform::SyscallFilter` interface which
allows a policy to permit or deny every syscall.

The interface has one function `filter_syscall()`:

```rust
trait kernel::platform::SyscallFilter {
    fn filter_syscall(
        &self,
        process: &dyn process::Process,
        syscall: &syscall::Syscall,
    ) -> Result<(), errorcode::ErrorCode>;
}
```

which is run before every syscall is executed. An implementation of this
function should return `Ok(())` to permit the syscall, and an `Err()` to prevent
the syscall from executing. The returned error will be returned to the
application.

1.  Create a new file in the board's src/ directory called `policy.rs`.

2.  We start by creating a struct to implement the `SyscallFilter` trait.

    ```rust
    use kernel::errorcode;
    use kernel::process;
    use kernel::syscall;

    pub struct SoilMoistureSyscallFilter {}

    impl kernel::platform::SyscallFilter for SoilMoistureSyscallFilter {
        fn filter_syscall(
            &self,
            process: &dyn process::Process,
            syscall: &syscall::Syscall,
        ) -> Result<(), errorcode::ErrorCode> {
            Ok(())
        }
    }
    ```

3.  Our first step is to permit all syscalls which are _not_ for the GPIO and
    ADC syscall interfaces for all applications. We can do this by matching on
    the `syscall` argument provided to `filter_syscall()` function. At this
    point we will just deny all GPIO and ADC accesses.

    ```rust
    use kernel::errorcode;
    use kernel::process;
    use kernel::syscall;

    pub struct SoilMoistureSyscallFilter {}

    impl kernel::platform::SyscallFilter for SoilMoistureSyscallFilter {
        fn filter_syscall(
            &self,
            process: &dyn process::Process,
            syscall: &syscall::Syscall,
        ) -> Result<(), errorcode::ErrorCode> {
            match syscall.driver_number() {
                Some(capsules_core::adc::DRIVER_NUM) | Some(capsules_core::gpio::DRIVER_NUM) => {
                    Err(errorcode::ErrorCode::NODEVICE)
                }
                _ => Ok(()),
            }
        }
    }
    ```

4.  Now we need a way to determine if the app calling the syscall is the app we
    want to permit to use GPIO and ADC. We do this by calculating the ShortId of
    the permitted app.

    ```rust
    let permitted = kernel::process::ShortId::Fixed(
        core::num::NonZeroU32::new(kernel::utilities::helpers::crc32_posix(
            "soil_moisture_sensor".as_bytes(),
        ))
        .unwrap(),
    );
    ```

    Then we can compare the app calling the syscall to `permitted` to determine
    if we should approve the GPIO/ADC syscall or not. If the syscall is for GPIO
    or ADC, then we check, and if the calling ShortId is the same as `permitted`
    we return `Ok(())`, otherwise we return `Err(ErrorCode::NODEVICE)`. This
    error makes it look like to the app that the GPIO/ADC syscalls are just not
    included on this kernel.

    ```rust
    use kernel::errorcode;
    use kernel::process;
    use kernel::syscall;

    pub struct SoilMoistureSyscallFilter {}

    impl kernel::platform::SyscallFilter for SoilMoistureSyscallFilter {
        fn filter_syscall(
            &self,
            process: &dyn process::Process,
            syscall: &syscall::Syscall,
        ) -> Result<(), errorcode::ErrorCode> {
            let permitted = kernel::process::ShortId::Fixed(
                core::num::NonZeroU32::new(kernel::utilities::helpers::crc32_posix(
                    "soil-moisture-sensor".as_bytes(),
                ))
                .unwrap(),
            );

            match syscall.driver_number() {
                Some(capsules_core::adc::DRIVER_NUM) | Some(capsules_core::gpio::DRIVER_NUM) => {
                    if process.short_app_id() == permitted {
                        Ok(())
                    } else {
                        Err(errorcode::ErrorCode::NODEVICE)
                    }
                }
                _ => Ok(()),
            }
        }
    }
    ```

We now have our syscall filtering policy!

## Use the Policy in the Kernel

Now that we have the policy we need to update our kernel definition to use the
policy.

1.  We need to include our `policy.rs` file in main.rs. This is easy enough:

    ```rust
    mod policy;
    ```

2.  Next we add the filter to our `Platform` struct:

    ```rust
    pub struct Platform {
        ...
        syscall_filter: &'static policy::SoilMoistureSyscallFilter,
        ...
    }
    ```

3.  We need to configure the core kernel loop to use our filter when syscalls
    are called. We do this by modifying the implementation of the
    `KernelResources` trait.

    ```rust
    impl KernelResources<nrf52::chip::NRF52<'static, Nrf52840DefaultPeripherals<'static>>>
        for Platform {
        ...
        type SyscallFilter = policy::SoilMoistureSyscallFilter;
        ...
        fn syscall_filter(&self) -> &Self::SyscallFilter {
            self.syscall_filter
        }
        ...
    }
    ```

4.  We also need to instantiate the policy and add it to the platform struct.

    ```rust
    //--------------------------------------------------------------------------
    // SYSCALL FILTERING
    //--------------------------------------------------------------------------

    let syscall_filter = static_init!(
        policy::SoilMoistureSyscallFilter,
        policy::SoilMoistureSyscallFilter {}
    );
    ```

    and

    ```rust
    let platform = Platform {
        ...
        syscall_filter,
        ...
    };
    ```

## Compile and Load

Our kernel is now configured to enforce process resource isolation. You can
compile and load the kernel.

## Testing The Isolation

To test that the isolation is successful, install another app which uses the ADC
syscall.

```
cd libtock-c/examples/tests/adc/adc
make
tockloader install
```

You should see that the app errors out as it does not have access to the ADC
syscall.
