# Types

Certain types within the Tock kernel are chosen very deliberately. This aids
with clarity on how the kernel works and helps with porting to new platforms.

## Integer Types

Many kernel interfaces use integer types (e.g., `usize` or `u32`). These types
are often used because the contained value must fit in a hardware register,
represents a memory address, or is a fixed width in an interface specification.
The kernel should use these types very deliberately depending on the meaning of
the underlying value.

- Fixed-width integers (e.g., `u32`, `u8`, etc.): These types should be used
  when the value is meant to be precisely the specified number of bits and the
  width restriction has a particular semantic meaning. For example, this could
  be a timer value used within a system call interface, or a field in a TBF
  header.
- Machine-sized types (e.g., `usize`): These types should be used for a value
  that should fit exactly into a register, like a abstract argument to the
  `command` syscall.
- Constant pointer (e.g., `*const u8`): These types should be used for a value
  that refers to an address but userspace does not have access to. For example,
  this could be the intended new boundary of the heap after calling `brk`.
- Authenticated pointer (e.g., `AuthenticatedPtr`): This type should be used for
  a pointer that is provided to userspace. These pointers, on some systems,
  include additional information which allows userspace to dereference the
  pointer. On other systems this behaves as a traditional pointer. With any
  underlying implementation, this type expresses that the value is a pointer
  that userspace uses.
