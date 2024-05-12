# Testing You Can Compile the Kernel

To test if your environment is working enough to compile Tock, go to the
`tock/boards/` directory and then to the board folder for the hardware you have
(e.g. `tock/boards/imix` for imix). Then run `make` in that directory. This
should compile the kernel. It may need to compile several supporting libraries
first (so may take 30 seconds or so the first time). You should see output like
this:

```
$ cd tock/boards/imix
$ make
   Compiling tock-cells v0.1.0 (/Users/bradjc/git/tock/libraries/tock-cells)
   Compiling tock-registers v0.5.0 (/Users/bradjc/git/tock/libraries/tock-register-interface)
   Compiling enum_primitive v0.1.0 (/Users/bradjc/git/tock/libraries/enum_primitive)
   Compiling tock-rt0 v0.1.0 (/Users/bradjc/git/tock/libraries/tock-rt0)
   Compiling imix v0.1.0 (/Users/bradjc/git/tock/boards/imix)
   Compiling kernel v0.1.0 (/Users/bradjc/git/tock/kernel)
   Compiling cortexm v0.1.0 (/Users/bradjc/git/tock/arch/cortex-m)
   Compiling capsules v0.1.0 (/Users/bradjc/git/tock/capsules)
   Compiling cortexm4 v0.1.0 (/Users/bradjc/git/tock/arch/cortex-m4)
   Compiling sam4l v0.1.0 (/Users/bradjc/git/tock/chips/sam4l)
   Compiling components v0.1.0 (/Users/bradjc/git/tock/boards/components)
    Finished release [optimized + debuginfo] target(s) in 28.67s
   text    data     bss     dec     hex filename
 165376    3272   54072  222720   36600 /Users/bradjc/git/tock/target/thumbv7em-none-eabi/release/imix
   Compiling typenum v1.11.2
   Compiling byteorder v1.3.4
   Compiling byte-tools v0.3.1
   Compiling fake-simd v0.1.2
   Compiling opaque-debug v0.2.3
   Compiling block-padding v0.1.5
   Compiling generic-array v0.12.3
   Compiling block-buffer v0.7.3
   Compiling digest v0.8.1
   Compiling sha2 v0.8.1
   Compiling sha256sum v0.1.0 (/Users/bradjc/git/tock/tools/sha256sum)
6fa1b0d8e224e775d08e8b58c6c521c7b51fb0332b0ab5031fdec2bd612c907f  /Users/bradjc/git/tock/target/thumbv7em-none-eabi/release/imix.bin
```

You can check that tockloader is installed by running:

```
$ tockloader --help
```

If either of these steps fail, please double check that you followed the
environment setup instructions above.

## Flash the kernel

Now that the board is connected and you have verified that the kernel compiles
(from the steps above), we can flash the board with the latest Tock kernel:

    $ cd boards/<your board>
    $ make

Boards provide the target `make install` as the recommended way to load the
kernel.

    $ make install

You can also look at the board's README for more details.
