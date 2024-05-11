# Tock Robustness

The Tock kernel's robustness and inherently mutually distrustful design provides
a major advantage for embedded networked systems. Take for instance a standard
network application that implements all logic within one application unit (i.e.
links OpenThread directly to the platform implementation). We consider two
illustrative scenarios below of what may go wrong and how Tock guards against
such outcomes.

## Scenario 1 - Faulting Application

OpenThread is a large code base and interacts with a number of buffers.
Furthermore, our openthread app adds the complexity of sharing buffers across
IPC. Given the challenges in writing C code, it is likely that some aspect of
the application will fault at somepoint in the future.

In a traditional naively linked embedded platform, a fault in the OpenThread app
or OpenThread code base would in turn result in the platform itself faulting.
Tock guards against this as the kernel was designed with fault tolerance in
mind. Subsequently, a faulting app can be handled by the kernel and the broader
system is left unharmed. Developers have the option to specify how the kernel
should handle such faults. (@leon leaving this as a todo for you).

## Scenario 2 - Buggy Behavior

We now provide a scenario in which a bug in the OpenThread app results in the
OpenThread app entering some form of infinite loop (be it deadlock or busy
waiting). In a non-preemptive platform, the system will be disabled due to this
bug. However, because Tock preempts applications, such a buggy application will
no longer function, but the broader system will be unharmed.

## Tock Kernel

Up to this juncture, we have exclusively worked within userspace. We now modify
a kernel parameter so as to recover faulting applications (@Leon add more text
here since you are likely more familiar with this than I am)

By altering this kernel feature, the OpenThread app will now be relaunched after
a fault. This provides our network with a higher degree of resilience as
OpenThread saves the persistent state (e.g. network parameters) in nonvolatile
storage. Thus, upon the app being relaunched, these parameters can be read from
flash and the device can rapidly reattach to the network.
