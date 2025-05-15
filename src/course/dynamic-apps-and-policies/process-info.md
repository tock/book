# Using the Process Info Userspace Application

insert image

The Process Info application is an interactive, screen-based application for
viewing and controlling the applications installed on a Tock board. This guide
will help you install it and walk you through its features.

## Tock Kernel Image

If you haven't already, install the `tutorials/nrf52840dk-dynamic-apps-and-policies`
kernel on your board.

```
$ cd tock/boards/tutorials/nrf52840dk-dynamic-apps-and-policies
$ make install
```

## Install the Process Info Application

You can install the process info app like any other Tock application. You can
find it in
`libtock-c/examples/tutorials/dynamic-apps-and-policies/process-info`.

```
$ cd libtock-c/examples/tutorials/dynamic-apps-and-policies/process-info
$ make
$ tockloader install
```

## Exploring with the Process Info Application

When the Tock kernel is running the Process Info should be shown on the screen:

insert image

Interact with the application using the buttons:

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│                                                                    │
│                                                                    │
│           ┌────────────────┐                                       │
│           │                │                                        \
│           │                │                                         │
├───┐       │                │                                         │
│USB│       │     Screen     │                                         │
├───┘       │                │                                         │
│           │                │                      ┌─┐  ┌─┐           │
│           │                │                  Up--│O│  │O│           │
│           └────────────────┘                      └─┘  └─┘           │
│                                                   ┌─┐  ┌─┐           │
│                                             Down--│O│  │O│--Enter   /
│                                                   └─┘  └─┘         │
└────────────────────────────────────────────────────────────────────┘
```

| nRF52840dk Button Number | Action |
|--------------------------|--------|
| 1                        | Up     |
| 2                        | unused |
| 3                        | Down   |
| 4                        | Enter  |


### Viewing Active Processes

All active processes (including the Process Info application) are listed by the
Process Info application. You can scroll up and down to look through all
installed applications.

### Details on a Specific Process

Scroll to a desired application such that it is highlighted on the screen. Press the enter button
(`BUTTON 4`) to select it. You will now see a list of details about that application.

| Entry     | Description                                                                                                                                                                            |
|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ProcessId | The ProcessId is the runtime identifier for the process. Every time a process starts it gets a new ProcessId. All process IDs must be unique.                                          |
| ShortId   | The ShortId is the fixed identifier for a specific application. Each Tock kernel uses a policy for determining the ShortId. This identifier is persistent across reboots and restarts. |
|           |                                                                                                                                                                                        |

### Controlling a Specific Process

The Process Info application also enables you to control the execution of a
process.

| Operation | Description                                                                   |
|-----------|-------------------------------------------------------------------------------|
| Start     | Resume running a stopped process.                                             |
| Stop      | Halt a running process such that it is no longer scheduled to run.            |
| Fault     | Cause a process to crash and have the kernel run the process's fault handler. |
| Terminate | Stop a process and have its resources released.                               |
| Boot      | Start running a terminated or never started process.                          |




