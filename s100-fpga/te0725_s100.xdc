## te0725_s100.xdc - generated from the pin plan (pinplan.py); do not edit by hand
## Trenz TE0725 (Artix-7 XC7A35T/100T CSG324), S-100 CPU-replacement board
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## on-board 100 MHz oscillator and user LED
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports clk_100mhz]
create_clock -name clk_100mhz -period 10.000 [get_ports clk_100mhz]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports led]

## PHI is an FPGA output in CPU mode; in bus-monitor mode it may be used as a clock input.
## The bus lines are asynchronous to clk_100mhz; they are synchronized in logic.
set_false_path -from [get_ports {f_* }] -to [all_registers]
set_false_path -from [all_registers] -to [get_ports {f_* ls_* }]

## header J3 (bank 34)
set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {f_a[0]}]  ;# F_A0 = J3-3 B34_L24_N
set_property -dict {PACKAGE_PIN R8 IOSTANDARD LVCMOS33} [get_ports {f_a[1]}]  ;# F_A1 = J3-4 B34_L24_P
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS33} [get_ports {f_a[2]}]  ;# F_A2 = J3-7 B34_L21_N
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS33} [get_ports {f_a[3]}]  ;# F_A3 = J3-8 B34_L21_P
set_property -dict {PACKAGE_PIN N6 IOSTANDARD LVCMOS33} [get_ports {f_a[4]}]  ;# F_A4 = J3-9 B34_L18_N
set_property -dict {PACKAGE_PIN M6 IOSTANDARD LVCMOS33} [get_ports {f_a[5]}]  ;# F_A5 = J3-10 B34_L18_P
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33} [get_ports {f_a[6]}]  ;# F_A6 = J3-11 B34_L22_N
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {f_a[7]}]  ;# F_A7 = J3-12 B34_L22_P
set_property -dict {PACKAGE_PIN V6 IOSTANDARD LVCMOS33} [get_ports {f_a[8]}]  ;# F_A8 = J3-13 B34_L20_N
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {f_a[9]}]  ;# F_A9 = J3-14 B34_L20_P
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33} [get_ports {f_a[10]}]  ;# F_A10 = J3-15 B34_L23_N
set_property -dict {PACKAGE_PIN R7 IOSTANDARD LVCMOS33} [get_ports {f_a[11]}]  ;# F_A11 = J3-16 B34_L23_P
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {f_a[12]}]  ;# F_A12 = J3-17 B34_L10_N
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {f_a[13]}]  ;# F_A13 = J3-18 B34_L10_P
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS33} [get_ports {f_a[14]}]  ;# F_A14 = J3-19 B34_L19_P
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {f_a[15]}]  ;# F_A15 = J3-20 B34_L19_N
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {f_a[16]}]  ;# F_A16 = J3-21 B34_L8_P
set_property -dict {PACKAGE_PIN U3 IOSTANDARD LVCMOS33} [get_ports {f_a[17]}]  ;# F_A17 = J3-22 B34_L8_N
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {f_a[18]}]  ;# F_A18 = J3-23 B34_L9_N
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports {f_a[19]}]  ;# F_A19 = J3-24 B34_L9_P
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {f_a[20]}]  ;# F_A20 = J3-25 B34_L7_N
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {f_a[21]}]  ;# F_A21 = J3-26 B34_L7_P
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports {f_a[22]}]  ;# F_A22 = J3-27 B34_L13_P MRCC
set_property -dict {PACKAGE_PIN P5 IOSTANDARD LVCMOS33} [get_ports {f_a[23]}]  ;# F_A23 = J3-28 B34_L13_N
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {f_phi}]  ;# F_PHI = J3-29 B34_L12_P MRCC
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports {f_phlda}]  ;# F_pHLDA = J3-30 B34_L12_N
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS33} [get_ports {f_pwait}]  ;# F_PWAIT = J3-31 B34_L11_N
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {f_clock}]  ;# F_CLOCK = J3-32 B34_L11_P SRCC
set_property -dict {PACKAGE_PIN P4 IOSTANDARD LVCMOS33} [get_ports {f_pinte}]  ;# F_PINTE = J3-33 B34_L14_P SRCC
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {f_psync}]  ;# F_pSYNC = J3-34 B34_L14_N
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports {f_pstval_n}]  ;# F_pSTVAL* = J3-35 B34_L16_N
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {f_pdbin}]  ;# F_pDBIN = J3-36 B34_L16_P
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {f_pwr_n}]  ;# F_pWR* = J3-37 B34_L17_N
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS33} [get_ports {f_sm1}]  ;# F_sM1 = J3-38 B34_L17_P
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {f_sout}]  ;# F_sOUT = J3-39 B34_L15_N
set_property -dict {PACKAGE_PIN P2 IOSTANDARD LVCMOS33} [get_ports {f_sinp}]  ;# F_sINP = J3-40 B34_L15_P
set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {f_smemr}]  ;# F_sMEMR = J3-41 B34_L3_N
set_property -dict {PACKAGE_PIN N2 IOSTANDARD LVCMOS33} [get_ports {f_shlta}]  ;# F_sHLTA = J3-42 B34_L3_P
set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33} [get_ports {f_sinta}]  ;# F_sINTA = J3-43 B34_L1_N
set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports {f_swo_n}]  ;# F_sWO* = J3-44 B34_L1_P
set_property -dict {PACKAGE_PIN M3 IOSTANDARD LVCMOS33} [get_ports {ls_bus_dir}]  ;# LS_BUS_DIR = J3-47 B34_L4_P
set_property -dict {PACKAGE_PIN M2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {spare1}]  ;# SPARE1 = J3-48 B34_L4_N

## header J4 (bank 35)
set_property -dict {PACKAGE_PIN K1 IOSTANDARD LVCMOS33} [get_ports {f_d[0]}]  ;# F_D0 = J4-3 B35_L23_N
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports {f_d[1]}]  ;# F_D1 = J4-4 B35_L23_P
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {f_d[2]}]  ;# F_D2 = J4-7 B35_L15_N
set_property -dict {PACKAGE_PIN H2 IOSTANDARD LVCMOS33} [get_ports {f_d[3]}]  ;# F_D3 = J4-8 B35_L15_P
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports {f_d[4]}]  ;# F_D4 = J4-9 B35_L13_N
set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports {f_d[5]}]  ;# F_D5 = J4-10 B35_L13_P MRCC
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports {f_d[6]}]  ;# F_D6 = J4-11 B35_L12_N
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {f_d[7]}]  ;# F_D7 = J4-12 B35_L12_P MRCC
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_rdy}]  ;# F_RDY = J4-13 B35_L22_P
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_xrdy}]  ;# F_XRDY = J4-14 B35_L22_N
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_int_n}]  ;# F_INT* = J4-15 B35_L17_N
set_property -dict {PACKAGE_PIN H1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_nmi_n}]  ;# F_NMI* = J4-16 B35_L17_P
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_hold_n}]  ;# F_HOLD* = J4-17 B35_L18_N
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_mwrt}]  ;# F_MWRT = J4-18 B35_L18_P
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_pwrfail_n}]  ;# F_PWRFAIL* = J4-19 B35_L14_N
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_error_n}]  ;# F_ERROR* = J4-20 B35_L14_P SRCC
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[0]}]  ;# F_VI0* = J4-21 B35_L16_P
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[1]}]  ;# F_VI1* = J4-22 B35_L16_N
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[2]}]  ;# F_VI2* = J4-23 B35_L9_N
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[3]}]  ;# F_VI3* = J4-24 B35_L9_P
set_property -dict {PACKAGE_PIN B3 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[4]}]  ;# F_VI4* = J4-25 B35_L10_P
set_property -dict {PACKAGE_PIN B2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[5]}]  ;# F_VI5* = J4-26 B35_L10_N
set_property -dict {PACKAGE_PIN A3 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[6]}]  ;# F_VI6* = J4-27 B35_L8_N
set_property -dict {PACKAGE_PIN A4 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_vi_n[7]}]  ;# F_VI7* = J4-28 B35_L8_P
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_tma_n[0]}]  ;# F_TMA0* = J4-29 B35_L11_N
set_property -dict {PACKAGE_PIN D5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_tma_n[1]}]  ;# F_TMA1* = J4-30 B35_L11_P SRCC
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_tma_n[2]}]  ;# F_TMA2* = J4-31 B35_L3_N
set_property -dict {PACKAGE_PIN A6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_tma_n[3]}]  ;# F_TMA3* = J4-32 B35_L3_P
set_property -dict {PACKAGE_PIN B6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_sdsb_n}]  ;# F_SDSB* = J4-33 B35_L2_N
set_property -dict {PACKAGE_PIN B7 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_cdsb_n}]  ;# F_CDSB* = J4-34 B35_L2_P
set_property -dict {PACKAGE_PIN B4 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_adsb_n}]  ;# F_ADSB* = J4-35 B35_L7_N
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_dodsb_n}]  ;# F_DODSB* = J4-36 B35_L7_P
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_reset_n}]  ;# F_RESET* = J4-37 B35_L1_N
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_slave_clr_n}]  ;# F_SLAVE_CLR* = J4-38 B35_L1_P
set_property -dict {PACKAGE_PIN E5 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_poc_n}]  ;# F_POC* = J4-39 B35_L5_N
set_property -dict {PACKAGE_PIN E6 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_phantom_n}]  ;# F_PHANTOM* = J4-40 B35_L5_P
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS33} [get_ports {ls_data_dir}]  ;# LS_DATA_DIR = J4-41 B35_L6_N
set_property -dict {PACKAGE_PIN E7 IOSTANDARD LVCMOS33} [get_ports {ls_do_oe_n}]  ;# LS_DO_OE* = J4-42 B35_L6_P
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports {ls_di_oe_n}]  ;# LS_DI_OE* = J4-43 B35_L19_P
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {ls_bus_oe_n}]  ;# LS_BUS_OE* = J4-44 B35_L19_N
set_property -dict {PACKAGE_PIN C7 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {f_ssw_dsb_n}]  ;# F_SSW_DSB* = J4-47 B35_L4_N
set_property -dict {PACKAGE_PIN D8 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {spare0}]  ;# SPARE0 = J4-48 B35_L4_P

