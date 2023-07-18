# TicKV Key-Value Store

[TicKV](https://github.com/tock/tock/tree/master/libraries/tickv) is a
flash-optimized key-value store written in Rust. Tock supports using TicKV
within the OS to enable the kernel _and_ processes to store and retrieve
key-value objects in local flash memory.

## TicKV and Key-Value Design

This section provides a quick overview of the TicKV and Key-Value stack in Tock.

### TicKV Structure and Format

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
another object. If a key cannot fit on the page assigned by the
`object_page_index`, it is stored on the next page with sufficient room.

Objects are updated in TicKV by invalidating the existing object (setting the
`V` flag to 0) and then writing the new value as a new object. This removes the
need to erase and re-write an entire page of flash to update a specific value.

### TicKV on Tock Format

The previous section describes the generic format of TicKV. Tock builds upon
this format by adding a header to the value buffer to add additional features.

The full object format for TicKV objects in Tock has the following structure:

```text
0        3            11  12       16       20              (bytes)
------------------------------------------------ ... ----
| TicKV  | Key        |Ver| Length | Write  |   Value   |
| Header |            |   |        |  ID    |           |
------------------------------------------------ ... ----
<--TicKV Header+Key--><--Tock TicKV Header+Value-...---->
```

- `Version (Ver)`: One byte version of the Tock header. Currently 0.
- `Length`: Four byte length of the value.
- `Write ID`: Four byte identifier for restricting access to this object.

The central addition is the `Write ID`, which is a `u32` indicating the
identifier of the writer that added the key-value object. The write ID of 0 is
reserved for the kernel to use. Each process can be assigned using TBF headers
its own write ID to use for storing state, such as in a TicKV database. Each
process and the kernel can then be granted specific read and update permissions,
based on the stored write ID. If a process has read permissions for the specific
ID stored in the `Write ID` field, then it can access that key-value object. If
a process has update permissions for the specific ID stored in the `Write ID`
field, then it can change the value of that key-value object.

### Tock Key-Value APIs

Tock supports two key-value orientated APIs: an upper and lower API. The lower
API expects hashed keys and is designed with flash as the underlying storage in
mind. The upper API is a more traditional K-V interface.

The lower interface looks like this. Note, this version is simplified for
illustration, the actual version is complete Rust.

```rust
pub trait KVSystem {
    /// The type of the hashed key. For example `[u8; 8]`.
    type K: KeyType;

    /// Create the hashed key.
    fn generate_key(&self, unhashed_key: [u8], key: K) -> Result<(), (K, buffer,ErrorCode)>;

    /// Add a K-V object to the store. Error on collision.
    fn append_key(&self, key: K, value: [u8]) -> Result<(), (K, buffer, ErrorCode)>;

    /// Retrieve a value from the store.
    fn get_value(&self, key: K, value: [u8]) -> Result<(), (K, buffer, ErrorCode)>;

    /// Mark a K-V object as deleted.
    fn invalidate_key(&self, key: K) -> Result<(), (K, ErrorCode)>;

    /// Cleanup the store.
    fn garbage_collect(&self) -> Result<(), ErrorCode>;
}
```

(You can find the full definition in `tock/kernel/src/hil/kv_system.rs`.)

In terms of TicKV, the `KVSystem` interface only uses the TicKV header. The Tock
header is only used in the upper level API.

```rust
pub trait KVStore {
    /// Get key-value object.
    pub fn get(&self, key: [u8], value: [u8], perms: StoragePermissions) -> Result<(), (buffer, buffer, ErrorCode)>;

    /// Set or update a key-value object.
    pub fn set(&self, key: [u8], value: [u8], perms: StoragePermissions) -> Result<(), (buffer, buffer, ErrorCode)>;

    /// Delete a key-value object.
    pub fn delete(&self, key: [u8], perms: StoragePermissions) -> Result<(), (buffer, ErrorCode)>;
}
```

As you can see, each of these APIs requires a `StoragePermissions` so the
capsule can verify that the requestor has access to the given K-V object.

## Key-Value in Userspace

Userspace applications have access to the K-V store via the `kv_driver.rs`
capsule. This capsule provides an interface for applications to use the upper
layer get-set-delete API.

However, applications need permission to use persistent storage. This is granted
via headers in the TBF header for the application.

Applications have three fields for permissions: a write ID, multiple read IDs,
and multiple modify IDs.

- `write_id: u32`: This u32 specifies the ID used when the application creates a
  new K-V object. If this is 0, then the application does not have write access.
  (A `write_id` of 0 is reserved for the kernel.)
- `read_ids: [u32]`: These read IDs specify which k-v objects the application
  can call `get()` on. If this is empty or does not include the application's
  `write_id`, then the application will not be able to retrieve its own objects.
- `modify_ids: [u32]`: These modify IDs specify which k-v objects the
  application can edit, either by replacing or deleting. Again, if this is empty
  or does not include the application's `write_id`, then the application will
  not be able to update or delete its own objects.

These headers can be added at compilation time with `elf2tab` or after the TAB
has been created using Tockloader.

To have elf2tab add the header, it needs to be run with additional flags:

```
elf2tab ... --write_id 10 --read_ids 10,11,12 --access_ids 10,11,12 <list of ELFs>
```

To add it with tockloader (run in the app directory):

```
tockloader tbf tlv add persistent_acl 10 10,11,12 10,11,12
```

### Using K-V Storage

To use the K-V storage, load the kv-interactive app:

```
cd libtock-c/examples/tests/kv_interactive
make
tockloader tbf tlv add persistent_acl 10 10,11,12 10,11,12
tockloader install
```

Now via the terminal, you can create and view k-v objects by typing `set`,
`get`, or `delete`.

```
$ tockloader listen
set mykey hello
Setting mykey=hello
Set key-value
get mykey
Getting mykey
Got value: hello
delete mykey
Deleting mykey
```

## Managing TicKV Database on your Host Computer

You can interact with a board's k-v store via tockloader on your host computer.

### View the Contents

To view the entire DB:

```
tockloader tickv dump
```

Which should give something like:

```
[INFO   ] Using jlink channel to communicate with the board.
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[STATUS ] Dumping entire TicKV database...
[INFO   ] Using settings from KNOWN_BOARDS["nrf52dk"]
[INFO   ] Dumping entire contents of Tock-style TicKV database.
REGION 0
TicKV Object hash=0xbbba2623865c92c0 version=1 flags=8 length=24 valid=True checksum=0xe83988e0
  Value: 00000000000b000000
  TockTicKV Object version=0 write_id=11 length=0
    Value:

REGION 1
TicKV Object hash=0x57b15d172140dec1 version=1 flags=8 length=28 valid=True checksum=0x32542292
  Value: 00040000000700000038313931
  TockTicKV Object version=0 write_id=7 length=4
    Value: 38313931

REGION 2
TicKV Object hash=0x71a99997e4830ae2 version=1 flags=8 length=28 valid=True checksum=0xbdc01378
  Value: 000400000000000000000000ca
  TockTicKV Object version=0 write_id=0 length=4
    Value: 000000ca

REGION 3
TicKV Object hash=0x3df8e4a919ddb323 version=1 flags=8 length=30 valid=True checksum=0x70121c6a
  Value: 0006000000070000006b6579313233
  TockTicKV Object version=0 write_id=7 length=6
    Value: 6b6579313233

REGION 4
TicKV Object hash=0x7bc9f7ff4f76f244 version=1 flags=8 length=15 valid=True checksum=0x1d7432bb
  Value:
TicKV Object hash=0x9efe426e86d82864 version=1 flags=8 length=79 valid=True checksum=0xd2ac393f
  Value: 001000000000000000a2a4a6a6a8aaacaec2c4c6c6c8caccce000000000000000000000000000000000000000000000000000000000000000000000000000000
  TockTicKV Object version=0 write_id=0 length=16
    Value: a2a4a6a6a8aaacaec2c4c6c6c8caccce

REGION 5
TicKV Object hash=0xa64cf33980ee8805 version=1 flags=8 length=29 valid=True checksum=0xa472da90
  Value: 0005000000070000006d796b6579
  TockTicKV Object version=0 write_id=7 length=5
    Value: 6d796b6579

REGION 6
TicKV Object hash=0xf17b4d392287c6e6 version=1 flags=8 length=79 valid=True checksum=0x854d8de0
  Value: 00030000000700000033343500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
  TockTicKV Object version=0 write_id=7 length=3
    Value: 333435

...

[INFO   ] Finished in 3.468 seconds
```

You can see all of the hashed keys and stored values, as well as their headers.

### Add a Key-Value Object

You can add a k-v object using tockloader:

```
tockloader tickv append newkey newvalue
```

Note that by default tockloader uses a `write_id` of 0, so that k-v object will
only be accessible to the kernel. To specify a specific `write_id` so an app can
access it:

```
tockloader tickv append appkey appvalue --write-id 10
```

## Wrap-Up

You now know how to use a Key-Value store in your Tock apps as well as in the
kernel. Tock's K-V stack supports access control on stored objects, and can be
used simultaneously by both the kernel and userspace applications.
