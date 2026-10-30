# S-100 Client Card — Schematic Design

This KiCad project is the separate slave-card counterpart to
`s100-bus-master`.  It uses the same Trenz TE0725 module but reverses the
interface topology: the card receives the master-owned signals and drives
only the S-100 `DI` byte during its selected reads.

## First personality: 64 KiB RAM

The first FPGA image decodes every 16-bit address (`0000`–`FFFF`).

| S-100 signals            | Direction at this card | Level-shifter implementation                                              |
|--------------------------|------------------------|---------------------------------------------------------------------------|
| A0–A23                   | S-100 → FPGA           | U10–U12, 74LVC245A, direction pin held low (B→A), output enable held low  |
| DO0–DO7                  | S-100 → FPGA           | U14, 74LVC245A, direction pin held low (B→A), output enable `LS_DO_OE*`   |
| DI0–DI7                  | FPGA → S-100           | U15, 74ACT245, direction pin held at 5 V (A→B), output enable `LS_DI_OE*` |
| pDBIN, pWR*, sMEMR, sOUT | S-100 → FPGA           | U13, 74LVC245A, direction pin held low (B→A), output enable held low      |
| RESET*, POC*             | S-100 → FPGA           | Q1 and Q2, TN0702N3-G, gate at 3.3 V, FPGA listens only                   |

The `DI` 74ACT245 and `DO` 74LVC245 have independent active-low output
enables.  The FPGA always disables both while configuring.  During a read it
first disables the `DO` receiver, waits one 100 MHz cycle, then enables the
`DI` driver.  During a write it leaves the `DI` driver disabled and samples
the byte from `DO`.

`pDBIN` plus `sMEMR` selects a memory read.  `pWR*` low while `sOUT` is low
selects a memory write.  This avoids responding to an output-port write.

## Drawn sheets

`s100-bus-client.kicad_sch` is the root sheet. It holds the S-100 edge
connector. The other sheets are:

- `fpga.kicad_sch` — TE0725 headers J3 and J4
- `power.kicad_sch` — +8 V fuse, 7805, LM1117-3.3, and the heatsink
- `level_shifter.kicad_sch` — slave transceivers drawn for this card

On the copied FPGA sheet the two enable names are swapped relative to the
bus-master sheet, so they match `s-100-bus-client-fpga/te0725_s100_client.xdc`.
Header J4 pin 42 (`LS_DI_OE*`, ball E7) enables the data-in driver U15.
Header J4 pin 43 (`LS_DO_OE*`, ball G6) enables the data-out receiver U14.
Both enables are pulled to 3.3 V by R11 and R10, so both transceivers stay
off while the FPGA configures, and neither FPGA pin is pulled up to 5 V.

U13 leaves four channels unused. Those bus-side inputs are tied to 0 V.
The FPGA side of those channels is left open.

## Before board layout

1. Order a 74LVC245A that accepts 5 V on an input while powered from 3.3 V.
   The schematic cites the Texas Instruments SN74LVC245A.
2. Confirm the TE0725 J3 and J4 orientation against the module drawing before
   layout. The header symbols warn that the local `TE` symbol library is not
   installed; the symbols are embedded in the sheet.
