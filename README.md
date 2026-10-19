<!--no-pdf-->
# CMSC 131 Lab 1 Starter

[![lab1-checks](https://github.com/WhiteLicorice/cmsc-131-lab1-starter/actions/workflows/test.yml/badge.svg)](https://github.com/WhiteLicorice/cmsc-131-lab1-starter/actions/workflows/test.yml)

Decode, encode, and checksum 20-byte IPv4 packet headers under a C driver.
The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: argument parsing and file I/O
cdecl.h             provided: the calling-convention macros
decode.asm          yours
encode.asm          yours
checksum.asm        yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register discipline checks for contract_test
tests/              provided: the header fixtures, their expected output,
                    and manifest.txt, the list both passes read
LICENSE             CC BY-NC-SA 4.0, inherited from the pcasm material
```

## What to Run

On Windows, run these commands in Git Bash, the shell from Block 1. In that
shell, `make` is your alias for `mingw32-make`. On Linux, use your terminal.

```bash
make
make check
```

`make` builds `renpkt` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The gate has two passes. The first decodes every header listed in
`tests/manifest.txt` and compares the output with `tests/expected/`. The
second is `contract_test`. It decodes and re-encodes every header the
manifest marks valid. It checks a checksum vector that needs the carry
folded twice. It checks that all three routines keep `ebx`, `esi`, `edi`,
and `ebp`, and return with `esp` where the call left it. A program can pass
the first pass and fail the second. That failure is the usual encoder bug.

## Reading a First Run

The assembly files ship as stubs that assemble and link as-is, so the build
works before you write any code. Right now they do nothing useful, which
makes every check fail: `7 of 7 checks differ`. That red run is the correct
starting state for a starter. The badge stays red until you implement the
routines.

## Adding a Header

Put the header in `tests/NAME.bin`. Write the output `renpkt --decode`
must print for it in `tests/expected/NAME.out`. Then add one line to
`tests/manifest.txt`:

```text
NAME val

```

Use `invalid` for a header with a wrong checksum. A valid header joins the
round trip in `contract_test` as well as the decode pass. The gate fails
and names the file when a `.bin` is not in the manifest, and when a listed
header has no expected file.

## The Driver's Argument Checks

`renpkt --encode` refuses a value its field cannot hold, and two values the
standard forbids. `--len` takes 20 through 65535, because the total length
counts the header. It defaults to 20. `--flags` takes 0 through 3, because
the top bit of the field is reserved and must be zero. `--df` sets 2 and
`--mf` sets 1. A refused option exits with status 2 and writes no file.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

## Fixtures

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`,
`contract_test.c`, `contract_regs.asm`, or a provided `tests/` file appears
as a diff in the open. Your own headers and manifest lines are additions,
not edits.

---

## Design Notes

Complete this section before the Week 1 progress report. The syllabus asks
for problem analysis, a solution architecture, and an estimated timeline.
Keep each part short. Update it when the plan changes.

| Field | Bit Location | Size | Description |
|---|---|---|---|
| Version | byte 0, bits 7-4| 4 | IPv4 is used, therefore this value is always 4 in decimal (0100) |
| Header Length (IHL) | byte 0, bits 3-0| 4 bit | This 4-bit field tells us the length of the IP header in 32-bit increments. With 4 bits in 32-bit increments, the max header length we can make with this is 60 bytes. This is the absolute limit of the header length.|
| Type of Service | [byte 1, bits 7-2 DSCP] [byte 1, bits 1-0 ECN]| 6 bits(DSCP), 2 bits(ECN) |DSCP is used to tell what priority the packet has. The ECN field enables congestion notification, which allows senders to slow down before packet loss.  |
| Total Length: | bytes 2-3| 16 bits | indicates  the entire size of the IP packet (header and data) in bytes [100(decimal) => 100 bytes]. If you have no data, the size is 20 bytes. |
| Identification | bytes 4-5| 16 bits | If fragmented, the packet will use this to identify whih IP packet it belongs to. All fragments of a packet use the same ID |
| IP Flags | byte 6, bits 7-3| 3 bits  | 1st bit is reserved and MUST always be set to 0. 2nd bit (Don't Fragment [DF]), means that the packet should not be fragmented by the router. 3rd bit (More Fragments [MF]) means that fragments can follow. |
| Fragment Offset | bytes 6-7, low 13 bits (0-13)| 13 bits | Specifies the position of the fragment in the original fragmented IP packet, it is measured in 8-byte units. (decimal value of bits) * 8 = (starting point of data) |
| Time to Live TTL | byte 8| 8 bits  | A sort of timer "hop count" that decrements each time the packet passes through a router, it times out if it reaches 0. |
| Protocol | byte 9| 8 bits | Tells us which protocol the packet uses. |
| Header Checksum | bytes 10-11| 16 bits | Can be used to detect errors in the header but does not validate the data if ever |
| Source Address | bytes 12-15| 32 bits | The sender's IP address |
| Destination Address | bytes 16-19| 32 bits | The destination IP address |
| Checksum Validation |---| ---? | Used to see if the checksum was valid, not included in the packet. just in the C print |
Reference: https://networklessons.com/ip-routing/ipv4-packet-header

### Solution architecture

How the three routines split the work. Which registers each routine uses,
and how the struct offsets in `driver.c` map to the fields.

A cdecl routine performs several things:
1. Passing Arguments - When arguments are pushed into the stack, it is done so from right to left based on how they appeared in the fucntion prototype located in the driver.c. The caller is responsible to push the arguments of the function prototype to the stack before the program proceeds to the callee function.
2. Maintaining the Stack - The callee cleans up the stack after it finishes execution. The ESP register's value is adjusted based on the total size of the arguments.
3. Returning Values - Return values can be as large as 32-bits and is contained in the EAX register. When dealing with larger return values, they have extra space allocated in the stack because of the caller. The return value is then copied to the stack by the callee.
4. Using the Register - Registers are caller saved, the callee function must preserve their values should it modifiy it. However, some registers, like EAX, ECX, and EDX, are callee saved where the caller does not need to save their original values.

Based on #4, the cdecl routine must restore 5 registers after they were used, these are: EBX, ESI, EDI, EBP, and ESP. ESP is a special case since, instead of using the usual POP \<register\>, the instruction ADD ESP, \<(number of bytes of arguments) * 4\> is instead used.

#### Call trace

This section explains the call trace using --decode as the example

1. First, drive.c calls the decode_header() function that was first instantiated as a function prototype on the top of the file. Via ENTER 0, 0, it pushes THE EBP to the stack then copies the value of ESP to EBP to change where the stack frame begins.
2. Next, it takes the two arguments given and pushes them right to left to the stack. It first pushes &f which is the address of the ipvr4_fields struct. Then, it pushes the address of the 20 byte field header (which is in the form of an unsigned char array of size 20). This subtracts 4 from the value of ESP for each argument passed (in this case two arguments equates to subtracting 8).
3. Then the program pushes the return address of the program execution, which subtracts another 4 from ESP.
4. After the program finishes exeecuting the cleanup portion is performed. First, the callee must ensure that the registerers that must be restored, EBX, ESI, EDI, EBP are restored. Next, the program must call the LEAVE instruction to restore the value of EBP and throws away the items pushed in the stack. Then, RET pops the return address so the program could continue executing based on its value. Lastly, based on the caller's responsibility to clean up the two arguments that is passed through the instruction ADD ESP, 8.
5. The Routine ends with the arguments placed on the stack and the value of ESP pointing to it.


### Timeline

| Week | Goal | Owner |
|---|---|---|
| 1 | Checksum /wo tests | JB Aparicio |
| 2 | Decode | EJ Tolentino |
| 3 | Encode | Julian Medalla |
| 4 | Defense | |

## Subsystem Ownership

| Subsystem | Owner |
|---|---|
| Decode path (`decode.asm`) | EJ Tolentino |
| Encode path (`encode.asm`) | Julian Medalla |
| Checksum and tests (`checksum.asm`, `tests/`) | JB Aparicio |

## Quirks and Issues

### Known issues

In encoding, one of the main issues encountered are segmentation faults due to imporper handling of the stack. This is mainly due to to not adding the `[esp + ,number of arguments>]`. This was eventually solved by adding the missing argument. 

### Quirks

- 
