# S-100 compatible Computer

This project contains a full S-100 bus compliant micro computer based on the IMSAI-8080 design (which is basically a clone of the Altair 8800).
But instead of using old and hard to find computer parts, we use FPGAs to emulate their behavior.

**Please note:** This project is work in process! So please do not expect anything working for now.

This project contains the following components:

## S-100 Backplane (Motherboard)

The PCB here was not tested or used. I just ordered the board from [SmallRun](https://smallrun.net/shop/retrodisks/9-slot-s100-motherboard-with-integrated-power).
The Source of this version can be found on [GitHub](https://github.com/nullvalue0/S100MotherboardV5)

See folder `./S100MotherboardV5`

## S-100 Front Panel (CP-A)

This was also taken from [s100Computers](https://www.s100computers.com/My%20System%20Pages/FP%20Board/FP%20Board.htm) and cleaned to work with KiCad V10.

See folder `./S100-front-panel`

**Note:** This is not the design of the original CP-A provided by IMSAI in 1975. This one confirms the IEEE 696 and therefore works a bit different.

## IMSAI Front Panel (CP-A)

This is created from the original schmatics by IMSAI MPU-A REV.A 2/76.
In order to get a working reference, I decided to order the full front panel from [parastream.com](https://www.parastream.com/imsai/boards/cp-a-r.aspx) that belongs to the design here.

Important: This design is not fully IEEE 696 compatible without modifications as documented on the web page. Our Bus Master board is compatible to IMSAI and IEEE 696 if you select the correct FPGA core for it.

See folder `./imsai_cp-a`

## Bus Master

This is my work. The idea is to use only level shifters in order to connect a FPGA directly to the S-100 bus. All kind of S-100 boards that behave as bus master can therefore be recreated just be replacing the FPGA code. The first approach is to run a full IMSAI CPU board (MPU-A) on this board.
This board uses the [TE0725-04-21C-1-A](https://www.trenz-electronic.de/de/FPGA-Modul-mit-AMD-Artix-7A15T-1C-2-x-50-Pin-Header-3-5-x-7-3-cm/TE0725-04-21C-1-A) from Trenz, based on the AMD Artix™ 7A15T-1C.

See folder `./s100-bus-master`

The first FPGA implementation can be found in the folder `./s100-bus-master-fpga`. This code only contains some test code for debugging the S100 bus.

## References

* https://www.s100computers.com/index.html
* https://www.retrotechnology.com/herbs_stuff/s100.html
* https://github.com/nullvalue0/S100MotherboardV5
