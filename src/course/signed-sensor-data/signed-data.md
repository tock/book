# Signed Sensor Data

[NOTE: I don't think signed is the right word here anymore since we're talking
about CTR which only involves encrypt / decrypt. We should think about how else
we should frame this]

We now will extend our networked device to determine if the data we receive is
signed data. Notice that we currently receive both signed and unsigned data.

At a high level, both the sender and receiver of our sensor data possess our
unique key. For simlicity in this tutorial, we have decided to use AES128CTR
encryption and decide to format the payloads of the UDP packets we send as
follows:

> | HEADER | IV | SIGNED DATA |

Importantly, OpenThread already encrypts the data sent within the Thread
network. We add this additional layer of encryption not to hide or secure the
data we are sending but instead to ensure this data originates only from nodes
in our network.

## Decrypting Received Packets

Tock provides apps access to cryptographic operations (e.g. an app can request
the kernel decrypt a given buffer). Naively, we can utilize said kernel
functionality to decrypt a signed packet and store the key in plaintext in the
app.

Storing such secrets in plaintext, however, is not particularly secure. For
instance, many microcontrollers offer debug ports which can be used to gain read
and write access to flash. Even if these ports can be locked down, such
protection mechanisms have been broken in the past. Apart from that, disallowing
external flash access makes debugging and updating our device much more
difficult.

[TODO NOTE: update naming encryption oracle]

To circumvent these issues, we will use an encryption oracle capsule: this
Tock kernel module will allow applications to request decryption of some
ciphertext, using a kernel-internal key not exposed to applications themselves.
This is a commonly used paradigm in root of trust systems such as TPMs or
OpenTitan, which feature hardware-embedded keys that are unique to a chip and
hardened against key-readout attacks.

Our kernel module will use a hard-coded symmetric encryption key (AES-128
CTR-mode), embedded in the kernel binary. While this does not actually
meaningfully increase the security of our example application, it demonstrates
how Tock can be integrated with root of trust hardware to securely store and use
encryption keys in a networked IoT device.

In the interest of time, we provide a completed kernel module with the needed
userspace bindings (in `oracle.h`) to you. If you are interested in seeing how this would 
be implemented, we provide a thorough walkthrough of creating an encryption
oracle in the [Tock USB Security Key Tutorial](../usb-security-key/key-hotp-oracle.md).
Let's use this to securely decrypt our signed sensor data!


> EXERCISE: Decrypt the signed sensor data UDP packets.
> and update handleUdpRecv(...) to print both unsigned
> packets and decrypted signed packets.
> 
> Recall, we have decided to structure our signed packets
> as follows:
>
>   | HEADER | IV | ENCRYPTED DATA | 
>
>       3B    16B      (N)bytes
>
> To denote our packets, we use a header of {"R","O","T"} 
> (root of trust) followed by our initialization vector (IV).
> The IV is a component of AES128CTR and is needed as an input
> for decrypting our data.

> **CHECKPOINT** 03_signed_data_final

Congratulations! You now have a complete Tock application that
can attach to an OpenThread network and use Tock's ability 
to securely store/decrypt data. This concludes this tutorial
module.
