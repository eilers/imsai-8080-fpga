# S-100 processor board — manual

This board takes the place of the processor card in an IMSAI 8080. A small plug-in module (a Trenz TE0725, which carries a Xilinx Artix-7 field-programmable gate array) generates the bus signals that the original 8080 processor card generated. The rest of the machine — the front panel, the memory cards, the disk controller, the backplane — stays as it is.

The gate array is a chip whose wiring is loaded from a file at power-up. That file is written in a hardware-description language called VHDL. You do not need to read VHDL to build, set up, or test this board. The chapters below describe what the wires do, what the lights should show, and what to check.

The program that is loaded today is a **demo**, not a computer. It walks through memory addresses so the front-panel lamps have something to display, and it lets the front panel stop, step, and deposit. It does not run programs. A later program will put an 8085 processor into the same chip. The electrical design of the board is already made for that processor, at a clock of up to 6 MHz. The demo itself runs at 2 MHz, which is the speed of a standard IMSAI.

## What the words mean

These names appear on the schematics, on the front panel, and in this manual. An asterisk `*` after a name means the wire is **active low**: it does its job when it is near 0 V, and it is idle when it is near 5 V.

| Word               | Meaning                                                                                                                                                                                                                                                                  |
|--------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| S-100              | The 100-pin connector and the shared wires behind it. Every card in the machine plugs into the same set of wires. Also published later as IEEE-696.                                                                                                                      |
| Backplane          | The board those connectors are soldered to. This machine uses an N8VEM S-100 backplane, version 4 (May 2015).                                                                                                                                                            |
| IMSAI              | The computer this board is built for: an IMSAI 8080, with its original front panel.                                                                                                                                                                                      |
| CP-A               | The printed-circuit board behind the IMSAI front panel. It owns the switches and the lamps.                                                                                                                                                                              |
| MPU-A              | The original IMSAI processor card. This project replaces that card.                                                                                                                                                                                                      |
| FPGA               | The programmable chip on the Trenz module. It plays the role of the 8080.                                                                                                                                                                                                |
| Bus master         | The one card that is allowed to put an address on the bus and to decide whether this moment is a read or a write. This board is the permanent bus master.                                                                                                                |
| DO and DI          | Data Out and Data In. DO is the byte the processor sends. DI is the byte a memory or a peripheral sends back. They are two separate 8-bit groups on the S-100 connector. On this board they share one set of wires at the FPGA.                                          |
| Open collector     | A shared wire that any card may pull down to 0 V, and that no card ever drives up. A resistor (here, the backplane terminator) lets it rise when everybody has let go. Interrupt requests and "ready" lines work this way, so several cards can share them.              |
| Terminator         | The circuit on the backplane that holds idle signal wires at about 2.7 V through 270 ohm resistors, and that absorbs reflections when the machine runs fast.                                                                                                             |
| Level shifter      | A chip that translates between the 5 V of the S-100 bus and the 3.3 V of the FPGA. Outbound signals use 74ACT245 (5 V supply, dual in-line package, order code SN74ACT245N). Inbound signals use 74LVC245 (3.3 V supply, same package). |
| T-state            | One tick of the processor clock. At 2 MHz a tick lasts 500 ns (half a millionth of a second). A memory read takes three ticks, plus extra ticks if a card asks the processor to wait.                                                                                    |
| pSYNC, pDBIN, pWR* | The three timing strobes. pSYNC says "a new cycle is starting." pDBIN says "I am reading, please put a byte on DI." pWR* says "I am writing, the byte on DO is valid."                                                                                                   |
| Status word        | Eight bits that say what kind of cycle this is: instruction fetch, memory read, memory write, input, output, interrupt acknowledge, or halt. The processor puts them on the data wires during pSYNC. The front panel latches them and lights the status lamps from them. |
| MWRT               | Memory write. A pulse that means "store the byte now." On an IMSAI the front panel creates this pulse, not the processor card.                                                                                                                                           |
| XRDY and PRDY      | Two "ready" wires. Both must be high for the processor to finish a cycle. The front panel uses XRDY as its RUN / STOP line. Memory boards use PRDY (pin 72, called RDY on the schematic) when they need extra time.                                                      |
| SSW DSB*           | Sense-switch disable, pin 53. The front panel pulls it low while it is forcing a byte onto the processor's own data wires (examine, deposit, single step).                                                                                                               |
| POC*               | Power-on clear, pin 99. A long low pulse after power-up, and again after the front-panel RESET switch. Memory boards and peripherals reset from it.                                                                                                                      |
| DMA, HOLD*, pHLDA  | Direct memory access. Another card pulls HOLD*low to borrow the bus. This board answers with pHLDA and lets go of the address and data wires until HOLD* is released.                                                                                                    |
| JP1                | A two-pin header on this board. A jumper on it connects the on-board memory-write gate to the bus. Leave the jumper off in an IMSAI.                                                                                                                                     |

## How the S-100 bus works in an IMSAI 8080

### One set of wires, many cards

The chassis holds a row of 100-pin sockets. Pin 1 of every socket is the same wire, pin 2 of every socket is the next wire, and so on. A card never has a private path to the processor. It watches the shared wires and, when the address matches it, it answers.

Six of the pins are the supplies and the main grounds:

| Pins       | What they carry                                                            |
|------------|----------------------------------------------------------------------------|
| 1 and 51   | Unregulated +8 V. Each card makes its own +5 V from this.                  |
| 2          | Unregulated +16 V, for cards that need a positive analog or serial supply. |
| 52         | Unregulated −16 V.                                                         |
| 50 and 100 | Ground.                                                                    |

The other pins are signals. They fall into a few jobs.

**Address, A0 to A23 (16 of these on a stock IMSAI, 24 in the later standard).** The processor puts out the address of the byte it wants. Lamps on the front panel follow A0 to A15.

**Data out, DO0 to DO7.** The byte the processor is sending. During the first tick of every cycle this byte is not data at all: it is the status word, described below.

**Data in, DI0 to DI7.** The byte a memory or a peripheral is sending back.

**Clocks.** Pin 24, called Φ2 on an IMSAI and PHI on this board, is the processor clock. Pin 49, CLOCK, is a separate 2 MHz square wave that other cards may use as a timebase. Pin 25 was Φ1 on the original IMSAI; the later standard redefined it as pSTVAL* ("status valid"). This board can drive either one. The choice is described under "Pin 25" below.

**Strobes.** pSYNC (pin 76) rises at the start of a cycle and stays high for one tick. pDBIN (pin 78) rises when the processor wants to read. pWR*(pin 77) falls when the processor wants to write. MWRT (pin 68) is the memory-write pulse the front panel makes out of pWR*.

**Status, one wire per flag.** sM1, sOUT, sINP, sMEMR, sHLTA, sINTA, and sWO*. These stay valid for the whole cycle. The stack flag has no pin of its own; it exists only as bit 2 of the status byte on the data wires during pSYNC. The front panel does not have to use the status pins: it can read the same information from the data wires during pSYNC, and that is what the CP-A does. Pin 98 is the ERROR* line. The backplane schematic happens to name that net SSTACK; this card treats the pin as ERROR* and does not connect it to the stack flag.

**Ready, interrupt, and borrow-the-bus wires.** These are open-collector wires. XRDY (pin 3) and RDY (pin 72) hold the processor in a wait. INT*(pin 73) and NMI* (pin 12) ask for an interrupt. VI0*to VI7* (pins 4 to 11) carry the eight old-style vectored interrupt requests. HOLD*(pin 74) asks to borrow the bus, and pHLDA (pin 26) is the answer. TMA0* to TMA3* (pins 55, 56, 57, and 14) are priority lines used when several cards want the bus.

**Disable wires.** ADSB*, CDSB*, SDSB*, and DODSB* tell the processor to let go of the address, the strobes, the status, or the data-out wires. A card that has borrowed the bus uses them.

**Reset wires.** RESET*(pin 75) comes from the front-panel reset switch. POC* (pin 99) is the long reset this card sends out. SLAVE CLR*(pin 54) is the IMSAI EXT CLR line. PHANTOM* (pin 67) lets a boot memory hide the normal memory for a moment.

### What one cycle looks like

Everything the processor does to memory or to a peripheral is one cycle, and every cycle has the same shape. At 2 MHz each step below is 500 ns.

1. **Tick T1.** The address is put on A0–A23 and stays there until the cycle ends. pSYNC goes high. The status word is put on DO0–DO7. In the second half of T1, pSTVAL* goes low to say "the status word is stable." The front panel uses this moment to capture the status lamps, and it looks at bit 5 (the M1 bit) to recognise an instruction fetch.
2. **Tick T2.** pSYNC goes low. On a read, pDBIN goes high, which tells the selected card to drive DI. On a write, the status word is replaced by the byte being written. At the falling edge of the clock the processor looks at RDY and XRDY.
3. **Wait ticks, if needed.** If either ready wire is low, the processor inserts wait ticks and raises PWAIT (pin 27). The front-panel WAIT lamp lights. It samples the ready wires again at every falling clock edge, and it moves on at the next rising edge after both have been seen high.
4. **Tick T3.** On a read, the processor takes the byte from DI at the falling clock edge, and pDBIN falls at the end of the tick. On a write, pWR*is low for most of the tick and rises about 30 ns before the end, so the address and the data are still valid when the write strobe ends. MWRT has the same shape, but only for memory writes; an output to a peripheral pulses pWR* and does not pulse MWRT.

Then the next cycle starts immediately, or the processor sits idle if it has nothing to do.

A memory read of an instruction sets the M1 bit. A plain memory read sets sMEMR and does not set M1. A memory write sets neither. An input sets sINP. An output sets sOUT. An interrupt acknowledge sets sINTA and M1. A halted processor sets sHLTA and holds PWAIT high so the WAIT lamp stays on.

The status word, as it appears on DO0–DO7 during pSYNC, is:

| Kind of cycle         | DO7 MEMR | DO6 INP | DO5 M1 | DO4 OUT | DO3 HLTA | DO1 WO* | DO0 INTA | Byte   |
|-----------------------|----------|---------|--------|---------|----------|---------|----------|--------|
| Instruction fetch     | on       |         | on     |         |          | on      |          | A2 hex |
| Memory read           | on       |         |        |         |          | on      |          | 82 hex |
| Memory write          |          |         |        |         |          |         |          | 00 hex |
| Input from a port     |          | on      |        |         |          | on      |          | 42 hex |
| Output to a port      |          |         |        | on      |          |         |          | 10 hex |
| Interrupt acknowledge |          |         | on     |         |          | on      | on       | 23 hex |
| Halt                  | on       |         |        |         | on       | on      |          | 8A hex |

DO2, the stack bit, is not produced by the demo. WO* (DO1) is high whenever the cycle is not a write. On the front panel the WO lamp therefore lights for reads and stays dark for writes.

### The lines an IMSAI uses differently from the later standard

The IEEE-696 document, written years after the IMSAI, says that pins 20, 53, and 70 are extra grounds. An IMSAI does not treat them that way, and grounding them breaks the front panel.

| Pin | IEEE-696                    | IMSAI                                                                                                                     |
|-----|-----------------------------|---------------------------------------------------------------------------------------------------------------------------|
| 20  | ground                      | UNPROT. The front panel also uses it as a timing point called T5. Grounding it disables the EXAMINE and DEPOSIT circuits. |
| 21  | not defined                 | SS, a front-panel sense line.                                                                                             |
| 25  | pSTVAL*                     | Φ1, the first phase of the 8080 clock.                                                                                    |
| 27  | reserved                    | PWAIT, the wait lamp.                                                                                                     |
| 28  | reserved                    | PINTE, the interrupt-enabled lamp.                                                                                        |
| 53  | ground                      | SSW DSB*. The front panel pulls this low while it forces data onto the processor.                                         |
| 68  | MWRT, made by the processor | MWRT, made by the front panel.                                                                                            |
| 69  | reserved                    | PS, a front-panel sense line.                                                                                             |
| 70  | ground                      | PROT. The front panel itself ties this pin to ground.                                                                     |
| 71  | reserved                    | RUN, a front-panel sense line.                                                                                            |

This board follows the IMSAI column. Pins 20, 21, 69, 70, and 71 are labelled on the schematic and are not driven. Pin 53 is an input. Pin 68 is driven only if a jumper is fitted on JP1, which it must not be in this machine.

## The front panel (CP-A)

The switches and lamps are not wired straight to the S-100 bus. They go to the CP-A board, and that board uses two paths into the processor card.

### The bus

The CP-A watches pSYNC, the clock on pin 24, and the data-out wires. From those it latches the status lamps. It drives XRDY for RUN, STOP, and SINGLE STEP. It drives RESET* from the reset switch. It drives MWRT when a deposit has to be written. It reads PWAIT and PINTE to light those two lamps.

STOP works like this. The panel waits until an instruction fetch is under way (pSYNC high and DO5 high) and then pulls XRDY low at the falling edge of the clock. The processor finishes tick T1, enters tick T2, sees XRDY low, and stays in wait ticks with PWAIT high. The address lamps freeze on the instruction that was about to run, and the data lamps show the byte on the data wires. RUN lets XRDY go high, and the processor continues. SINGLE STEP lets XRDY go high for one instruction and then pulls it low again.

### The ribbon cable

The second path is a 16-wire ribbon cable between the front panel and the processor card. On the original MPU-A this cable lands on the processor's own data pins, the pins that sit between the processor and the bus transceivers. The panel can put a byte on that cable and, at the same time, pull SSW DSB* low. The processor then reads the panel's byte instead of the byte from memory.

The eight data wires of the cable are pulled up to 5 V by 1 kΩ resistors on the processor card. The panel pulls a wire low with an open-collector driver (a 7405) when that bit should be 0. The other eight wires of the cable are ground.

On this board the cable plugs into **J5**. The socket is a 16-pin insulation-displacement header. The schematic assumes the same arrangement as a typical MPU-A cable: odd pins 1, 3, 5, 7, 9, 11, 13, 15 are D0 to D7, and even pins are ground. **Check this against the cable of your own machine before you order or fit the connector.** The pin order is marked on the schematic as something that still has to be confirmed.

### Examine and deposit, on a real processor

EXAMINE forces the processor to read three bytes that did not come from memory: the instruction `C3` (JMP), then the low half of the address switches, then the high half. A real 8080 executes that JMP, so the next instruction fetch happens at the address in the switches, and the panel stops it there. You see that address and that memory byte on the lamps.

DEPOSIT, while the processor is stopped, puts the data switches on the cable, pulls SSW DSB* low, and pulses MWRT. The address is whatever the processor is still holding. The byte has to reach the DO wires, because memory cards listen to DO, not to the private cable. The original processor card's data-out transceiver is pointed at the bus and simply repeats whatever is on the processor's pins, so the deposited byte shows up on DO.

EXAMINE NEXT and DEPOSIT NEXT do the same thing one address further on, by making the processor execute a NOP, which adds one to the address.

### What the panel does to this board

This board reproduces the electrical half of that arrangement.

- SSW DSB* low turns the DI transceiver off, so the S-100 data-in wires and the panel cannot both drive the FPGA.
- The same signal turns the cable transceiver U9 around, so the cable drives the FPGA's data pins.
- The data-out transceiver stays pointed at the bus and repeats those pins, so a deposited byte reaches DO and the memory cards.

The demo program behind this wiring does not execute `C3` or NOP. What that means for the lamps is in the testing chapter.

If the ribbon cable is unplugged, SSW DSB* is held high by the backplane terminator, the DI transceiver works normally, and the card keeps running. The panel switches that depend on the cable do nothing. There is no lamp that says the cable is missing.

## The backplane

The N8VEM version 4 backplane is a nine-slot S-100 motherboard. Slot 1 is spaced one inch from slot 2 so that an IMSAI front panel fits; the other slots are at the usual 0.75 inch. Mounting holes suit an IMSAI or Altair chassis. Power comes in on connector P1 (5.08 mm pitch) or P2 (0.156 inch pitch), each with fuses for +8 V, +16 V, and −16 V. The manual for that board recommends 3 to 10 A on the +8 V fuses and 1 A on the ±16 V fuses, sized to the power supply you actually have.

### The terminator

For a machine at 4 MHz or slower the terminator is optional. At the 6 MHz this board is designed for, the backplane manual says to fit it. Fit it for the demo as well.

The terminator is an active circuit: an LM4250 amplifier and a pair of power transistors hold a rail called `Vacc` at 2.7 V. Adjust trimmer R1 until a meter on that rail reads 2.7 V (the schematic prints "2.63 to 2.7 V" next to it; the board legend says to set 2.7 V). Ten resistor networks, RR1 to RR10, connect almost every signal pin to that rail through 270 ohm. Each network is a **10-pin** single-in-line pack with pin 1 as the common pin and nine 270 ohm resistors. The backplane's bill of materials says "9 pin, 8 resistors," which does not match the schematic. Order the 10-pin part (a Bourns 4610X-101-271 or the same thing from another maker).

Four pins are not on those networks: pin 48 (sHLTA), pin 49 (CLOCK), pin 98 (the stack / ERROR*pin), and pin 99 (POC*). Power and ground pins are not terminated either.

The back expansion connector at the end of the bus can take four more 270 ohm networks instead of a cable to a second backplane. Those are an alternative, not an addition. Fitting them together with RR1–RR10 doubles the load on every driver.

### Jumpers that must stay off

JP1, JP2, and JP3 tie pins 20, 53, and 70 to ground. The backplane manual itself says pin 53 must not be grounded when an Altair or IMSAI front panel is used. The same is true of pin 20, because of the EXAMINE / DEPOSIT lockout. Pin 70 is already grounded on the CP-A, so the backplane jumper is unnecessary.

| Backplane jumper | Pin             | Leave it |
|------------------|-----------------|----------|
| JP1              | 20, UNPROT / T5 | open     |
| JP2              | 53, SSW DSB*    | open     |
| JP3              | 70, PROT        | open     |

With the jumpers open, those three pins sit at 2.7 V through 270 ohm, which is a normal high and does not lock the panel out.

### What this means for the pull-ups on our board

Because the terminator already holds the open-collector lines at 2.7 V, this board does not add its own pull-up to 5 V on those lines. Two lines are the exception, because the terminator does not cover them: pin 98 ERROR* has R22, 2.2 kΩ to 5 V, and pin 99 POC* has R42, 2.2 kΩ to 5 V.

## This board

The KiCad project is `s100-board/s100-template.kicad_sch`. It has four sheets.

| Sheet          | File                      | What is on it                                                                        |
|----------------|---------------------------|--------------------------------------------------------------------------------------|
| Root           | `s100-template.kicad_sch` | The S-100 edge connector and the names of every bus wire.                            |
| FPGA           | `fpga.kicad_sch`          | The two 50-pin sockets J3 and J4 for the Trenz module, and the FPGA pin names.       |
| Level Shifter  | `level_shifter.kicad_sch` | The 5 V ↔ 3.3 V translation, the front-panel connector, and the memory-write jumper. |
| Power Delivery | `power.kicad_sch`         | The two regulators that make 5 V and 3.3 V from the bus +8 V.                        |

### Power

The S-100 +8 V rail is fused on this board (a Bourns MF-RHT300 polyfuse, which holds 3 A) and then fed to a 7805 regulator, U1, in a TO-220 package. That makes +5 V for the level shifters' bus side, the cable pull-ups, and the memory-write gate. A second regulator, U2, an LM1117T-3.3 in the same package, takes that 5 V and makes +3.3 V for the FPGA side of the level shifters and for the Trenz module. The Trenz module must be ordered or jumpered for 3.3 V input/output. Fit a small heatsink on U1: it drops about 3 V, and that difference turns into heat. The unregulated +8 V rail must stay above about 7.5 V, because a 7805 needs roughly 2 V of headroom. The ±16 V rails are not used by this card; they pass through the backplane to other cards.

### The Trenz module and the FPGA sockets

J3 (bank 34 of the FPGA) carries the address, the clocks, the strobes, the status lines, and two control signals for the level shifters. J4 (bank 35) carries the eight data wires, the open-collector lines, the front-panel SSW DSB* input, and the remaining level-shifter controls. Two pins, SPARE0 and SPARE1, are unused.

The module's own 100 MHz oscillator is the timebase everything else is divided down from. The green user light-emitting diode on the module is wired but the demo does not blink it.

Until the FPGA has finished loading its program, pull-up resistors hold the output-enable pins high. Those enables are active low, so a high switches the transceiver off. The one exception is U10, the clock chip, whose enable is tied on. Its inputs have resistors to ground, so PHI and CLOCK stay low until the FPGA starts driving them. During power-up the card therefore does not put an address or data on the bus, and the clocks sit low.

### Level shifters

There is no through-hole version of a single chip that translates both ways between 5 V and 3.3 V, so each direction is its own chip. All of them are the ordinary 20-pin dual in-line package.

A 74ACT245 is powered from 5 V. A 3.3 V high from the FPGA is a valid high for it, and its outputs are 5 V, which is what the S-100 bus expects. Each pin is specified to sink 24 mA, and the ground pin is rated for 200 mA, so a byte of all zeros (about 70 mA through the backplane terminator) stays inside the rating. The part to order is SN74ACT245N. Its direction pin is tied to 5 V, so it always drives from the FPGA side toward the bus. A 74LVC245 is powered from 3.3 V. Its inputs accept 5 V from the bus, and its outputs are 3.3 V, which is what the FPGA accepts. Its direction pin is tied to ground, so it always drives from the bus toward the FPGA.

The direction is strapped with a wire and cannot be turned around. Turning a 74ACT245 around would drive 5 V into an FPGA pin. The two FPGA pins `LS_BUS_DIR` and `LS_DATA_DIR` are still on the connector, with pull-ups, so the pin plan does not change. They are not wired to a direction pin.

| Chip | Part      | What it carries                                      | Output enable                                      |
|------|-----------|------------------------------------------------------|----------------------------------------------------|
| U5   | 74ACT245 | Address A0–A7, toward the bus                        | `LS_BUS_OE*`                                       |
| U6   | 74ACT245 | Address A8–A15, toward the bus                       | `LS_BUS_OE*`                                       |
| U7   | 74ACT245 | Address A16–A23, toward the bus                      | `LS_BUS_OE*`                                       |
| U8   | 74ACT245 | The seven status lines, toward the bus               | `LS_BUS_OE*`                                       |
| U9   | 74ACT245 | pSYNC, pSTVAL*, pDBIN, pWR*, toward the bus          | `LS_BUS_OE*`                                       |
| U10  | 74ACT245 | PHI, pHLDA, PWAIT, CLOCK, PINTE, toward the bus      | Tied on. Inputs pulled down.                       |
| U11  | 74ACT245 | Data out, DO0–DO7, toward the bus                    | `LS_DO_OE*`                                        |
| U12  | 74ACT245 | FPGA toward the front-panel cable                    | Off while the panel is active, and until the FPGA enables the bus |
| U13  | 74LVC245  | Data in, DI0–DI7, toward the FPGA                    | Off while the panel is active                      |
| U14  | 74LVC245  | Front-panel cable toward the FPGA                    | On while SSW DSB* is low                           |

U5 through U9 share one enable, `LS_BUS_OE*`. In normal running they are enabled. They switch off together when another card borrows the bus (HOLD* / pHLDA, or one of the disable lines ADSB*, CDSB*, SDSB*).

U10 stays enabled while the bus is borrowed. PHI, CLOCK, pHLDA, PWAIT, and PINTE have to keep running so the front panel and the borrowing card still have a clock and can see that the processor has let go. The five inputs of U10 each have 10 kΩ to ground, so those lines rest at 0 V until the FPGA is configured and drives them.

U11, U13, and the two cable chips are all wired, on the FPGA side, to the same eight pins. That is safe because only one of them drives those pins at a time. U11 points at the bus, so on the FPGA side it only listens. U13 listens to DI and drives the FPGA pins only during a read. U14 drives the FPGA pins only while the front panel is forcing a byte onto the cable.

U15, U16, and U17 make the front-panel steering and the memory-write pulse. They are ordinary 14-pin gates. Unused gates in the same package have their inputs tied to ground.

- U15 is a 74HCT04 inverter. One gate turns SSW DSB* into the opposite sense. A 3.3 V high is a valid high for this gate.
- U16 is a 74HCT32, two OR gates. While the front panel pulls SSW DSB* low, one gate forces the DI chip off and the other forces the cable driver off, even if the FPGA is asking to read. The cable driver is also held off until the FPGA enables the bus, so it stays quiet during configuration.
- U17 is a 74HCT02 NOR gate. Its output is high only when pWR* is low and sOUT is low, which is exactly a memory write. Header **JP1** connects that output to MWRT. **Leave the jumper off.** In an IMSAI the CP-A drives MWRT, and two drivers on that wire would fight. Fit the jumper only in a chassis that has no front panel and whose memory cards expect the processor card to create MWRT. U17 is a small gate (about 4 mA). That is enough for a short bus; a chassis with many memory cards may want a stronger driver later.

### The open-collector translators

Twenty-nine TN0702 transistors, Q1 to Q29, translate the shared open-collector lines. The order code is TN0702N3-G, a small transistor in the TO-92 package. The gate is tied to 3.3 V. A low on the FPGA side pulls the bus side low, and a low on the bus side pulls the FPGA side low. The FPGA either pulls its side low or lets go; it never drives a high. The 10 kΩ resistor on the FPGA side is the bias for that transistor. The bus side has no resistor of its own, except R22 on ERROR* and R42 on POC*, as described in the backplane chapter.

This part is specified to start conducting by 1.0 V, and its on-resistance is guaranteed at 3 V of gate drive (2.5 Ω at most). With the gate at 3.3 V it is fully on, and the bus wire is pulled to a solid low. Fit it with the flat face toward you and the pins pointing down: source, gate, drain, from left to right. That matches the footprint on the board.

MWRT and SSW DSB* pass through these transistors as inputs only. The FPGA listens to them and does not pull them.

### Pins this board drives, and pins it only listens to

Driven as a normal output: A0–A23, the seven status lines, pSYNC, pSTVAL*(or Φ1), pDBIN, pWR*, PHI, CLOCK, pHLDA, PWAIT, PINTE, and DO0–DO7.

Driven as an open collector, and only pulled low when needed: POC*. The demo never pulls the interrupt, hold, or disable lines; the wiring is there for the later processor program.

Listened to: DI0–DI7, RDY, XRDY, INT*, NMI*, HOLD*, the eight VI* lines, the four TMA*lines, the four disable lines, RESET*, SLAVE CLR*, PHANTOM*, PWRFAIL*, ERROR*, MWRT, and SSW DSB*.

Not connected to the FPGA: SIXTN*and sXTRQ* (the 16-bit request pair; this card is 8-bit only), UNPROT, SS, PS, PROT, RUN, and the ±16 V rails.

## What the demo does

The VHDL in `s100-fpga/` is three layers.

`main.vhdl` is the only file that knows about pins and level shifters. It turns the wires into named bus signals and keeps the transceivers from driving into each other.

`s100_master.vhdl` produces the bus cycles described in the S-100 chapter: the clock, pSYNC, the status word, pDBIN, pWR*, the wait states, the hold handshake, and POC*. A processor core talks to it with a request and an acknowledge, not with bus timing.

`s100_application.vhdl` is the demo that stands in for that processor. Replacing the demo with an 8085 is a change inside this one file. The other two stay.

At power-up, and whenever RESET*is low, the master holds POC* low. After RESET*is released it waits 20 ms (2 000 000 ticks of the 100 MHz clock) and then lets POC* rise. The same 20 ms follows configuration of the FPGA. While POC* is low, the demo is held reset and no cycle runs.

After that the demo asks for cycles one at a time:

1. It reads an instruction byte from address 0000, then 0001, then 0002, and so on, each one marked as an instruction fetch (status byte A2 hex). The address lamps count. The byte it reads is kept only so it can be written out later; it is not executed.
2. When the low half of the address rolls from FF to 00 (every 256 reads), it writes that saved byte to output port F0 hex, then reads port F0 hex back, then goes on with instruction fetches. The address lamps show 00F0 for those two cycles, and the status lamps show OUT and then INP.

The clock on pin 24 is 2 MHz. Pin 49 is a separate 2 MHz square wave. PWAIT goes high only while XRDY or RDY holds a cycle. PINTE stays dark, because the demo reports interrupts as disabled. The demo never halts and never asks for the bus itself.

Because the demo does not execute instructions:

- STOP freezes the lamps, and RUN continues the count. SINGLE STEP advances one cycle, which is usually one address.
- EXAMINE does **not** move the lamps to the address in the switches. The panel still jams `C3` and the address bytes onto the data wires, and the card will read them, but the demo then adds one to its own address instead of jumping.
- DEPOSIT can still write. While the card is stopped it holds the current address, the panel places the switch data on DO through the cable, and the panel pulses MWRT. A memory card at that address stores the byte. The address is the demo's address, not an address chosen with EXAMINE.
- No program will run, and an interrupt from another card is ignored.

## Testing the demo

Do these with the terminator fitted and set to 2.7 V, JP1 on this board open, JP1–JP3 on the backplane open, and the ribbon cable plugged into J5 only after its pin order has been checked. A memory card is needed for the deposit test. It is not needed to see the lamps count: with no memory, the terminator holds DI at a high level, so a read returns FF hex and the data lamps are all on.

Watch the bus with the front panel first. A logic analyser on pSYNC, PHI, pDBIN, pWR*, XRDY, PWAIT, and DO0–DO7 is useful for the timing checks, and it is not required to see that the lamps behave.

### Power-up and reset

1. Switch the machine on and confirm +8 V at the backplane, then +5 V and +3.3 V on this board, before you rely on the lamps.
2. For the first 20 ms after the FPGA has loaded, POC*(pin 99) should be low, and the address and data transceivers should be off. After that POC* rises and the address lamps start at 0000 and count.
3. Press the front-panel RESET switch. RESET*(pin 75) goes low, this board answers by pulling POC* low, the count stops, and about 20 ms after you release RESET the count starts again at 0000.
4. While the FPGA is loading, no address or data wire should be driven by this card. The pull-ups on the level-shifter controls are what guarantee that. If the bus is being fought during power-up, those pull-ups or the enable wiring are the place to look.

### The running count

1. With RUN on and nothing pulling XRDY low, the address lamps count in binary. They will look blurred. That is expected at 2 MHz.
2. The status lamps show MEMR, M1, and WO for these fetches (status byte A2 hex). WO lights because the cycle is not a write.
3. Every 256 addresses the pattern breaks for two cycles: the address lamps show 00F0, first with OUT lit, then with INP lit. If no board answers port F0, the byte read back is FF because of the terminator.
4. Pin 24 is a 2 MHz square wave. Pin 49 is a 2 MHz square wave too, and it is not the same signal: it does not have to line up with pin 24. Pin 49 is not terminated on this backplane, so if it looks rounded or rings, that is the first place to suspect.

### Stop, run, and single step

1. STOP pulls XRDY low on the next instruction fetch. PWAIT goes high, the WAIT lamp lights, and the address freezes. The data lamps settle on the byte of that cycle instead of blurring.
2. RUN lets the count continue from that address. The address must not restart at 0000.
3. SINGLE STEP advances one fetch per press, so the address increases by one. Once every 256 steps the step lands on the port-F0 output, and the next step on the port-F0 input, with address 00F0 and the OUT or INP lamp. The step after that returns to instruction fetches.
4. On a fetch that is stopped in a wait tick, pDBIN stays high, pSYNC stays low, and the address does not change. pWR* stays high.

### The cable and deposit

 1. Unplug the ribbon cable, leave RUN on, and confirm the count still runs. Plug it back.
 2. STOP the machine. Set the data switches to a recognisable pattern such as A5 hex (1010 0101). Press DEPOSIT, with a memory card in the machine at the address shown on the lamps. MWRT (pin 68) must pulse once, and it must come from the front panel: JP1 is open, so this board is not driving it. EXAMINE will not bring that address back (see above), so check the stored byte by reading that memory another way, or by stopping at the same address again and looking at the data lamps.
 3. During that deposit, SSW DSB* goes low, the DI transceiver is off, and the byte on DO matches the data switches. This is the check that U9, U12, and the data-out repeater are wired the right way.
 4. Press EXAMINE. The address lamps will step, not jump to the address switches. On a logic analyser you should still see the panel pull SSW DSB* low and place `C3`, then the low address byte, then the high address byte, on the cable. Seeing those bytes proves the cable and the transceiver. The lamps not jumping proves only that the demo is not a processor, which is expected.

### Wait from a memory card, and bus borrowing

 1. If you have a card that pulls RDY (pin 72) low to ask for wait states, confirm that PWAIT lights for those cycles and that the cycle completes once RDY is released. The demo treats RDY and XRDY the same way.
 2. If you have a direct-memory-access card, confirm that HOLD*low makes this board raise pHLDA, release the address, status, strobe, and data-out wires, and keep PHI, CLOCK, PWAIT, and PINTE running. When HOLD* is released, the count resumes. This is optional; the demo itself never generates a hold.

### Things the demo will not show

 1. PINTE stays off. INT*and NMI* can be asserted by another card and this board will see them, but the demo does not act on them.
 2. The halt lamp stays off. The demo never executes HLT.
 3. EXAMINE, EXAMINE NEXT, and DEPOSIT NEXT do not move the address to the switches or to the next address. That behaviour arrives with the processor core.
 4. No instruction, no CP/M, and no front-panel program switch will execute.

### After the demo looks right

 1. Decide pin 25. The default program drives pSTVAL*: low during the second half of tick T1, high otherwise. An original IMSAI front panel was designed around Φ1 on that pin. If STOP, the status lamps, or EXAMINE misbehave while everything else in this chapter looks right, rebuild the FPGA program with the pin-25 option set to Φ1 and repeat the stop and status-lamp checks.
 2. Only when this list is green does it make sense to replace the demo with the 8085 and raise the clock. The board is laid out for up to 6 MHz. The backplane terminator is required at that speed. The 8085 program has to use the same request-and-acknowledge handshake as the demo: keep the request stable until the acknowledge, and present the next request within half a tick if cycles should run back to back.

## Before you order the board

- Confirm the J5 pin order against your CP-A cable.
- Order 10-pin, 9-resistor, 270 ohm networks for the backplane, not the 9-pin parts in its bill of materials.
- Fit the terminator and set R1 to 2.7 V.
- Leave this board's JP1 open, and leave the backplane's JP1, JP2, and JP3 open.
- sHLTA and CLOCK are unterminated on this backplane. If either one rings at 6 MHz, add a termination for those two pins rather than refitting the whole network.
- The data-out transceiver repeats the FPGA data pins onto DO even during a read, so that deposit works. A card that samples DO while pDBIN is high will see the byte being read. That is how an original processor card behaved.

## Where the files are

| Path                              | Contents                                                                                  |
|-----------------------------------|-------------------------------------------------------------------------------------------|
| `s100-bus-master/`                | KiCad schematic of this card.                                                             |
| `s100-bus-master-fpga/main.vhdl`  | Pins and level-shifter control.                                                           |
| `s100-bus-master-fpga/s100_master.vhdl`      | Bus cycles, clocks, wait, hold, POC*.                                                     |
| `s100-bus-master-fpga/s100_application.vhdl` | The demo. This is the file a processor core replaces.                                     |
| `s100-bus-master-fpga/s100_pkg.vhdl`         | The names of the bus signals shared by those files.                                       |
| `s100-bus-master-fpga/te0725_s100.xdc`       | The FPGA pin assignment for the Trenz module.                                             |
| `S100_Backplane_V4/`              | KiCad design and manual of the N8VEM backplane.                                           |
| `simulator/`                      | A software IMSAI that runs on a PC. It is not this board and it does not test the wiring. |
