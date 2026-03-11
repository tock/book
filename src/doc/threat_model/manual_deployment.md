# Example Use Case: Manual Local Tock Deployment

## Use case description

When new users follow Tock's [Getting Started](../../getting_started.md) guide,
they are instructed to:

1. Connect a local development board to their machine.
1. Manually build a kernel and flash it using `make install`
1. Install applications using `tockloader install`

This is a very common workflow for Tock usage, and is used by:

- Tock developers contributing to the Tock kernel, libtock-c, and libtock-rs.
- Hobbyists building Tock systems for their own use, for example a homemade
  temperature and humidity monitoring system.
- Researchers trying out novel OS design ideas or using Tock systems to collect
  data on long-running experiments.

Tock users generally want the usual OS isolation properties (e.g. one process
should not be able to corrupt another process' memory). However, for most of
these users, advanced security guarantees (such as those that can only be
provided by cryptographically verified apps) are not necessary and are more
effort than is reasonable.

This document is focused on use cases where the usual OS isolation properties
are beneficial, but complex security mechanisms are unnecessary and not worth
the implementation effort.

## System configuration

### Build system

The kernel is complied locally on the user's computer. Applications are either
compiled locally on the user's computer, or downloaded from e.g.
`www.tockos.org/assets/tabs`.

### Application IDs

The kernel is configured as follows:

- **Application ID:** For userspace binaries with a [package
  name](../tock_binary_format.md#3-package-name) TBF header, the package name is
  used as the application ID. If no package name header is present, the kernel
  instead uses the [short ID](../tock_binary_format.md#10-shortid) header as the
  application ID. If a userspace binary lacks both a package name and a short ID
  header, the kernel uses the SHA-256 hash of the userspace binary as its
  application ID.
- **Short ID:** Userspace binaries with a ShortId header are given that short
  ID. Userspace binaries with no short ID header are given a locally unique
  short ID.

Applications that want to access storage need a short ID header, other
applications do not need short ID headers. If a short ID header is included, the
ID should be generated as follows:

1. Generate a random nonzero 32-bit integer.
2. Verify that short ID does not match the short ID of any other known Tock apps
   (including all apps available at `www.tockos.org/assets/tabs`). If a conflict
   is encountered, go back to step 1.

A user who downloads apps from third parties is responsible for verifying that
the apps do not have the same short ID.

### Cryptography

Cryptographic subsystems that generate application-specific encryption keys use
the application ID to identify the application. For example, a system which
generates per-app encryption keys using a KDF would feed the application ID into
the KDF.

### IPC

Most clients will discover servers using the string name and/or package name
registries. Applications can also choose to discover servers by application ID
or to validate application IDs against expected IDs, but that is not necessary
(and can block some use cases, such as new implementations of existing
inter-process APIs).

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

It is not generally expected that these use cases have a syscall filter.

If a syscall filter is implemented, there are a couple options for implementing
the ACL list:

- Refer to applications by short ID.
- Use the [Permissions](../tock_binary_format.md#6-permissions) TBF header.

## Security dependencies

All of the following are trusted to provide confidentiality, integrity, and
availability to applications (in other words, if any of these entities are
malicious, they can compromise the security of applications):

1. The Tock kernel source code and build system.
1. The system(s) used to build the application code.
1. For downloaded pre-built applications, the application distribution
   mechanism.
1. The system used to deploy the kernel and applications onto the dev hardware
   (e.g. tockloader and its dependencies).
1. The dev hardware itself.
1. If third-party applications are used: the user, to verify that no application
   impersonates another application's package name, and to verify that no two
   applications have the same ShortId header.
1. If applications use the IPC string name registry: applications are trusted to
   not impersonate other applications.
