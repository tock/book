# Thread Smart Sensor

This module and submodules will walk you through how to create a Thread-enabled
wireless sensor using Tock.

## Hardware Notes

To fully follow this guide you will need a hardware board that supports the
nRF52840 microcontroller. We recommend using the nRF52840dk.

Compatible boards:

- nRF52840dk
- imix
- Microbit v2

## Goal

Our goal is to create a Thread-enabled wireless sensor.

The main logic of the key will be implemented as a userspace program.

## nRF52840dk Hardware Setup

![nRF52840dk](imgs/nrf52840dk.jpg)

If you are using the nRF52840dk, there are a couple of configurations on the
nRF52840DK board that you should double-check:

1. The "Power" switch on the top left should be set to "On".
2. The "nRF power source" switch in the top middle of the board should be set to
   "VDD".
3. The "nRF ONLY | DEFAULT" switch on the bottom right should be set to
   "DEFAULT".

## Install the Tock Kernel

To start, you will need to install the Tock kernel on your board. The kernel is
configured and installed from the `tock/boards/` directory. Find the correct
board file for your hardware and run `make install`.

```
git clone https://github.com/tock/tock
cd tock/boards
cd <your board>
make install
```
