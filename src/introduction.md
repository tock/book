# Tock OS Book

<img src="../imgs/tock.svg" style="float:right;" />
This book introduces you to Tock, a secure embedded operating system for sensor
networks and the Internet of Things. Tock is the first operating system to allow
multiple untrusted applications to run concurrently on a microcontroller-based
computer. The Tock kernel is written in Rust, a memory-safe systems language
that does not rely on a garbage collector. Userspace applications are run in
single-threaded processes that can be written in any language.

The book is divided into two sections: the course and a series of mini
tutorials. The course is a good place to start, and provides a structured
introduction to Tock that should take a few hours to complete (it was designed
for a half day workshop). The tutorials are smaller examples that highlight
specific features.

## Tock Course

In this hands-on guide, we will look at some of the high-level services provided
by Tock.  We will start with an understanding of the OS and its programming
environment.  Then we'll look at how a process management application can help
afford remote debugging, diagnosing and fixing a resource-intensive app over the
network.  The last part of the tutorial is a bit more free-form, inviting
attendees to further explore the networking and application features of Tock or
to dig into the kernel a bit and explore how to enhance and extend the kernel.

This course assumes some experience programming embedded devices and fluency in
C. It assumes no knowledge of Rust, although knowing Rust will allow you to be
more creative during the kernel exploration at the end.

### Course Outline

You should first make sure you have the [requisite](prerequisites.html)
hardware and software to complete the guide.

The guide is divided into sections, each with an brief introduction to
introduce concepts, followed by hands-on exercises.

1. [Environment Setup](environment.html): Get familiar with the Tock tools
   and getting a board setup.

2. [Userland programming](application.html): write a basic sensing application in C.

3. [Kernel programming](capsule.html): understand the kernel's boot sequence and
   write a simple driver in Rust.

## Tock Mini Tutorials

These [tutorials](./tutorials/tutorials.html) feature specific examples of Tock
applications. They can be completed after the course to learn about different
capabilities of Tock apps.
