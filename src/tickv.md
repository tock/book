# TicKV Key-Value Store

[TicKV](https://github.com/tock/tock/tree/master/libraries/tickv) is a
flash-optimized key-value store written in Rust. Tock supports using TicKV
within the OS to enable the kernel _and_ processes to store and retrieve
key-value objects in local flash memory.

## TicKV Structure and Format

TicKV can store 8 byte keys and values up to 2037 bytes. TicKV is page-based,
meaning that each object is stored entirely on a single page in flash.

> Note: for familiarity, we use the term "page", but in actuality TicKV uses the
> size of the smallest _erasable_ region, not necessarily the actual size of a
> page in the flash memory.

Each object is assigned to a page based on the lowest 16 bits of the key:

```text
object_page_index = (key & 0xFFFF) % <number of pages>
```

Each object in TicKV has the following structure:

```text
0        3            11                  (bytes)
---------------------------------- ... -
| Header | Key        | Value          |
---------------------------------- ... -
```

The header has this structure:

```text
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4    (bits)
-------------------------------------------------
| Version=1     |V| res | Length                |
-------------------------------------------------
```

- `Version`: Format of the object, currently this is always 1.
- `Valid (V)`: 1 if this object is valid, 0 otherwise. This is set to 0 to
  delete an object.
- `Length (Len)`: The total length of the object, including the length of the
  header (3 bytes), key (8 bytes), and value.

Subsequent keys either start at the first byte of a page or immediately after
another object.