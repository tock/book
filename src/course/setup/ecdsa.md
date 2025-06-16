# Signing Apps with ECDSA Signatures

Tock applications can be signed with a cryptographic signature to verify the
authenticity of the application. This guide describes how to use ECDSA with the
P256R1 curve to sign Tock applications.

## Generating an ECDSA Key Pair

The first step is creating a public-private key pair for the signature. We can
do that with `openssl`:

```bash
$ openssl ecparam -name secp256r1 -genkey -noout -out ec-secp256r1-priv.pem
$ openssl ec -in ec-secp256r1-priv.pem -pubout -out ec-secp256r1-pub.pem
```

Once created, we can view the key:

```bash
$ openssl ec -in ec-secp256r1-priv.pem -text -noout
```

Note the "pub" key is encoded in `sec1` format.

## Signing a Tock App

There are two ways to sign a Tock app with the private key: (1) adding the
signature when the `.tbf` is created with `elf2tab` or (2) adding the signature
with tockloader.

### Approach 1: Using `elf2tab`

First, we need to convert the private key from `sec1` format to the `pk8` format
that `elf2tab` expects. We can do this with `openssl`:

```bash
$ openssl pkcs8 -in ec-secp256r1-priv.pem -topk8 -nocrypt -outform der > ec-secp256r1-priv.p8
```

Now we can pass that key to `elf2tab` as a command line argument. This works
best if you are running `elf2tab` directly or if you have a custom build setup
for Tock applications.

```bash
$ elf2tab ... --ecdsa-nist-p256-private ec-secp256r1-priv.p8 ...
```

If you are using `libtock-c`, you can have an app compiled and the signature
includes by modifying the app's Makefile. Add the following line to the
Makefile:

```make
ELF2TAB_ARGS += --ecdsa-nist-p256-private ec-secp256r1-priv.p8
```

### Approach 2: Using tockloader

If you have an existing Tock app compiled into the `.tab` format, you can add
the ECDSA signature to the `.tbf` files within the existing `.tab`. To add the
signature, run the following command in the directory with your existing app:

```bash
$ tockloader tbf credential add ecdsap256 --private-key ec-secp256r1-priv.pem
```

## Verifying the Signature in the Kernel

To instruct the kernel to verify signatures when loading apps, we need to use
the signature verifier capsule with the ECDSA-P256 verifier.

First, we setup the types at the top of main.rs:

```rust
type Verifier = ecdsa_sw::p256_verifier::EcdsaP256SignatureVerifier<'static>;
type SignatureVerifyInMemoryKeys =
    components::signature_verify_in_memory_keys::SignatureVerifyInMemoryKeysComponentType<
        Verifier,
        1,
        64,
        32,
        64,
    >;
```

Next we have to setup the public key that we will use to verify the signature.

We need to convert the public key to a byte-array that we can include in the
Rust source code.

An easy way to do that is to convert the original keypair to `pk8` format (if
you didn't do this already in Approach 1 above):

```bash
$ openssl pkcs8 -in ec-secp256r1-priv-key.pem -topk8 -nocrypt -outform der > ec-secp256r1-priv-key.p8
```

The last 64 bytes of that file are the public key.

We can extract and format as-needed with:

```bash
$ tail -c 64 ec-secp256r1-priv-key.p8 | hexdump -v -e '1/1 "0x%02x "'
```

Create a buffer in main.rs with those bytes:

```rust
let verifying_key = kernel::static_init!(
    [u8; 64],
    [
        // insert bytes here
    ]
);
```

Then we can setup the remaining verification infrastructure:

```rust
let verifying_keys = kernel::static_init!([&'static mut [u8; 64]; 1], [verifying_key]);

let ecdsa_p256_verifier = kernel::static_init!(
    ecdsa_sw::p256_verifier::EcdsaP256SignatureVerifier<'static>,
    ecdsa_sw::p256_verifier::EcdsaP256SignatureVerifier::new()
);
ecdsa_p256_verifier.register();

let verifier_multiple_keys =
	components::signature_verify_in_memory_keys::SignatureVerifyInMemoryKeysComponent::new(
	    ecdsa_p256_verifier,
	    verifying_keys,
	)
	.finalize(
	    components::signature_verify_in_memory_keys_component_static!(Verifier, 1, 64, 32, 64,),
	);

let checking_policy = components::appid::checker_signature::AppCheckerSignatureComponent::new(
    sha,
    verifier_multiple_keys,
    tock_tbf::types::TbfFooterV2CredentialsType::EcdsaNistP256,
)
.finalize(components::app_checker_signature_component_static!(
    SignatureVerifyInMemoryKeys,
    capsules_extra::sha256::Sha256Software<'static>,
    32,
    64,
));
```

The `checking_policy` can then be used when loading processes.
