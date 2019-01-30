## Tock's goals, architecture and components

![](imgs/architecture.svg)

A key contribution of Tock is that it uses Rust's borrow checker as a
language sandbox for isolation and a cooperative scheduling model for
concurrency in the kernel.  As a result, for the kernel isolation is
(more or less) free in terms of resource consumption at the expense of
preemptive scheduling (so a malicious component could block the system by,
e.g., spinning in an infinite loop).

Tock includes three architectural components:

  - A small trusted _core kernel_, written in Rust, that implements a hardware
    abstraction layer (HAL), scheduler, and platform-specific configuration.
  - _Capsules_, which are compiled with the kernel and use Rust's type and
    module systems for safety.
  - _Processes_, which use the memory protection unit (MPU) for protection at runtime.

[_Presentation slides are available here._](presentation/presentation.pdf)

Read the Tock documentation for more details on its
[design](https://github.com/tock/tock/blob/master/doc/Design.md).


### Check your understanding

1. What kinds of binaries exist on a Tock board? Hint: There are three, and
   only two can be programmed using `tockloader`.

2. What are the differences between capsules and processes? What performance
   and memory overhead does each entail? Why would you choose to write
   something as a process instead of a capsule and vice versa?

3. What happens if the core kernel enters an infinite loop? What about a
   process? What about a capsules?
