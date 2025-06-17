# Dynamic Application Loading and Secure Policies with Tock

Tock enables a host of security features not possible with other embedded system
OSes. Tock kernels can enforce strict isolation and least privilege for
applications through mechanisms including application signing, system call
filtering, and resource controls. Platforms running Tock can strongly reason
about the capabilities entrusted to each application.

Further, Tock platforms are designed to be dynamic, with applications updating
over time. Tock supports loading new applications at runtime without
interrupting existing processes.

This module will walk you through some of these features and how Tock supports
many security features not otherwise possible on resource-constrained embedded
systems.

## Goal

Traditionally, for an application to be installed on a Tock supported board, one
must use `tockloader`, a tool that offers users various ways to interact with
the OS. Typically, applications are installed using `tockloader install` which
writes the application to the board and restarts the device.

Imagine if your phone restarted each time you had to update an app!

To allow for a seamless application loading experience, in this tutorial we will
add required kernel components and a supporting userspace application that
enables Tock to live-update apps, without using `tockloader`, other external
tools, nor requiring a restart.

Then we will use cryptographic application signing to enforce per-process
security properties for running Tock applications.

## Hardware Notes

Any hardware that supports Tock should work, although this module will build on
the nrf52840dk board.

### nRF52840dk Hardware Setup

![nRF52840dk](../../imgs/nrf52840dk.jpg)

There are a couple of configurations on the nRF52840DK board that you should
double-check:

1. The "Power" switch in the corner near the USB should be set to "On".
2. The "nRF power source" switch in the middle of the board (under the screen)
   should be set to "VDD".
3. The "nRF ONLY | DEFAULT" switch on the side near the LEDs should be set to
   "DEFAULT".

## Organization and Getting Oriented to Tock

This module will refer to some Tock components. This section briefly describes
the general structure of Tock that you will need to be somewhat familiar with to
follow the module.

Using Tock consists of two main building blocks:

1. The Tock kernel, which runs as the operating system on the board. This is
   compiled from the [Tock repository](https://github.com/tock/tock).
2. Userspace applications, which run as processes and are compiled and loaded
   separately from the kernel.

The Tock kernel is compiled specifically for a particular hardware device,
termed a "board". The location of the top-level file for the kernel on a
specific board is in the Tock repository, under `/tock/boards/<board name>`. Any
time you need to compile the kernel or edit the board file, you will go to that
folder. You also install the kernel on the hardware board from that directory.

Userspace applications are stored in a separate repository, either
[libtock-c](https://github.com/tock/libtock-c) or
[libtock-rs](https://github.com/tock/libtock-rs) (for C and Rust applications,
respectively). Those applications are compiled within those repositories.

## Stages

These pre-setup is done for you if you are using the tutorial configuration for
the nRF52840dk board:
`tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies`. You can jump right
to the [Main Tutorial](#main-tutorial).

### Pre-setup

If you are using a different hardware platform, you will need to follow these
three setup guides first to add required support to the base kernel image
provided for a board by default:

1. [Dynamic App Load Setup](../setup/dynamic-app-loading.md).
2. [ECDSA Signature Verification](../setup/ecdsa.md).
3. [Screen Setup](../setup/screen.md)

> To get the screen functional for this tutorial, you need to make a minor
> change to the `apps_regions` variable:
>
> ```rust
> let apps_regions = kernel::static_init!(
>         [capsules_extra::screen_shared::AppScreenRegion; 3],
>         [
>             capsules_extra::screen_shared::AppScreenRegion::new(
>                 create_short_id_from_name("process_manager", 0x0),
>                 0,      // x
>                 0,      // y
>                 16 * 8, // width
>                 7 * 8   // height
>             ),
>             capsules_extra::screen_shared::AppScreenRegion::new(
>                 create_short_id_from_name("counter", 0x0),
>                 0,     // x
>                 7 * 8, // y
>                 8 * 8, // width
>                 1 * 8  // height
>             ),
>             capsules_extra::screen_shared::AppScreenRegion::new(
>                 create_short_id_from_name("temperature", 0x0),
>                 8 * 8, // x
>                 7 * 8, // y
>                 8 * 8, // width
>                 1 * 8  // height
>             )
>         ]
>     );
> ```

### Main Tutorial

This module is broken into 3 stages:

1. Experimenting with the
   [Process Manager userspace application](./process-manager.md).
2. Installing Applications with the
   [App loader helper application](./app-loader.md).
3. Exploring Security Mechanisms via [Syscall Filtering](./snooping.md)
