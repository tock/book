# Thread Router Setup

---

> _Note:_ If you are a participant at a hosted tutorial, we have already set up
> a thread router. You should skip this step and
> [go straight to creating the sensor application](sensor-app.md).
>
> Please **do not** set up your own router during a hosted tutorial, as this may
> confuse other tutorial participants.

---

The thread network tutorial requires a Thread router to be present, which is
able to accept certain messages from participant boards, average the supplied
values, and broadcast them back. We provide a pre-built flash image that
performs this task here:
[ot-central-controller.hex](../../assets/thread-tutorial/ot-central-controller.hex).

## Flashing the Binary

You can flash this binary with an arbitrary tool that can program `hex` files,
such as `JLinkExe` or `probe-rs`. It may be that you need to reset the board
after flashing, for example by pressing the physical `RESET` button.

```
$ probe-rs
probe-rs download --chip nRF52840_xxAA --format hex ot-central-controller.hex
      Erasing ✔ [00:00:13] [##########] 516.00 KiB/516.00 KiB @ 37.43 KiB/s (eta 0s )
	  Programming ✔ [00:00:11] [########] 516.00 KiB/516.00 KiB @ 46.68 KiB/s (eta 0s )
	  Finished in 24.86s
```

```
$ JLinkExe
SEGGER J-Link Commander V7.94a (Compiled Dec  6 2023 16:07:30)
DLL version V7.94a, compiled Dec  6 2023 16:07:07

Connecting to J-Link via USB...O.K.
Firmware: J-Link OB-SAM3U128-V2-NordicSemi compiled Oct 30 2023 12:12:17
Hardware version: V1.00
J-Link uptime (since boot): 0d 00h 08m 40s
S/N: 683487279
License(s): RDI, FlashBP, FlashDL, JFlash, GDB
USB speed mode: High speed (480 MBit/s)
VTref=3.300V


Type "connect" to establish a target connection, '?' for help
J-Link>connect
Please specify device / core. <Default>: NRF52840_XXAA
Type '?' for selection dialog
Device>NRF52840_XXAA
Please specify target interface:
  J) JTAG (Default)
  S) SWD
  T) cJTAG
TIF>S
Specify target interface speed [kHz]. <Default>: 4000 kHz
Speed>
Device "NRF52840_XXAA" selected.


Connecting to target via SWD
InitTarget() start
InitTarget() end - Took 2.79ms
Found SW-DP with ID 0x2BA01477
DPIDR: 0x2BA01477
CoreSight SoC-400 or earlier
Scanning AP map to find all available APs
AP[2]: Stopped AP scan as end of AP map has been reached
AP[0]: AHB-AP (IDR: 0x24770011)
AP[1]: JTAG-AP (IDR: 0x02880000)
Iterating through AP map to find AHB-AP to use
AP[0]: Core found
AP[0]: AHB-AP ROM base: 0xE00FF000
CPUID register: 0x410FC241. Implementer code: 0x41 (ARM)
Found Cortex-M4 r0p1, Little endian.
Cortex-M: The connected J-Link (S/N 683487279) uses an old firmware module: V1 (current is 2)
FPUnit: 6 code (BP) slots and 2 literal slots
CoreSight components:
ROMTbl[0] @ E00FF000
[0][0]: E000E000 CID B105E00D PID 000BB00C SCS-M7
[0][1]: E0001000 CID B105E00D PID 003BB002 DWT
[0][2]: E0002000 CID B105E00D PID 002BB003 FPB
[0][3]: E0000000 CID B105E00D PID 003BB001 ITM
[0][4]: E0040000 CID B105900D PID 000BB9A1 TPIU
[0][5]: E0041000 CID B105900D PID 000BB925 ETM
Memory zones:
  Zone: "Default" Description: Default access mode
Cortex-M4 identified.
J-Link>loadfile ot-central-controller.hex
'loadfile': Performing implicit reset & halt of MCU.
Reset: Halt core after reset via DEMCR.VC_CORERESET.
Reset: Reset device via AIRCR.SYSRESETREQ.
Downloading file [ot-central-controller.hex]...
J-Link: Flash download: Bank 0 @ 0x00000000: 1 range affected (528384 bytes)
J-Link: Flash download: Total: 17.932s (Prepare: 0.161s, Compare: 0.045s, Erase: 10.840s, Program & Verify: 6.757s, Restore: 0.128s)
J-Link: Flash download: Program & Verify speed: 76 KB/s
O.K.
J-Link>quit
```

## Interacting with the Router

Once you have flashed this image, it should provide you with an OpenThread CLI
on the serial console. You can use this to inspect the state of the device, such
as through `tockloader listen`:

```
$ tockloader listen
[INFO   ] Using "/dev/ttyACM0 - J-Link - CDC".
[INFO   ] Listening for serial output.

> state
leader
Done
```

You can get a list of attached devices through `child table`:

```
> child table
| ID  | RLOC16 | Timeout    | Age        | LQ In | C_VN |R|D|N|Ver|CSL|QMsgCnt|Suprvsn| Extended MAC     |
+-----+--------+------------+------------+-------+------+-+-+-+---+---+-------+-------+------------------+
|   1 | 0x1801 |        240 |         67 |     3 |  107 |1|1|1|  4| 0 |     0 |   129 | 0a5e0b97af0631ae |

Done
```
