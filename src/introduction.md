# Tock OS Tutorial

This course introduces you to Tock, a secure embedded operating system for
sensor networks and the Internet of Things. Tock is the first operating system
to allow multiple untrusted applications to run concurrently on a
microcontroller-based computer. The Tock kernel is written in Rust, a
memory-safe systems language that does not rely on a garbage collector.
Userspace applications are run in single-threaded processes that can be written
in any language.

In this hands-on guide, we will look at some of the high-level services
provided by Tock.  We will start with an understanding of the OS and its
programming environment.  Then we'll look at how a process management
application can help afford remote debugging, diagnosing and fixing a
resource-intensive app over the network.  The last part of the tutorial is a
bit more free-form, inviting attendees to further explore the networking and
application features of Tock or to dig into the kernel a bit and explore how to
enhance and extend the kernel.

This course assumes some experience programming embedded devices and fluency in C.
It assumes no knowledge of Rust, although knowing Rust will allow you to be
more creative during the kernel exploration at the end.

## Agenda

The training is divided into three sections, each starting with a short
presentation to introduce some concepts, followed by a practical exercise.

1. [Environment Setup](environment.md): Get familiar with the Tock tools
   and getting a board setup.

2. [Userland programming](application.md): write a basic sensing application in C.

3. [Deliver for the Client](client.md): Help an important client get a
   new board setup.

4. [Free-form Experimentation](freeform.md): Open-ended exploration with
   support from the Tock team.

