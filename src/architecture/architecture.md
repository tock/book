An online series designed for people new to Tock explaining the system architecture with a focus on how it can be used in their projects. The series uses the Tock online book, kernel documentation, libtock-rs and libtock-c repositories to illustrate the concepts.

# Current Videos
- [Tock Overview, Setup Tock Tooling, and First Boot on QEMU (Blink) Part 1](https://www.youtube.com/watch?v=cd10qCP-ciU)
- [Tock Overview, Setup Tock Tooling, and First Boot on QEMU (Blink) Part 2](https://www.youtube.com/watch?v=SNxUK6WFEe4)
- [Demo for Tock Overview, Setup Tock Tooling, and First Boot on QEMU (Blink)](https://www.youtube.com/watch?v=IEgUObXtJko)

# Audience
1. Students building course projects  
2. Job seekers creating interview-ready demos  
3. People prototyping ideas for work  
4. Rust/embedded enthusiasts curious about Tock

## Materials & Setup

**Core references**

- Tock Book: <https://book.tockos.org/>  
- Tock Docs (TRDs, syscalls, capsules): <https://github.com/tock/tock/tree/master/doc>

**Tools**

- QEMU virtual environment (used throughout Section I)  
- `rustup` (stable), `cargo`, `gcc` (or build-essentials), Python 3  
- `tockloader` (`pip3 install tockloader`)  
- (Optional) VS Code with Rust Analyzer for debugging

**Hardware (Section II–IV)**

- **nRF52840-DK** (~$50; Digikey, Newark, etc)  
- **Two nRF52840-DK boards recommended** for 802.15.4/Thread hands-on.  
- **Two USB cables** (USB HID sessions often need a second cable).  
- Link: <https://www.nordicsemi.com/Products/Development-hardware/nRF52840-DK>

**Repositories used**

```bash
# Suggested clones in a dedicated workspace
git clone https://github.com/tock/tock.git
git clone https://github.com/tock/libtock-rs.git
git clone https://github.com/tock/libtock-c.git
```

## Four Sections & Session Plan
- Section I — Understand Tock and its use cases using QEMU (Weeks 1–6)
- Section II — Tock on Hardware (nRF52840-DK) (Weeks 7–10)
- Section III — Wireless with 802.15.4 and Thread (Weeks 11–13)
- Section IV — Security & Delivery (Weeks 14–16)

### Section I — Understand Tock and its use cases using QEMU (Weeks 1–6)

#### Session 1 — Setup Tock Tooling & First Boot on QEMU (Blink)
**Outcome:** Boot Tock under QEMU, install/run a Rust app, see the event loop.

**Presentation:** Tock overview; userspace vs kernel
- Video: [Part 1](https://www.youtube.com/watch?v=cd10qCP-ciU), [Part 2](https://www.youtube.com/watch?v=SNxUK6WFEe4)
- Kernel configs <https://book.tockos.org/doc/configuration.html>
- Kernel memory layout <https://book.tockos.org/doc/memory_layout.html>

**Hands-on:**  
- Video: [Demo](https://www.youtube.com/watch?v=IEgUObXtJko)
- Run the QEMU tutorial board <https://book.tockos.org/getting_started.html> 
- Build and install a **blink** app; verify output; exit QEMU gracefully <https://book.tockos.org/tutorials/06_qemu_libtockrs.html>

---

#### Session 2 — Multiple Apps on QEMU and `tockloader` Essentials (Blink + Buttons)
**Outcome:** Run multiple apps; manage them with `tockloader`; observe interaction with capsules.
  
**Presentation:** Processes, memory limits, and basic capsules (LEDs, Buttons).  
- Tock processes <https://book.tockos.org/doc/processes.html>
- Capsules on buttons and LEDs <https://github.com/tock/tock/blob/master/doc/syscalls/00003_buttons.md>, <https://github.com/tock/tock/blob/master/doc/syscalls/00002_leds.md>

**Hands-on:**  
- Build/run Blink + Buttons <https://book.tockos.org/tutorials/06_qemu_libtockrs>
- `tockloader list`, `install`, `erase-apps`, `listen`

---

#### Session 3 — Under the Hood: Syscalls, Upcalls, Data Movement, and Debugging
**Outcome:** Understand `command`, `subscribe`, `allow`, `yield`; learn basic QEMU/VS Code debugging.
  
**Presentation:** Kernel tie-in: syscalls overview: yield, subscribe, command, allow.
- <https://github.com/tock/tock/tree/master/doc/syscalls>
- <https://book.tockos.org/trd/trd104-syscalls.html>
- <https://book.tockos.org/trd/trd106-completion-codes.html>

**Hands-on:**  
- Trace a button press through **userspace → syscall → capsule → upcall → userspace** <https://book.tockos.org/tutorials/06_qemu_libtockrs> 
- Set breakpoints in VS Code; step over/into; inspect registers/logs <https://book.tockos.org/development/vscode_debugging>

---

#### Session 4 — Inter-Process Communication (IPC) and C Apps on Tock
**Outcome:** See process isolation in action; pass data via IPC; compare C vs Rust apps.
  
**Presentation:** Why IPC in Tock; minimal surfaces; `yield_for` patterns.
- <https://book.tockos.org/tutorials/05_ipc.html>
- <https://github.com/tock/libtock-c/tree/master/examples/tutorials/05_ipc>
- <https://github.com/tock/tock/blob/master/kernel/src/ipc.rs>

**Hands-on:**  
- Build an IPC **service + client** pair (C or Rust) <https://github.com/tock/libtock-c/tree/master/examples/tutorials/05_ipc>
- Show message flow and upcalls  

---

#### Session 5 — QEMU Virtual Screen: Text and Graphics
**Outcome:** Write text and simple graphics to the QEMU screen.
  
**Presentation:** Text/Screen capsules; display buffers; double-buffering basics.
- <https://book.tockos.org/course/setup/screen.html>
- <https://github.com/tock/tock/blob/master/doc/syscalls/90001_screen.md>
- <https://github.com/tock/tock/blob/master/doc/syscalls/90003_text_screen.md>

**Hands-on:**  
- Draw text; draw primitives; update regions <https://book.tockos.org/course/setup/screen.html>

---

#### Session 6 — App Storage: Key-Value and Non-Volatile Storage
**Outcome:** Persist and retrieve app data in QEMU with Key-Value DB and non-volatile storage (this would be good to do with a Rust application instead of the C examples.)

**Presentation:** Understand how to use the Key-Value and non-volatile storage capsules
- <https://github.com/tock/tock/blob/master/doc/syscalls/50003_key_value.md>
- <https://github.com/tock/tock/blob/master/doc/syscalls/50004_isolated_nonvolatile_storage.md>

**Hands-on:**  
- Save a small settings struct; retrieve and display it <https://book.tockos.org/course/setup/kv.html> 

---

### Section II — Tock on Hardware (nRF52840-DK) (Weeks 7–10)

#### Session 7/8 — Board Bring-Up: Flashing Kernel & Apps; using hardware sensors with Tock
**Outcome:** Kernel flashed on nRF52840-DK; compile, flash and debug the temperature sensor on nRF52840

**Presentation:** J-Link/OpenOCD; board support; Interrupts & callbacks; temperature sensor.
- Discuss hardware tools(JLink/OpenOCD). <https://book.tockos.org/setup/hardware>
- Alarm capsule https://github.com/tock/tock/blob/master/doc/syscalls/00000_alarm.md>
- Temperature capsule https://github.com/tock/tock/blob/master/doc/syscalls/60000_ambient_temperature.md>
- GPIO <https://book.tockos.org/trd/trd103-gpio.html>, <https://github.com/tock/tock/blob/3bda1239b287c9ee0bd3d0c803463c7cabadbe07/doc/syscalls/00004_gpio.md>

**Hands-on:** Hands-on: Setup the temperature sensor app on the nRF52840 DK development board and debug
- <https://github.com/tock/libtock-rs/blob/master/examples/temperature.rs>
- <https://book.tockos.org/development/vscode_debugging.html>

**Hands-on:**  
- Button toggles LED with interrupt; periodic LED “heartbeat” via Alarm  
- Measure callback cadence (print timestamps)  

---

#### Session 9 — Using the ADC
**Outcome:** Sample temperature/ADC; format and print readings; basic filtering.  
**Presentation:** Sensor capsules; synchronous user code atop async drivers (`yield_for`).  
- ADC https://book.tockos.org/trd/trd102-adc.html>, <https://github.com/tock/tock/blob/3bda1239b287c9ee0bd3d0c803463c7cabadbe07/doc/syscalls/00005_adc.md>

**Hands-on:**  
- Is there a rust app <https://github.com/tock/libtock-c/tree/master/examples/tests/adc/adc>?

---

#### Session 10 — USB HID Keyboard (Stage 1: Userspace)
**Outcome:** Act as a USB HID keyboard; inject HOTP/one-shot codes from a user app.  

**Presentation:** USB device basics; HID report structure; event-driven app design.
- Overview USB <https://book.tockos.org/course/setup/usb-hid.html>
- Kernel USB capsules <https://github.com/tock/tock/blob/master/capsules/extra/src/usb_hid_driver.rs>
- Kernel USB capsules <https://github.com/tock/tock/tree/master/capsules/extra/src/usb>
  
**Hands-on:**  
- Build & run a HID keyboard userspace app that types a short code on button press <https://github.com/tock/libtock-c/tree/master/examples/tests/keyboard_hid>

---

### Section III — Wireless with 802.15.4 and Thread (Weeks 11–13)

#### Session 11 — 802.15.4 Basics: RX/TX and UDP Capsule
**Outcome:** Transmit/receive between two boards; inspect frames/packets; simple UDP.

**Presentation:** Radio stack overview; addressing/channel; reliability tradeoffs.  
- Kernel 802.15.4 Radio: <https://github.com/tock/tock/blob/3bda1239b287c9ee0bd3d0c803463c7cabadbe07/doc/reference/trd-radio.md>
- 802.15.4 stack: <https://github.com/tock/tock/tree/master/capsules/extra/src/ieee802154>
- UDP capsule <https://github.com/tock/tock/blob/master/doc/syscalls/30002_udp.md>
**Hands-on:** showing use of IEEE 802.15.4 networking
- Build `ieee802154_rx_tx` <https://github.com/tock/libtock-rs/blob/master/examples/ieee802154_rx_tx.rs>  
- (Optional) Wrap a UDP packet and print payload  

---

#### Session 12 — Thread Networking (Stage 1): Join and Inspect a Network
**Outcome:** Join a Thread network; observe state changes; obtain IPv6 addresses.  

**Presentation:** Thread roles (router, end device), commissioning, security material.  
- <https://book.tockos.org/course/thread-tutorials/thread-primer>
- <https://book.tockos.org/course/thread-tutorials/encrypted-sensor-data/thread-app>

**Hands-on:**  
- Build Thread demo; join an existing network or a provided border router  
- Show address/state in `tockloader listen`  

---

#### Session 13 — Thread (Stage 2): Encrypted Sensor Data
**Outcome:** End-to-end: sensor → encrypt → send; decrypt on the other end.  

**Presentation:** Keys/credentials; app vs kernel responsibilities; failure modes.  
- <https://book.tockos.org/course/thread-tutorials/encrypted-sensor-data/thread-app>

**Hands-on:**  
- Encrypt temperature readings; transmit over Thread; decrypt/print at receiver  
- <https://book.tockos.org/course/thread-tutorials/encrypted-sensor-data/thread-app>

---

### Section IV — Security & Delivery (Weeks 14–16)

#### Session 14 — App Signing & Tock Binary Format
**Outcome:** Build/sign apps with ECDSA; verify at load/run; understand startup flow.  

**Presentation:** Tock Binary Format (TBF), headers, versioning; boot pathway.  
- Tock binary format: <https://book.tockos.org/doc/tock_binary_format.html>
- Signing Apps with ECDSA Signatures <https://book.tockos.org/course/setup/ecdsa.html>
- <Kernel startup https://book.tockos.org/doc/startup.html>

**Hands-on:**  
- Sign an app; demonstrate accepted vs tampered images  

---

#### Session 15 — Threat Model & Isolation
**Outcome:** Map Tock’s threat model to your project; identify defenses & gaps.  

**Presentation:** Process isolation, MPU, capabilities; least privilege in capsules.
- <https://book.tockos.org/doc/threat_model/threat_model.html>

**Hands-on:**  
- Create a simple threat table for your project (assets, adversaries, mitigations)  
---

#### Session 16 — USB Security Key (Stage 2): Kernel Oracle & Access Control
**Outcome:** Move secrets to a kernel driver; enforce which app can use them. 
 
**Presentation:** Capabilities & policy; userspace→kernel trust boundaries.  

**Hands-on:**  
- Add credentials/policy to enable HID code entry only from your app  
- Show denied-by-default behavior, then allow with proper credential  
---
