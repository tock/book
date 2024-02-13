Advanced Soil Moisture Sensor with Tock
===========

In this guide we are going to build a sophisticated soil moisture sensor using
many of the advanced features Tock provides.

> insert image here

This guide will highlight many Tock features, including:

- Signed applications
- OLED display software stack
- Inter-process communication
- Multi-processing
- Thread networking
- Userspace resource isolation

## Project Overview

We are going to develop three userspace apps:

1. The first app will read the analog soil moisture sensor and estimate the soil
   moisture. The app will expose the readings via IPC and display the readings
   on the screen.
2. The second app will grab data from the first app and transmit it via a Thread
   wireless network.
3. The third app will use the soil moisture data to decide when the plant needs
   to be watered and will alert the user via a large message on the screen.

We will also need to add some kernel-level capability to enable this:

- Each application will need a credential so the kernel can identify the app and
  give it access to particular resources. For example, on the first app can read
  the soil moisture sensor.
- The screen will need to be virtualized so that multiple apps can access the
  screen, and each gets its own region to write to.
- The kernel will need to support the Thread stack running in userspace.
