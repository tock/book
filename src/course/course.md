# Tock Course

The Tock course includes several different modules that guide you through
various aspects of Tock and Tock applications. Each module is designed to be
fairly standalone such that a full course can be composed of different modules
depending on the interests and backgrounds of those doing the course. You should
be able to do the lessons that are of interest to you.

Each module begins with a description of the lesson, and then includes steps to
follow. The modules cover both programming in the kernel as well as
applications.

## Setup and Preparation

You should follow the [getting started guide](../getting_started.html) to get
your development setup and ensure you can communicate with the hardware.

## Which Tutorial Should You Follow?

All tutorials explore Tock and running applications, but they focus on different
subsystems and different application areas for Tock. If you are interested in
learning about a specific feature or subsystem this table tries to help direct
you to the most relevant tutorial.

| Aspect of Tock              | Tutorial                                                                             |
| --------------------------- | ------------------------------------------------------------------------------------ |
| **Applications**            |                                                                                      |
| Hardware Root-of-Trust      | [Root of Trust](./root-of-trust)                                                     |
| Fido Security Key           | [USB Security Key](./usb-security-key)                                               |
| Wireless Networking         | [Thread Networking](./thread-tutorials)                                              |
| **Topics**                  |                                                                                      |
| Process Isolation           | [Root of Trust](./root-of-trust)                                                     |
| Inter-process Communication | [Thread Networking](./thread-tutorials), [Dynamic Apps](./dynamic-apps-and-policies) |
| Kernel Configuration        | [Dynamic Apps](./dynamic-apps-and-policies)                                          |
| **Skills**                  |                                                                                      |
| Writing Apps                | [USB Security Key](./usb-security-key), [Sensor](./sensor)                           |
| Implementing a Capsule      | [USB Security Key](./usb-security-key)                                               |
