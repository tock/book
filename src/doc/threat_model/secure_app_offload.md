# Example Use Case: Smartphone Secure App Offload

## Use case description

The main processor of a modern smartphone (known as its Application Processor,
or AP for short) is not the most secure execution environment. The CPU is
generally a multi-core processor with multiple threads per core, a data cache,
DRAM, and speculative execution. All of those have hardware side-channels and
vulnerabilities. In addition, the software environment is more
performance-focused than security-focused, generally using a highly featureful
kernel written in C.

Because of this, security-critical parts of the OS such as:

- Secure/verified boot
- PIN/passcode checking and encryption key derivation
- Fingerprint checking
- Facial recognition
- Encryption key storage

are typically implemented on separate, security-focused processors.

This use case describes a smartphone OS that gives its apps access to a
similarly-secure execution environment for their code.

The basic concept is:

- The phone contains a security-focused processor to support this offload.
- The security-focused processor runs Tock, and allows applets to be dynamically
  deployed onto it by the AP.
- The smartphone's main OS contains an API that allows the phone apps to deploy
  applets onto the Tock system.
- Those Tock applets then run computations without relying on the AP for
  confidentiality or integrity.

One key property of this use case is that there is no single entity that can be
trusted to delegate application IDs, for a couple reasons:

- Smartphone OSes may support multiple app stores, so the app store cannot
  delegate app IDs.
- App developers have to be able to deploy development apps onto the phone, so
  there is always some way to sideload an app onto the system (bypassing app
  stores entirely).
- There isn't any other entity that is trusted to delegate app IDs.

This use case also poses a resource allocation problem. Smartphone OSes can
support a much larger number of apps than most Tock systems can support. That
necessitates swapping out the applets dynamically. In the following sequence of
events:

1. An app installs its applet
2. The applet runs, and saves some data
3. The app goes idle (is not used for a while)
4. The system uninstalls the applet to free up resources for another applet
5. The app is used again, and reinstalls its applet

After step 5, the applet should be able to access the data it saved at step 2
(or at least its cryptographic keys, so that data can be offloaded onto external
storage without losing confidentiality and integrity).

For this use case, application IDs are constructed cryptographically in a manner
that:

- Does not require a central ID delegation authority
- Does not trust the AP
- Preserves application IDs across applet installs so they can access
  previously-saved data and encryption keys.

## System configuration

### Build system and deployment

App developers set up a Public Key Infrastructure (PKI) to sign their applets
with. To release a new version of the app, they:

1. Compile the applet using their build system.
1. Sign the compiled applet images using their PKI.
1. Format the signature into a [credentials
   footer](../../trd/trd-appid.md#52-credentials-footer). The format is
   described below in [Application IDs](#application-ids)
1. Include the applet images (including the credentials footer) into their app
   package.

### Application IDs

Note: Do not blindly copy this application ID design! It has not been reviewed
by cryptography experts and is not quantum safe. Its purpose is to demonstrate
that it is possible to derive application IDs from developer PKIs without
requiring a central signing authority. We expect that any organization that uses
cryptographically-derived application IDs will design their own credentials
footer that fits their hardware's limitations and security requirements.

The Tock system uses a TBF credentials footer with the following format:

```
0             2             4                           8
+-------------+-------------+---------------------------+
| Type (128)  | Length      | format                    |
+-------------+-------------+---------------------------+
| Ed25519 public key                                    |
|                                                       |
|                                                       |
|                                                       |
+-------------------------------------------------------+
| Ed25519 signature                                     |
|                                                       |
|                                                       |
|                                                       |
|                                                       |
|                                                       |
|                                                       |
|                                                       |
+-------------------------------------------------------+
```

The AppID checker verifies the signature is valid for the public key. The
application ID for the process is `format || public key` (a contiguous byte
range, `footer[4..40]`, so the appID slice can point into the footer).

Short IDs are split into two ranges as follows:

```
┌─────────────────────────┬───────────────────┬──────────────────────────────┐
│ Range                   │ Description       │ Allocation strategy          │
├─────────────────────────┼───────────────────┼──────────────────────────────┤
│ 1..=0x7FFFFFFF          │ System apps       │ Hardcoded table              │
├─────────────────────────┼───────────────────┼──────────────────────────────┤
│ 0x80000000..=0xFFFFFFFF │ All other applets │ Table in nonvolatile storage │
└─────────────────────────┴───────────────────┴──────────────────────────────┘
```

Within each range, short IDs are assigned sequentially, and are not reused.

The first range, system apps, is for applications that are part of the operating
system itself. These applications may have special permissions that other
applets do not have (for example, if the system for installing applets uses a
userspace process, that userspace process would have extra permissions). These
applications have hardcoded short IDs, which allows hardcoded ACLs (such as the
syscall filtering table) to refer to them.

The remaining range is for dynamically-installed applets. There are allocated
using a table stored in nonvolatile storage, allowing each app to be assigned a
short ID.

When the kernel loads a process, it checks the tables to identify its short ID.
If the application is not present, it assigns it a new short ID and adds it to
the table in nonvolatile storage.

### Cryptography

Cryptographic subsystems that generate application-specific encryption keys use
the application ID to identify the application. For example, a system which
generates per-app encryption keys using a KDF would feed the application ID into
the KDF.

### IPC

Multiple IPC registries may be provided (string name, package name,
application ID). Applets that want to communicate with specific apps use the
application ID registry to verify they are communicating with the specific apps
they wish (this applies to both clients and servers).

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

As previously mentioned, system apps may be granted permissions that
dynamically-loaded applets are not granted. That permission control may be
implemented by system call filtering. There would be a default list of
permissions that applies to dynamic applets, and a separate ACL giving
permissions to the known system apps. There are a couple ways the system app ACL
could refer to applications:

- By short ID
- By its index in the system app binary list (this option requires the ACL table
  to be regenerated any time system apps are added, removed, or reordered).

Additionally, the system could follow the
[Permissions](../tock_binary_format.md#6-permissions) TBF header. It would need
to make sure that dynamically-loaded applets can not grant themselves
system-only permissions using that header. That can be done through either a
load-time check or through checking each syscall against both the permission
header and the global permission ACLs.

## Security dependencies

All of the following must be trusted to provide the required security
properties:

1. The Tock kernel source code and build system.
1. For each application, that application's source code, build system, and PKI.
1. For applications that use IPC: the code of the IPC servers that it uses (but
   the impacts to confidentiality and integrity are limited to data passed over
   that IPC interface).
1. For availability: the system that distributes the firmware image and deploys
   it onto the secure processor.
1. The secure processor (including its secure boot mechanism).
