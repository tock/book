# Kernel Configuration

Because Tock is meant to run on various platforms (spanning multiple
architectures and various available peripherals), and with multiple use cases in
mind (for example, "production" vs. debug build with various levels of debugging
detail), Tock provides various configuration options so that each build can be
adapted to each use case. In general, there are three variants of kernel
configuration that Tock supports:

1. Per-board customization of kernel components. For example, choosing the
   scheduling algorithm the kernel uses. The [policies guide](../policies.md)
   goes into more depth on this configuration variant.
2. Crate-level composition of kernel code. Building a functional kernel consists
   of using several crates, and choosing specific crates can configure the
   kernel for a specific board or use case.
3. Compile-time configuration to conditionally compile certain kernel features.

Tock attempts to support these configuration variants while avoiding undue
confusion as to what exact code is being included in any particular kernel
compilation. Specifically, Tock tries to avoid pitfalls of "ifdef" conditional
code (which can be tricky to reason about which code is being include and to
suitable test).

## Crate-Level Configuration

Each level of abstraction (e.g. core kernel, CPU architecture, chip, board) has
its own crate. Configuring a board is then done by including the relevant crates
for the particular chip.

For example, many microcontrollers have a family of related chips. Depending on
which specific version of a MCU a board uses often makes subtle adjustments to
which peripherals are available. A board makes these configurations by careful
choosing which crates to include as dependencies. Consider a board which uses
the nRF52840 MCU, a version in the nRF52 family. It's board-level dependency
tree might look like:

```

                 ┌────────────────┐
                 │                │
                 │ Board Crate    │
                 │                │
                 └─────┬─────────┬┘
                       │         └───────┬───────────────┐
            ┌──► ┌─────┴────────┐     ┌──┴───────┐ ┌─────┴────┐
            │    │ nRF52840     │     │ Capsules │ │ Kernel   │
            │    └─────┬────────┘     └──────────┘ └──────────┘
            │      ┌───┴──────┐
            │      │ nRF52    │
      Chips │      └───┬──────┘
            │      ┌───┴──────┐
            │      │ nRF5     │
            └──►   └──────────┘
```

where choosing the specific chip-variant as a dependency configures the code
included in the kernel. These dependencies are expressed via normal Cargo crate
dependencies.

## Compile-Time Configuration Options

To facilitate fine-grained configuration of the kernel (for example to enable
syscall tracing), a `Config` struct is defined in `kernel/src/config.rs`. The
`Config` struct defines a collection of boolean values which can be imported
throughout the kernel crate to configure the behavior of the kernel. As these
values are `const` booleans, the compiler can statically optimize away any code
that is not used based on the settings in `Config`, while still checking syntax
and types.

To make it easier to configure the values in `Config`, the values of these
booleans are determined by cargo features. Individual boards can determine which
features of the kernel crate are included without users having to manually
modify the code in the kernel crate. Because of how feature unification works,
all features are off-by-default, so if the Tock kernel wants a default value for
a config option to be turning something on, the feature should be named
appropriately (e.g. the `no_debug_panics` feature is enabled to set the
`debug_panics` config option to `false`).

To enable any feature, modify the Cargo.toml in your board crate as follows:

```toml
[dependencies]
# Turn off debug_panics, turn on trace_syscalls
kernel = { path = "../../kernel", features = ["no_debug_panics", "trace_syscalls"]}
```

These features should not be set from any crate other than the top-level board
crate. If you prefer not to rely on the features, you can still directly modify
the boolean config value in kernel/src/config.rs if you prefer---this can be
easier when rapidly debugging on an upstream board, for example.

To use the configuration within the kernel crate, simply read the values. For
example, to use a boolean configuration, just use an `if` statement.
