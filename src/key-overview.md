# Security USB Key with Tock

This module and submodules will walk you through how to create a USB security
key using Tock.

![Security Key](imgs/usbkey.jpg)

## Hardware Notes

To fully follow this guide you will need a hardware board that supports a
peripheral USB port (i.e. where the microcontroller has USB hardware support).
We recommend using the nRF52840dk.

## Goal

Our goal is to create a standards-compliant HOTP USB key that we can use with a
demo website. The key will support enrolling new URL domains and providing
secure authentication.

The main logic of the key will be implemented as a userspace program. That
userspace app will use the kernel to decrypt the shared key for each domain,
send the HMAC output as a USB keyboard device, and store each encrypted key in a
nonvolatile key-value storage.
