# Implementing a HIL Interface

This guide describes the process of creating a new HIL interface in Tock. "HIL"s
are one or more Rust traits that provide a standard and shared interface between
pieces of the Tock kernel.

## Background

The most canonical use for a HIL is to provide an interface to hardware
peripherals to capsules. For example, a HIL for SPI provides an interface
between the SPI hardware peripheral in a microcontroller and a capsule that
needs a SPI bus for its operation. The HIL is a generic interface, so that same
capsule can work on different microcontrollers, as long as each microcontroller
implements the SPI HIL.

HILs are also used for other generic kernel interfaces that are relevant to
capsules. For example, Tock defines a HIL for a "temperature sensor". While a
temperature sensor is not generally a hardware peripheral, a capsule may want to
use a generic temperature sensor interface and not be restricted to using a
particular temperature sensor driver. Having a HIL allows the capsule to use a
generic interface. For consistency, these HILs are also specified in the kernel
crate.

> Note: In the future Tock will likely split these interface types into separate
> groups.

HIL development often significantly differs from other development in Tock. In
particular, HILs can often be written quickly, but tend to take numerous
iterations over relatively long periods of time to refine. This happens for
three general reasons:

1. HILs are intended to be generic, and therefore implementable by a range of
   different hardware platforms. Designing an interface that works for a range
   of different hardware takes time and experience with various MCUs, and often
   incompatibilities aren't discovered until an implementation proves to be
   difficult (or impossible).
2. HILs are Rust traits, and Rust traits are reasonably complex and offer a fair
   bit of flexibility. Balancing both leveraging the flexibility Rust provides
   and avoiding undue complexity takes time. Again, often trial-and-error is
   required to settle on how traits should be composed to best capture the
   interface.
3. HILs are intended to be generic, and therefore will be used in a variety of
   different use cases. Ensuring that the HIL is expressive enough for a diverse
   set of uses takes time. Again, often the set of uses is not known initially,
   and HILs often have to be revised as new use cases are discovered.

Therefore, we consider HILs to be evolving interfaces.

## Tips on HIL Development

As getting a HIL interface "correct" is difficult, Tock tends to prefer starting
with simple HIL interfaces that are typically inspired by the hardware used when
the HIL is initially created. Trying to generalize a HIL too early can lead to
complexity that is never actually warranted, or complexity that didn't actually
address a problem.

Also, Tock prefers to only include code (or in this case HIL interface
functions) that are actually in use by the Tock code base. This ensures that
there is at least some method of using or testing various components of Tock.
This also suggests that initial HIL development should only focus on an interface
that is needed by the initial use case.


## Overview

The high-level steps required are:

1. Determine that a new HIL interface is needed.
2. Create the new HIL in the kernel crate.
3. Ensure the HIL file includes sufficient documentation.


## Step-by-Step Guide

The steps from the overview are elaborated on here.

1. **Determine that a new HIL interface is needed.**

    Tock includes a number of existing HIL interfaces, and modifying an existing
    HIL is preferred to creating a new HIL that is similar to an existing
    interface. Therefore, you should start by verifying an existing HIL does not
    already meet your need or could be modified to meet your need.

    This may seem to be a straightforward step, but it can be complicated by
    microcontrollers calling similar functionality by different names, and the
    existing HIL using a standard name or a different name from another
    microcontroller.

    Also, you can reach out via the email list or slack if you have questions
    about whether a new HIL is needed or an existing one should suffice.

2. **Create the new HIL in the kernel crate.**

    Once you have determined a new HIL is required, you should create
    the appropriate file in `kernel/src/hil`. Often the best way to start is
    to copy an existing HIL that is similar in nature to the interface you are
    trying to create.

    As noted above, HILs evolve over time, and HILs will be periodically updated
    as issues are discovered or best practices for HIL design are learned.
    Unfortunately, this means that copying an existing HIL might lead to
    "mistakes" that must be remedied before the new HIL can be merged.

    Likely, it is helpful to open a pull request relatively early in the HIL
    creation process so that any substantial issues can be detected and
    corrected quickly.

    Tock has a [reference
    guide](https://github.com/tock/tock/blob/master/doc/reference/trd-hil-design.md)
    for dos and don'ts when creating a HIL. Following this guide can help avoid
    many of the pitfalls that we have run into when creating HILs in the past.

    Tock only uses **non-blocking** interfaces in the kernel, and HILs should
    reflect that as well. Therefore, for any operation that will take more than
    a couple cycles to complete, or would require waiting on a hardware flag,
    a split interface design should be used with a `Client` trait that receives
    a callback when the operation has completed.

3. **Ensure the HIL file includes sufficient documentation.**

    HIL files should be well commented with Rustdoc style (i.e. `///`) comments.
    These comments are the main source of documentation for HILs.

    As HILs grow in complexity or stability, they will be documented separately
    to fully explain their design and intended use cases.

## Wrap-Up

Congratulations! You have implemented a new HIL in Tock! We encourage you to
submit a pull request to upstream this to the Tock repository.
