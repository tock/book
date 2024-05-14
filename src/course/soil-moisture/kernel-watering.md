Soil Moisture Watering Instructions Kernel Configuration
=======

Our next task is to configure the kernel to support a third app, the
`soil-moisture-watering` watering instructions app. For this app we only need
minor changes to the kernel. Specifically, we only need to give the
`soil-moisture-watering` access to the screen so it can display instructions
when needed.

## Watering Screen Support

To do this, all we need to do is add to the `apps_regions` array. We will
give the remainder of the screen to the watering app.

Update your kernel like the following:


```rust
let apps_regions = static_init!(
    [capsules_extra::screen_shared::AppScreenRegion; 1],
    [
        capsules_extra::screen_shared::AppScreenRegion::new(
            kernel::process::ShortId::Fixed(
                core::num::NonZeroU32::new(crc("soil-moisture-display")).unwrap()
            ),
            0,      // x
            6 * 8,  // y
            16 * 8, // width
            2 * 8   // height
        ),
        capsules_extra::screen_shared::AppScreenRegion::new(
            kernel::process::ShortId::Fixed(
                core::num::NonZeroU32::new(crc("soil-moisture-watering")).unwrap()
            ),
            0,      // x
            0,      // y
            16 * 8, // width
            6 * 8   // height
        ),
    ]
);
```


## Wrap up

You can compile and load the kernel to support the next app.



