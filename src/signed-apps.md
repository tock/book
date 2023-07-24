# RSA Signed Apps

> Note: this module is **experimental** (as of July 2023). It requires a kernel
> with https://github.com/tock/tock/pull/3445 (or its successor).

For a Tock board to trust the applications it is running, the kernel can verify
that the app was signed with a trusted private key. Tock supports RSA
signatures, and this module describes how to sign apps with RSA signatures and
how to verify those signatures before executing apps.


## Trusting Apps

To configure the kernel to verify apps, and check if we trust them or not,
requires us to add a couple pieces:

- We need to actually sign the apps with our private key and include the
  signature when we load apps to the board so the kernel can check the
  signature.
- We need a mechanism in the kernel to check the signatures.
- We need the kernel to know the matching public key to verify the signatures.

### Signing Apps

We can use Tockloader to sign a compiled app. But first, we need RSA keys to use
for the signature. We can generate suitable keys with `openssl`:

```
$ openssl genrsa -aes128 -out tockkey.private.pem 2048
$ openssl rsa -in tockkey.private.pem -outform der -out tockkey.private.der
$ openssl rsa -in tockkey.private.pem -outform der -pubout -out tockkey.public.der
```

You should now have three key files (although we only need the `.der` files):

- `tockkey.private.pem`
- `tockkey.private.der`
- `tockkey.public.der`

Now, to add an RSA signature to an app, we first build the app and then add the
`rsa2048` credential. It shouldn't matter which app you want to use, but for
simplicity we'll use `blink` as an example.

First, compile the app:

```
$ cd libtock-c/examples/blink
$ make
```

Now, add the credential:

```
$ tockloader tbf credential add rsa2048 --private-key tockkey.private.der --public-key tockkey.public.der
```

It's fine to add to all architectures or you can specify which TBF to add it to.

To check that the credential was added, we can inspect the TAB:

```
$ tockloader inspect-tab
```

You should see output like the following:

```
$ tockloader inspect-tab
[INFO   ] No TABs passed to tockloader.
[STATUS ] Searching for TABs in subdirectories.
[INFO   ] Using: ['./build/blink.tab']
[STATUS ] Inspecting TABs...
TAB: blink
  build-date: 2023-06-09 21:52:59+00:00
  minimum-tock-kernel-version: 2.0
  tab-version: 1
  included architectures: cortex-m0, cortex-m3, cortex-m4, cortex-m7

 Which TBF to inspect further? cortex-m4

cortex-m4:
  version               : 2
  header_size           :         76         0x4c
  total_size            :       8192       0x2000
  checksum              :              0x6e3c4aff
  flags                 :          1          0x1
    enabled             : Yes
    sticky              : No
  TLV: Main (1)                                   [0x10 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       4604       0x11fc
  TLV: Program (9)                                [0x20 ]
    init_fn_offset      :         41         0x29
    protected_size      :          0          0x0
    minimum_ram_size    :       4604       0x11fc
    binary_end_offset   :       1780        0x6f4
    app_version         :          0          0x0
  TLV: Package Name (3)                           [0x38 ]
    package_name        : blink
  TLV: Kernel Version (8)                         [0x44 ]
    kernel_major        : 2
    kernel_minor        : 0
    kernel version      : ^2.0

TBF Footers
  Footer
    footer_size         :       6412       0x190c
  Footer TLV: Credentials (128)
    Type: RSA2048 (10)
    Length: 256
  Footer TLV: Credentials (128)
    Type: Reserved (0)
    Length: 6140
```

Note at the bottom, there is a `Footer TLV` with RSA2048 credentials! To verify
they were added correctly, we can run `tockloader inspect-tab` with
`--verify-credentials`:

```
$ tockloader inspect-tab --verify-credentials tockkey.private.der
```

There will now be a `✓ verified` next to the RSA2048 credential showing that the
stored credential matches what it should compute to.

> **SUCCESS:** We now have a signed app!