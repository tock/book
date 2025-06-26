# Encryption Service Userspace Application

As a reminder, this guide guides you through creating an encryption service that
we'll use in later parts to demonstrate Tock's strengths as a hardware root of
trust OS.

We have already configured our kernel as needed to provide access to the OLED
screen and the _encryption oracle_ driver from the
[HOTP demo](../usb-security-key/key-overview.md). This driver has a built-in AES
key that we can use to encrypt messages without our userspace application ever
making contact with the key itself.

## Background

### Secure Elements as Roots of Trust

Recall from the [overview](overview.md) that a secure element is a purpose-built
chip used for key storage and encryption purposes, often in support of a main
processor which needs to perform some kind of cryptography.

In a real-world setting, a secure element like the Infineon SLE78 (the chip used
in the YubiKey 5 series) might communicate over a standard device-internal bus
like SPI or I2C, or might even communicate directly with a host over USB.

Often, smaller secure elements like the SLE78 will receive commands and deliver
responses encoded as
[application protocol data units (APDUs)](https://en.wikipedia.org/wiki/Smart_card_application_protocol_data_unit),
a holdover from the smart card industry.

While we could replicate this behavior for our encryption service by passing
APDUs back and forth over USB, we elide this complexity for the sake of
simplicity and just prompt the user for plaintext to encrypt via Tock's console.

### Hardware-backed Keys

In an actual hardware root of trust, the AES key in the encryption oracle would
be _hardware-backed_, i.e. it would be generated and kept in a hardware key
store apart from where the processor could directly access it.

While the nRF5x AES peripheral doesn't have support for hardware-backed keys, it
does allow us to store our AES128 key in the encryption oracle driver and load
it into the AES128 peripheral as needed; this is almost as secure, and in any
case the difference is invisible to the userspace application which can't access
the key either way.

### Applications in Tock

For readers who have previously written embedded software, it's important to
note that Tock applications are written in a manner much more similar to
traditional, non-embedded software. They are compiled separately from the kernel
and loaded separately onto the hardware. They can be started or stopped
individually and can be removed from the hardware individually. Moreover, the
kernel decides which applications to run and what permissions they should be
given.

Applications make requests to the OS kernel through system calls. Applications
instruct the kernel using Command system calls, and the kernel notifies
applications with upcalls the application must `subscribe` to. Importantly,
upcalls never interrupt a running application. The application must `yield` to
receive upcalls (i.e. callbacks).

The userspace library (`libtock`) wraps system calls in easier to use functions.
The libtock library is completely asynchronous. Synchronous APIs to the system
calls are in `libtock-sync`. These functions include the call to `yield` and
expose a synchronous driver interface. Application code can use either.

### Tock Allows and Upcalls

When interacting with drivers in Tock, it's important to note that by design,
any driver can only access the data you explicitly allow it access to. In Tock,
an _allow_ is a buffer shared from a userspace application to a specified
driver. These can be _read-only_, where the driver can only read what the app
supplies in the buffer, or _read-write_, where the driver can also modify the
buffer to e.g. write results.

In order to easily allow asynchronous driver interfaces, the Tock driver allows
registering _upcalls_, callbacks which kernel drivers can invoke e.g. to signal
to an app that a requested operation has completed.

### Interprocess Communication in Tock

Tock has an IPC driver in the kernel which allows userspace apps to advertise
_IPC services_ with names such as `org.tockos.tutorial.led_service`.
Applications that want to make requests over IPC can use the `ipc_discover()`
function with an IPC service name to fetch the application ID of the app hosting
the service. After this is done, the requesting app can register callbacks,
allow access to shared buffers, and finally `notify` the IPC service to perform
some operation.

## Submodule Overview

We have three small milestones in this section, all of which build upon supplied
starter code.

1. Milestone one adds support for interacing with a dispatch/logging service, to
   illustrate how various root of trust services might be dispatched in practice
   while maintaining separation.
2. Milestone two adds support for sending/receiving data and serializing
   plaintext, introducing how libtock-c APIs work.
3. Milestone three adds actual encryption support using the encryption oracle
   driver, demonstrating how the Tock syscall interface.

## Setup

Before starting, check the following:

1. Make sure you have compiled and installed the Tock kernel with the screen and
   encryption oracle drivers on to your board.
2. Make sure you have no testing apps installed. To remove all apps:

   ```
   tockloader erase-apps
   ```

## Starter Code

We'll start with the starter code, which includes a logging application for
displaying encryption service logs to the OLED screen, as well as a scaffold for
developing the remainder of the encryption service userspace app.

1. Inside your copy of `libtock-c`, navigate to
   `libtock-c/examples/tutorials/root_of_trust/`.

   This contains the starter code which you'll work from in the following steps.
   For now, all this application does is present a list of services that the
   root of trust can provide, and allows you to select one to interact with.

2. Compile the screen application and load it onto your board. In the `screen/`
   subdirectory, run

   ```
   make install
   ```

3. Next, navigate to the `encrypt_service/` subdirectory in the same parent
   folder and load it as well by again running

   ```
   make install
   ```

4. After both applications are loaded, you should see a screen which should
   allow you to select a service to dispatch. You can navigate up and down in
   the menu by using `BUTTON 1` and `BUTTON 3` on the nRF52840dk board, and you
   can select an option by pressing `BUTTON 2` and then clicking `Start`.

   Note that right now, the encryption service doesn't have any code to react to
   requests for dispatch, so if you select it nothing will happen.

The source code for the screen application is in `screen/main.c`. If you dig
through it, you'll find logic for

- displaying the menu to select an application,
- requesting a root of trust service to be dispatched on select
- listening for logging requests to display

The macros for generating a menu using the `u8g2` user interface library are a
bit obtuse at first, so they (along with the rest of the file) have been
commented thoroughly.

## Milestone One: Connecting to the Main Screen App

To begin, we first want our encryption service to be able to (a) respond when
the main screen app signals it to take over control of the UART console, and (b)
connect to the logging service the main screen app provides for displaying logs
to the screen.

From a functionality standpoint, we certainly _could_ have service dispatch, all
of the desired cryptographic services, and logging functionality in one event
loop in an application; however, when using Tock, separating these
functionalities into different apps is helpful from a security perspective.
We'll discuss this more in the next part of the tutorial.

First, let's modify our scaffold in `encryption_service_starter/main.c` to
respond to the main screen app's dispatch signal using Tock's interprocess
communication (IPC) driver. Rename the directory in your local copy from
`encryption_service_starter/` to `encryption_service/`. Completed code is
available in `encryption_service_milestone_one/` if you run into issues.

1. Take a look in `screen/main.c` at the `select_rot_service()` function. This
   function, called by `main()`, takes in the name of an IPC service hosted e.g.
   by our encryption service app and

   - calls `ipc_discover()` to go from the IPC service name to the ID of the
     process hosting that IPC service
   - calls `ipc_register_service_callback()` to register a logging IPC service
     under `org.tockos.tutorials.root_of_trust.screen`, so that the selected
     root of trust service can log to screen
   - calls `ipc_notify_service()` to trigger the IPC service of the process
     whose ID `ipc_process()` found

   All of these IPC API functions are provided by the `libtock/kernel/ipc.h`
   header included at the top of the file.

2. To start, open `encryption_service/main.c` and create a `wait_for_start()`
   function which registers an IPC callback under the service name
   `org.tockos.tutorials.root_of_trust.encryption_service` and then yields until
   that callback is triggered by the main screen app.

   - You'll want to use the IPC function
     [`ipc_register_service_callback()`](https://github.com/tock/libtock-c/blob/master/libtock/kernel/ipc.h)
     to register your callback function. See the documentation there for how the
     signature of your callback function should look.
   - The callback function you write should set a global `bool` from false to
     true. `wait_for_start()` can then use the
     [`yield_for`](https://github.com/tock/libtock-c/blob/master/libtock/tock.h)
     function to wait for this change in state.

3. Now, call `wait_for_start()` in `main()`, and follow it with a call to
   `printf()` to send a message to the UART console; this should indicate when
   your app has been selected.

4. To test this out, build and install your application as previous, then run
   `tockloader listen` in a separate terminal. When you select the encryption
   service and hit `Start` in the menu, you should see your message in the
   console (not on the screen).

   > **TIP:** You can leave the console running, even when compiling and
   > uploading new applications. It's worth opening a second terminal and
   > leaving `tockloader listen` always running.

Next, we need to connect our application back to the screen logging IPC service.
To do this,

1. Again in `encryption_service/main.c`, create a new `setup_logging()` function
   which takes in a message string and sends it via IPC to the logging service
   to display.

   - In the `log_to_screen()` function, you'll want to use `ipc_discover()` to
     discover the process ID for the logging service,
     `ipc_register_client_callback()` to provide a callback that sets a global
     flag to indicate a completed log, and `ipc_share()` to share a buffer to
     the logging service.

   - When creating the log buffer to share over IPC, which can store as long of
     a message as will fit on the OLED screen. 32 bytes should be sufficient.
     Make sure that the buffer is marked with the `aligned` attribute. i.e.

     ```c
     char log_buffer[LOG_WIDTH] __attribute__((aligned(LOG_WIDTH)));
     ```

2. Next, create a new `log_to_screen()` function which takes in a
   null-terminated message string and sends it via IPC to the logging service to
   display.

   - To trigger the logging service to fetch your message string from the shared
     buffer, you'll want to use `ipc_notify()`.

3. To test your implementation, add calls to `wait_for_start()` and
   `setup_logging()` to `main()`, and follow them with some calls to
   `log_to_screen()`.

   - To test your implementation, recompile and re-install your encryption app
     and then use the on-device menu to start the encryption service.

> **Checkpoint:** Your application should now be able to receive encryption
> requests over the UART console, and log these requests over IPC to the screen.

## Milestone Two: Sending/Receiving Data and Serializing Plaintext

Now that we can interact with the main screen app over IPC, we should set up the
UART console to allow inputting secrets to encrypt, and make sure that we can
encode the resulting ciphertext as hex to present back to the user.

In a practical HWRoT setting, it may be inadvisable to send secret values to a
device `in the clear` where they could be intercepted. For instance, smart cards
and smaller secure elements often make use of GlobalPlatform's Secure Channel
Protocols such as
[Secure Channel Protocol 03](https://globalplatform.org/wp-content/uploads/2014/07/GPC_2.3_D_SCP03_v1.1.2_PublicRelease.pdf)
to establish an encrypted, authenticated channel before exchanging any secret
information.

For brevity, we won't implement a full secure channel in this protocol, but at
the end of this section we include a challenge in this vein for after the
tutorial is complete.

To start, let's retrieve the secret from the user over UART to parse. Completed
code is available in `encryption_service_milestone_two/` if you run into issues.

1. In `encryption_service/main.c`, create a `request_plaintext()` function which
   prompts a user over UART for plaintext into a provided buffer with a provided
   size.

   - To prompt the user, you'll want to use `libtocksync_console_write()` with a
     message like `"Enter a secret to encrypt:"`.

   - For fetching a response, you'll want to use `libtocksync_console_read()` to
     read bytes one-by-one, breaking when you hit a newline (`\n` or `\r`).
     You'll also want to use this function to strip leading whitespace from the
     user's input.

   - Make sure to echo each character as it's received by writing it back, or
     else the user won't be able to see their input.

   - For convenience later, return the size of the input.

2. Next, we'll add a function `bytes_to_hex()` which inputs a byte buffer and
   length, and outputs a null-terminated hex string.

   - When writing this function, the most direct way to convert a byte to hex is
     with `sprintf`: you can use `"%02X"` as a format string.

3. To test both of these functions in concert, modify `main` to, in a loop,
   input plaintext over the console, convert it to hex, and then report it to
   the screen.

> **Checkpoint:** Your application should now be able to input messages via the
> UART interface and report byte values as hex.

## Milestone Three: Adding Encryption Support

Finally, we want to actually encrypt our messages before we report them.

> **NOTE:** If you've completed the HOTP tutorial prior, the same implementation
> of `oracle.c` there will work--feel free to simply copy it over from
> `encryption_service_milestone_three/` if you've already implemented it before.

We first create a new file to house our interface to the encryption oracle
driver, then integrate it into `main`:

1. Create a header file `oracle.h` in `encryption_service/` with the following
   prototype (don't forget to `#include <stdint.h>`!):

   ```c
   int oracle_encrypt(const uint8_t* plaintext, int plaintext_len, uint8_t*
                      output, int output_len, uint8_t iv[16]);
   ```

2. Create a source file `oracle.c` next to `oracle.h` with an implementation of
   this function, using the encryption oracle to encrypt `plaintext` and placing
   the result in `output_len`. The `iv` buffer should be used to return the
   randomized
   [initialization vector](https://en.wikipedia.org/wiki/Initialization_vector)
   generated for encryption.

   - To randomize the IV, you'll want to use
     `libtocksync_rng_get_random_bytes()`.

   - The current kernel configuration has the ID for the encryption capsule as
     `0x99999`, which you'll pass to each command that targets it.

   - From there, the driver requires three allows to operate; you'll want to use
     `allow_readonly()` and `allow_readwrite()` to set them up.

     - A read-only allow with ID 0 for sending the input plaintext
     - A read-only allow with ID 1 for sending the input IV
     - A read-write allow with ID 0 for receiving the output ciphertext

   - Next, you'll need to set up an upcall to confirm when the encryption is
     done. You'll want the signature of your upcall to look like

     ```c
     static void crypt_upcall(__attribute__((unused))  int   num,
                                                       int   len,
                              __attribute__ ((unused)) int   arg2,
                              __attribute__ ((unused)) void* ud);
     ```

     and it should both set a global flag indicating that the upcall is done, as
     well as store the ciphertext length passed to it in a global variable.

   - Finally, you'll need to send a command to the driver with command ID 1 to
     trigger the start, after which you should `yield_for()` until the upcall
     completes and reset the `done` flag for the next call. The return value of
     the function should be the length returned from the upcall.

3. Finally, let's wire it all together. Go back to `main()` in `main.c`, and
   make it do the following:

   - Wait for the start signal for the encryption service (`wait_for_start()`)
   - Set up the IPC logging interface (`setup_logging()`)
   - Looping forever (using `log_to_screen` to indicate each step is happening):
     - Request a plaintext from the user (`request_plaintext()`), from a
       plaintext buffer and to ciphertext buffer both of size `512` (four
       AES-128 blocks)
     - Encrypt the plaintext (`oracle_encrypt()`, from `oracle.c`)
     - Convert the ciphertext to a hex string (`bytes_to_hex()`)
     - Dump the ciphertext to the console (e.g. with
       `printf("Ciphertext: %s\n", ...)`)

When you run the test now, you should be able to use `tockloader listen` and
type messages into the UART console when prompted to encrypt them.

> **Checkpoint:** Your application should now be able to encrypt arbitrary
> messages sent over the UART console, logging the status of the encryption
> capsule to the screen as it runs.

Congratulations! Feel free to move on to the next section, where we'll begin to
attack our implementation and show how Tock allows for defense-in-depth measures
appropriate for a root of trust operating system.

## Challenge: Authenticating the Results

> **NOTE:** This challenge is open-ended, may take a while, and requires
> experience working on Tock drivers--it's best approached after completing the
> remainder of the tutorial. We'll touch on Tock drivers later in this tutorial,
> but you can also follow the
> [HOTP tutorial](../usb-security-key/key-overview.md) for additional practice
> if you'd like.

As mentioned earlier, communication channels with a HWRoT are often _encrypted_
and _authenticated_. The former provides confidentiality so that secrets can't
be extracted by eavesdroppers; meanwhile, the latter provides authenticity of
results so attackers can't impersonate either party.

While designing a secure channel is a surprisingly tricky task, many existing
frameworks exist, e.g. the popular
[Noise Protocol Framework](https://noiseprotocol.org/) used by many projects
including the well-known WireGuard VPN. As a step in this direction, the
challenge described here is to just provide authentication using
[ECDSA signatures](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm)
for the ciphertexts that the root of trust produces, so that a client of the
encryption service can be sure that the results they receive came from our root
of trust.

Here is an outline for how one might go about doing so--these steps are
intentionally a bit vague, as this is intended more to serve as a longer-term
practice than something that can be done in the timeframe of an in-person
tutorial:

1. You'll want to first add a signing oracle driver. While the nRF52840dk board
   used for this tutorial lacks ECDSA hardware support[^1], Tock provides an
   `ecdsa-sw` driver which wraps RustCrypto's signing and verifying
   implementations to provide software support.

   - The actual structure you will want to use is the `EcdsaP256SignatureSigner`
     in `capsules/ecdsa_sw/src/p256_signer.rs`. This struct implements the
     `public_key_crypto::SignatureSign` hardware interface layer (HIL) trait, so
     you can use its `sign()` method to sign messages and its
     `set_sign_client()` to designate a callback for when a signing operation is
     completed. The `public_key_crypto::SetKey` HIL will similarly allow you to
     change the key the signer uses.

   - You can base your work off the encryption oracle implementation in
     `capusles/extra/tutorials/encryption_oracle_chkpt5.rs`. Most of the logic
     for tracking driver state should remain the same, but instead of the driver
     struct containing an instance of an AES struct used encrypt, your driver
     struct will contain an `EcdsaP256SignatureSigner` used to sign.

2. Next, you'll want to create a board definition based off the one in
   `boards/nordic/nrf52840dk/src/main.rs` which instantiates a
   `EcdsaP256SignatureSigner` and your signing oracle driver, passing the former
   to the latter on creation.

   - For an example this struct in use, see the ECDSA test capsule in
     `capsules/ecdsa_sw/src/test/p256.rs` as well as the test board
     configuration in
     `boards/configurations/nrf52840dk/nrf52840dk-test-kernel/src/test/ecdsa_p256_test.rs`
     which depends on it.

3. Finally, you'll want to create a new userspace interface to this driver akin
   to that in `encryption_service/oracle.c`. The resulting file should be almost
   identical, but of course with functions accepting messages to sign instead of
   secrets to encrypt, etc.

Even if you don't complete all these steps, hopefully reviewing the above
outline should give a good picture of how you can go from an idea of a driver
you need for an application to a full implementation and integration into a
userspace app.

[^1] This is _almost_ true: the nRF52840 chip contains the closed-source ARM
TrustZone CryptoCell 310, which has support for ECDSA signatures, but sadly
there's not driver support for it yet (due to its closed-source nature).
