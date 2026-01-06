# Example Use Case: Signed Monolithic Image

## Use case description

A company creates a product that contains a secure processor that runs Tock with
several applications. Each app implements a different security feature of the
product. The secure processor has a secure boot mechanism that only runs
firmware images signed by the company.

The company is building the Tock kernel and applications itself, so it trusts
that the kernel and applications are not malicious. However, it wants to prevent
bugs or security vulnerabilities in one app's implementation from impacting the
confidentiality, integrity, and availability of the other apps.

## System configuration

### Build system and deployment

The company builds the Tock kernel and applications then combines them into a
single firmware image. That firmware image is signed using the secure
processor's firmware-signing tool. The signed firmware image is then included in
the product's system software image, and is deployed onto the secure processor
by the OS update mechanism.

Organizations building monolithic Tock systems do not necessarily use
[TBF](../tock_binary_format.md) as their userspace binary format. However, this
document will use TBF terminology to avoid inventing new terminology. Everything
here should be applicable to other userspace binary formats.

### Application IDs

The kernel requires all process binaries to have a
[ShortId](../tock_binary_format.md#10-shortid) header. That header's value is
used as both the application ID and short ID. The short IDs are assigned
sequentially — the first app implemented has ID 1, the second implemented has ID
2, etc. If an application is retired, its ID is never reused.

### Cryptography

Cryptographic subsystems that generate application-specific encryption keys use
the application ID (which matches the short ID) to identify the application. For
example, a system which generates per-app encryption keys using a KDF would feed
the application ID into the KDF.

### IPC

Clients discover servers using their application ID. Servers that wish to
perform client authorization do so by checking the clients' application IDs.

### Storage

Persistent storage systems use an application's short ID to determine whether
that application may write new entries into that storage.

When data is written into persistent storage, the entity writing the data
specifies:

1. Which short IDs may modify that data.
1. Which short IDs may read that data.

The storage layer retains that information, and uses that list to filter which
apps may modify and/or read it.

For more information, see the [storage permissions
TRD](../../trd/trd-storage-permissions.md).

### Syscall filtering

If the company desires to implement syscall filtering, there are multiple ways
they could implement the ACLs:

- The [Permissions](../tock_binary_format.md#6-permissions) TBF header.
- A central ACL list that refers to applications by short ID.
- A central ACL list that refers to applications by their index in the userspace
  binary list (this requires the ACL list to be regenerated if applications are
  ever added, removed, or reordered).

## Security dependencies

All of the following must be trusted to provide the required security
properties:

1. The Tock kernel source code.
1. For each application, that application's source code.
1. For applications that use IPC: the code of the IPC servers that it uses (but
   the impacts to confidentiality and integrity are limited to data passed over
   that IPC interface).
1. The system used to compile the kernel and applications, assemble the firmware
   image, and sign the firmware image.
1. For availability: the system that distributes the firmware image and deploys
   it onto the secure processor.
1. The secure processor (including its secure boot mechanism).
1. The TBF headers, particularly the ShortId header, to prevent impersonation,
   and the Permissions header, if used for syscall filtering.
