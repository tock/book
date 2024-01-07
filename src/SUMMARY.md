# Summary

Tock OS Course

[Introduction](./introduction.md)

- [Hands-on Guides](./guides.md)

  - [Getting Started](./getting_started.md)

- [Tock Course](./course.md)

  - [USB Security Key](./key-overview.md)
    - [Kernel: USB Keyboard](./usb-hid.md)
    - [Kernel: HMAC](./key-hotp-hmac.md)
    - [Kernel: App State](./key-hotp-appstate.md)
    - [HOTP Application](./key-hotp-application.md)
    - [Encryption Oracle Capsule](./key-hotp-oracle.md)
    - [Access Control](./key-hotp-access.md)
  - [Kernel Boot](./boot.md)
  - [Policies](./policies.md)
  - [TicKV](./tickv.md)
  - [Application](./application.md)
  - [Graduation](./graduation.md)
  - [Deprecated](./deprecated.md)
    - [Important Client](./important_client.md)
    - [Capsule](./capsule.md)

- [Mini Tutorials](./tutorials/tutorials.md)

  - [Blink an LED](./tutorials/01_running_blink.md)
  - [Button to Printf()](./tutorials/02_button_print.md)
  - [BLE Advertisement Scanning](./tutorials/03_ble_scan.md)
  - [Sample Sensors and Use Drivers](./tutorials/04_sensors_and_drivers.md)
  - [Inter-process Communication](./tutorials/05_ipc.md)

- [Kernel Development Guides](./development/guides.md)

  - [Chip Peripheral Driver](./development/peripheral.md)
  - [Sensor Driver](./development/sensor.md)
  - [System Call Interface](./development/syscall.md)
  - [HIL](./development/hil.md)
  - [Virtualizers](./development/virtual.md)
  - [Kernel Tests](./development/tests.md)
  - [Component](./development/component.md)
  - [Optimize Code Size](./development/code_size.md)
  - [Porting Tock](./development/porting.md)
  - [Porting From 1.x to 2.x](./development/porting_v1-v2.md)

- [Kernel Documentation](./doc/index.md)

  - [Overview](./doc/overview.md)
  - [Design](./doc/design.md)
  - [Soundness](./doc/soundness.md)
  - [Lifetimes](./doc/lifetimes.md)
  - [Implementation](./doc/implementation.md)
    - [Compilation](./doc/compilation.md)
    - [Kernel Configuration](./doc/configuration.md)
    - [Kernel Attributes](./doc/kernel_attributes.md)
    - [Memory Layout](./doc/memory_layout.md)
    - [Mutable References](./doc/mutable_references.md)
    - [Processes](./doc/processes.md)
    - [Tock Binary Format](./doc/tock_binary_format.md)
