# Graduation

Now that you have the basics of Tock down, we encourage you to continue to
explore and develop with Tock! This book includes a "slimmed down" version of
Tock to make it easy to get started, but you will likely want to get a more
complete development environment setup to continue. Luckily, this shouldn't be
too difficult since you have the tools installed already.

## Using the latest kernel

The Tock kernel is actively developed, and you likely want to build upon the
latest features. To do this, you should get the Tock source from the repository:

```bash
$ git clone https://github.com/tock/tock
```

While the `master` branch tends to be relatively stable, you may want to use the
latest [release](https://github.com/tock/tock/releases) instead. Tock is
thoroughly tested before a release, so this should be a reliable place to start.
To select a release, you should checkout the correct tag. For example, for the
1.4 release this looks like:

```bash
$ cd tock
$ git checkout release-1.4
```

You should use the latest release. Check the [releases
page](https://github.com/tock/tock/releases) for the name of the latest release.

Now, you can compile the board-specific kernel in the Tock repository. For
example, to compile the kernel for imix:

```bash
$ cd boards/imix
$ make
```

All of the operations described in the course should work the same way on the
main repository.


## Using the full selection of apps

The book includes some very minimal apps, and many more can be found in the
`libtock-c` repository. To use this, you should start by cloning the repository:

```bash
$ git clone https://github.com/tock/libtock-c
```

Now you can compile and run apps inside of the examples folder. For instance,
you can install the basic "Hello World!" app:

```bash
$ cd libtock-c/examples/c_hello
$ make
$ tockloader install
```

With the `libtock-c` repository you have access to the full suite of Tock apps,
and additional libraries include BLE and Lua support.

