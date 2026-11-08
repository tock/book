# Writing a DMA Peripheral Driver with `DmaSlice`

This guide shows how to write, or port, a chip peripheral driver that hands
memory buffers to DMA hardware. It uses the types in
`kernel::utilities::dma_slice` and the architecture-provided `DmaFence`
implementations. Most of it describes one pattern: wrap the buffer, start the
hardware, stop the hardware, unwrap the buffer. It also covers the mistakes
that are easy to make along the way.

The module documentation of
[`dma_slice`](https://github.com/tock/tock/blob/master/kernel/src/utilities/dma_slice.rs)
lists the exact soundness requirements of each type. Read it alongside this
guide: this guide tells you what to do, and the module documentation tells
you why.

## Why a plain slice is not enough

When a driver writes a buffer's address into a DMA register, the hardware
reads or writes that memory behind the compiler's back. Without extra care,
two things can go wrong:

- The compiler (or the CPU) may delay or reorder Rust's writes to the buffer
  until after the MMIO write that starts the transfer. The hardware then sends
  stale data.
- After the transfer, the compiler may assume the buffer still holds what Rust
  last wrote, and reuse a cached value instead of reading what the hardware
  wrote. Worse, if the driver hands a `&mut [u8]` back to a client while the
  hardware is still writing to it, two parties mutate the same memory, which
  is undefined behavior.

`core::sync::atomic::fence` does not solve this: it only orders atomic
operations, not plain memory accesses observed by another bus master.

The `DmaSlice` types solve it by:

1. Taking ownership of the buffer for the duration of the transfer, so no Rust
   code can touch it.
2. Issuing a `DmaFence::release` when the buffer is wrapped, so that all prior
   writes are visible to the hardware.
3. Issuing a `DmaFence::acquire` when the buffer is unwrapped, so that all
   writes by the hardware are visible to Rust.

## Choosing a type

| Type                  | Wraps                 | Hardware may write? | Unwrapping is |
|-----------------------|-----------------------|---------------------|---------------|
| `DmaSlice`            | `&[T]`                | No                  | safe (`get`)  |
| `DmaSliceMut`         | `&mut [T]`            | Yes                 | `unsafe` (`take`) |
| `DmaSubSlice`         | `SubSlice<T>`         | No                  | safe (`as_sub_slice`) |
| `DmaSubSliceMut`      | `SubSliceMut<T>`      | Yes                 | `unsafe` (`take`) |
| `DmaSubSliceMutImmut` | `SubSliceMutImmut<T>` | No                  | safe (`take`) |

Some guidelines:

- **Prefer the `SubSlice` variants.** More and more Tock subsystems pass
  buffers as `SubSlice`/`SubSliceMut`, and the active range of the sub slice
  is a natural way for a client to say how much to transfer. Accepting a
  `SubSliceMut<'static, u8>` in your driver's API usually replaces a separate
  `len` argument.
- **Use `DmaSubSliceMut` whenever the hardware writes to the buffer** (receive,
  memory-to-memory destination). It is also fine for a buffer the hardware only
  reads, as long as the client gave you a mutable buffer.
- **Use `DmaSubSliceMutImmut` for read-only transfers that should accept
  either kind of buffer**, for example sending a constant from flash or a
  client's mutable buffer. See `chips/stm32u5xx/src/hash/hash.rs`.
- `T` must implement the sealed `ImmutableFromIntoBytes` trait. Currently that
  is `u8`, `u16` and `u32`.

## Getting a `DmaFence`

Every constructor and `take` call needs a `DmaFence`. The architecture crates
provide one each:

- `cortexm::dma_fence::CortexMDmaFence` (currently re-exported as
  `cortexm4f::dma_fence` and `cortexm33::dma_fence`; other Cortex-M arch crates
  need a one-line `pub use cortexm::dma_fence;` to expose it)
- `riscv::dma_fence::RiscvCoherentDmaFence`
- `x86::dma_fence::X86DmaFence`

Their constructors are `unsafe`. By calling one, you assert that this fence is
correct for your chip: for instance, the RISC-V and x86 fences are not
sufficient for non-coherent DMA or write-combining memory, and the Cortex-M
fence assumes no data cache in front of the memory the DMA engine accesses.
Check your chip's reference manual and write down why the fence fits in the
`// SAFETY:` comment.

Fences are zero-sized and `Copy`. You can create one each time you need it
(as `chips/nrf52/src/uarte.rs` does), or create one in your driver's
constructor and store it in the struct, so that the `unsafe` block and its
justification exist only once (as `chips/lpc55s6x/src/dma.rs` does):

```rust
pub struct MyDma<'a> {
    fence: CortexMDmaFence,
    buffer: MapCell<DmaSubSliceMut<'static, u8>>,
    // ...
}

impl<'a> MyDma<'a> {
    /// # Safety
    ///
    /// This constructor must be called at most once, and no other code may
    /// access the DMA registers of this peripheral. See "Uniqueness" below.
    pub unsafe fn new() -> Self {
        // SAFETY: This chip has a Cortex-M4 core and no data cache, so
        // `CortexMDmaFence` is a correct `DmaFence` for it.
        let fence = unsafe { CortexMDmaFence::new() };
        Self {
            fence,
            buffer: MapCell::empty(),
            // ...
        }
    }
}
```

## The lifecycle of a transfer

### 1. Validate before wrapping

Check everything that can fail (busy, length, alignment, peripheral enabled)
while you still hold the plain `SubSliceMut`. If you wrap the buffer first and
then find an error, getting the buffer back requires an `unsafe` `take`, with
a justification that no transfer was started. Validating first lets you return
the buffer in the `Err` without any `unsafe`:

```rust
pub fn start(
    &self,
    buffer: SubSliceMut<'static, u8>,
) -> Result<(), (ErrorCode, SubSliceMut<'static, u8>)> {
    if self.buffer.is_some() {
        return Err((ErrorCode::BUSY, buffer));
    }
    if buffer.len() == 0 || buffer.len() > MAX_LEN {
        return Err((ErrorCode::SIZE, buffer));
    }
    // ...
```

Use the address of the sub slice's *active range* (`buffer.as_ptr().addr()`)
for alignment checks, not the start of the underlying slice.

### 2. Wrap the buffer, then program the hardware

Create the `DmaSubSliceMut` **before** any MMIO write that may start the
transfer. Construction issues the release fence, so the order matters. Take
the address and length from the wrapped value:

```rust
    let dma_buf = DmaSubSliceMut::new_static(buffer, self.fence);

    self.registers.ptr.set(dma_buf.ptr_addr() as u32);
    self.registers.len.set(dma_buf.len() as u32);
```

`ptr_addr()` returns the address without exposing pointer provenance, which is
what you want for a value that only goes into a register.

`new_static` is safe for `'static` buffers. For non-`'static` buffers there is
an `unsafe` `new`: dropping such a wrapper would hand the memory back to its
owner without waiting for the hardware, so the caller must promise to always
call `take`. Driver APIs should almost always take `'static` buffers.

### 3. Store the wrapper, then start

Store the wrapper in the driver (a `MapCell` works well) so it lives for the
whole transfer, then issue the MMIO write that starts the hardware:

```rust
    self.buffer.replace(dma_buf);
    self.registers.task_start.write(Task::ENABLE::SET);
    Ok(())
}
```

**Other memory the hardware reads needs a fence too.** If your controller
reads descriptors, linked lists or queue structures from RAM, those are DMA
buffers as well. Either wrap them in a `DmaSlice` type, or issue a
`release` on them yourself before the start write:

```rust
// Make the descriptor writes above visible to the controller.
self.fence
    .release(ptr::from_ref(core::slice::from_ref(self.descriptor)).cast_mut());
self.registers.trigger.set(1);
```

### 4. Make sure the hardware has really stopped

`take` is `unsafe` because you promise that the hardware will not access the
buffer any more. "The interrupt fired" is not always enough. Check your
reference manual for:

- Whether the completion flag is set when the *last item is issued* or when it
  has *landed in memory*. Many controllers have a pipeline: a channel can
  signal completion while a write is still in flight. Look for a busy or
  active status bit and wait for it to clear.
- How to stop a transfer early (abort, cancel, timeout). Disabling a channel
  usually stops new operations, but operations already in the pipeline still
  complete. Again, wait for the busy bit.

Put the wait in the one function that every path uses to stop the hardware,
so that no path can forget it:

```rust
fn disable(&self) {
    self.registers.enableclr.set(self.mask());
    while self.registers.busy.get() & self.mask() != 0 {
        core::hint::spin_loop();
    }
}
```

### 5. Unwrap and return the buffer

Once the hardware has stopped, `take` the buffer back. This issues the acquire
fence, so the hardware's writes are now visible to Rust. Then hand the
buffer to the client:

```rust
fn handle_interrupt(&self) {
    self.disable();
    if let Some(dma_buf) = self.buffer.take() {
        // SAFETY: `disable` waited until the busy flag cleared, so the
        // hardware no longer accesses the buffer.
        let buffer = unsafe { dma_buf.take(self.fence) };
        self.client.map(|client| client.transfer_done(buffer, Ok(())));
    }
}
```

`take` restores the `SubSliceMut` with the same active range it had when it
was wrapped. If the hardware reports how many bytes it actually moved, report
that as a separate value, or shrink the active range before passing the
buffer on.

## Pitfalls

### Deciding completion from a stale snapshot

A client callback can start a new transfer, including on another channel or
instance of your driver. If your interrupt handler reads a status register
once and then loops over several channels, calling callbacks as it goes, a
callback for channel 1 may restart channel 2. The handler then reaches channel
2, still sees the old "done" bit in its snapshot, and hands the new transfer's
buffer back while the hardware is using it.

Read the status for each channel right before you act on it, and clear only
the flags you read:

```rust
for channel in &self.channels {
    let mask = channel.mask();
    let done = self.registers.done.get() & mask;
    if done == 0 {
        continue;
    }
    // Clear before the callback, so a transfer the callback starts keeps
    // its own flag.
    self.registers.done.set(done);
    channel.complete();
}
```

Similarly, when an abort clears a channel's flags, it prevents a stale flag
from being taken for the next transfer.

### Uniqueness

The safety of the whole scheme relies on the driver being the only code that
programs the DMA hardware. If two instances of your driver exist for the same
peripheral, one can start a transfer into memory the other has already handed
back to Rust. Make the constructor `unsafe`, and document in a `# Safety`
section that it must be called at most once and that no other code may access
the DMA registers. Whatever constructs it, such as the chip's default
peripherals, then becomes `unsafe` in turn. See
`chips/nrf52/src/uarte.rs` and `chips/nrf52/src/chip.rs`.

### Dropping a wrapper

Never drop a `DmaSubSliceMut` or `DmaSliceMut`. Make sure every path, including
errors and aborts, either returns the wrapper to a `MapCell` or calls `take`.

### Peripheral-side registers

A DMA transfer between memory and a peripheral also touches the peripheral's
data register (for example a UART FIFO). That access does not involve Rust
memory, so it usually does not make your function `unsafe`. The register
address should be computed by the driver, never supplied by the caller. It
can still interfere with the peripheral's own driver, so document those
requirements in a `# Safety Considerations` section on the safe function.

## Checklist

- [ ] The public API takes `SubSliceMut<'static, u8>` (or `SubSlice` /
      `SubSliceMutImmut` for read-only transfers) and returns it on error.
- [ ] All validation happens before the buffer is wrapped.
- [ ] The buffer is wrapped before the MMIO write that starts the transfer.
- [ ] Any other memory the hardware reads (descriptors, queues) is released
      with the fence too.
- [ ] The wrapper is stored in the driver for the whole transfer.
- [ ] Every path that stops the hardware waits until it is really idle.
- [ ] `take` is only called after that, with a `// SAFETY:` comment saying
      why the hardware is idle.
- [ ] Interrupt handlers read status flags right before acting on them.
- [ ] The driver's constructor is `unsafe` and documents uniqueness.
- [ ] The fence's `unsafe` constructor has a `// SAFETY:` comment explaining
      why it fits the chip.

## Examples in the tree

- `chips/nrf52/src/uarte.rs`: UART TX and RX with `DmaSubSliceMut`, the
  simplest example.
- `chips/stm32u5xx/src/usart.rs`, `i2c.rs`, `spi.rs`: peripherals driven by a
  separate DMA controller.
- `chips/stm32u5xx/src/hash/hash.rs`: read-only transfers with
  `DmaSubSliceMutImmut`, accepting both mutable and immutable buffers.
- `chips/virtio/src/queues/split_queue.rs`: VirtIO queues, mixing device-
  readable and device-writable buffers.
- `chips/lpc55s6x/src/dma.rs`: a general-purpose DMA controller with several
  channels, memory-to-memory and peripheral transfers, descriptors in RAM, and
  abort.

