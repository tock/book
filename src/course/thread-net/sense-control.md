# Sense and Control Application

## Background

### Applications in Tock

Tock applications look much closer to applications on traditional OSes than to
normal embedded software. They are compiled separately from the kernel and
loaded separately onto the hardware. They can be started or stopped individually
and can be removed from the hardware individually. Moreover, the kernel decides
which applications to run and what permissions they should be given.

Applications make requests to the OS kernel through system calls. Applications
instruct the kernel using "command" system calls, and the kernel notifies
applications with "upcalls". Importantly, upcalls never interrupt a running
application. The application must `yield` to receive upcalls (i.e. callbacks).

The userspace library ("libtock") wraps system calls in easier to use functions.
Often the library functions include the call to `yield` and expose a synchronous
driver interface. Application code can also call `yield` directly as we will do
in this module.

## Submodule Overview

In this submodule we will complete all non networked aspects of our mote. We will
begin with a simple temperature sensing application. From this starting point, we
will expand the application to accept user input and finally display the relevant 
information on a small screen. The milestones are shown below:

1. Milestone one: Obtain temperature sensor measurement.
2. Milestone two: Obtain user button input.
3. Milestone three: Display temperature data and user input on the screen.

We have provided starter code as well as completed code for each of the
milestones. If you're facing some bugs which are limiting your progress, you can
reference or even wholesale copy a milestone in order to advance to the next
parts of the tutorial.

