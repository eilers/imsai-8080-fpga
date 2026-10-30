# S-100 Client FPGA

This is the FPGA image for the S-100 client card.  The first image is a
64 KiB memory card that occupies addresses `0000` through `FFFF`.

## Bus behaviour

The card responds only to memory cycles:

- A read is selected by `sMEMR` and `pDBIN`.  The card enables its `DI0` through
  `DI7` driver only for that read.
- A write is selected by `pWR*` low while `sOUT` is low.  The byte is sampled
  from `DO0` through `DO7`.
- `RESET*` and `POC*` immediately disable the `DI` driver.  They do not clear
  RAM: clearing 64 KiB in flip-flops would prevent normal block-RAM inference,
  and real S-100 RAM cards retain undefined data after reset.

All S-100 inputs are asynchronous to the TE0725 100 MHz oscillator.  The
implementation synchronizes control strobes before acting on them.  At 6 MHz
the response leaves more than 100 ns of the `pDBIN` interval after the
two-stage synchronizer and the break-before-make data turn-around.

## Build inputs

- `s100_client_ram.vhdl` — top-level design and 64 KiB RAM controller
- `te0725_s100_client.xdc` — TE0725 pin constraints

The constraints deliberately leave unused S-100 pins unconstrained.  Add pins
only after the corresponding client-card schematic and level-shifter channel
exist.
