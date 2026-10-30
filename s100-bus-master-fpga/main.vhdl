-------------------------------------------------------------------------------
-- main.vhdl - top level for the TE0725 S-100 CPU-replacement board
--
-- This file owns the physical pins. It converts them into the S-100 bus
-- records of s100_pkg and drives the level-shifter control lines, so that
-- the bus master (s100_master.vhdl) and the application only deal with bus
-- signals that carry their S-100 names.
--
-- Port names follow the net names on the FPGA sheet of the KiCad project:
--   f_<name>   FPGA (3.3 V) side of the S-100 signal <name>; an S-100
--              asterisk (active low) becomes the suffix _n
--   ls_<name>  control line of the level shifters (LS)
--
-- Level shifters are through-hole, and the direction is strapped on the board
-- (a 74ACT245 reversed would drive 5 V into the FPGA). ls_bus_dir and
-- ls_data_dir are still driven so the pin plan stays stable; nothing on the
-- board connects them.
--   address/status/strobes  74ACT245, FPGA toward bus, enable ls_bus_oe_n
--   PHI, CLOCK, pHLDA,      74ACT245, FPGA toward bus, always enabled
--     PWAIT, PINTE
--   DO0..7  <- F_D          74ACT245, FPGA toward bus, enable ls_do_oe_n
--   DI0..7  -> F_D          74LVC245,  bus toward FPGA, enable ls_di_oe_n
--                           (disabled in hardware while SSW_DSB* is low)
--   CP-A cable -> F_D       74LVC245 enabled while SSW_DSB* is low
--   F_D -> CP-A cable       74ACT245, off while SSW_DSB* is low and until
--                           the bus enable is on
-- While SSW_DSB* is low the cable transceiver drives F_D in hardware, so the
-- FPGA pin is forced high-Z immediately. A two-stage synchronizer then keeps
-- it high-Z for one further clk after that synchronized signal goes high, so
-- the cable driver has released before the FPGA drives again.
-- The 29 open-collector lines use TN0702 open-drain translators and need no
-- control line; the FPGA drives them with '0' or 'Z'. MWRT and SSW_DSB* are
-- inputs only.
--
-- Turn-around rule: the FPGA pins and a level shifter must never drive the
-- same 3.3 V net at the same time. Every direction change is therefore
-- sequenced over clk_100mhz cycles (10 ns each):
--   to bus : shifter direction to bus, then FPGA outputs on
--   to FPGA: FPGA outputs off, then shifter direction to FPGA
-- On the shared data port the current driver is switched off one cycle
-- before the next one is switched on.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.s100_pkg.all;

entity main is
  generic (
    -- Kept so a later board can wire the direction pins again. On this board
    -- the 74ACT245 and 74LVC245 direction pins are strapped, and ls_bus_dir
    -- / ls_data_dir are not connected. '1' would mean "towards the FPGA" on
    -- the old dual-supply transceiver.
    LS_DIR_TO_FPGA : std_logic := '1';
    -- length of the POC* pulse after configuration / RESET* in clk cycles (20 ms)
    POC_CLKS       : positive  := 2_000_000
  );
  port (
    clk_100mhz : in  std_logic;   -- TE0725 on-board oscillator (ball P17)
    led        : out std_logic;   -- TE0725 green user LED (ball M16)

    -- J3, FPGA bank 34 -----------------------------------------------------
    f_a        : inout std_logic_vector(23 downto 0);
    f_phi      : inout std_logic;
    f_phlda    : inout std_logic;
    f_pwait    : inout std_logic;
    f_clock    : inout std_logic;
    f_pinte    : inout std_logic;
    f_psync    : inout std_logic;
    f_pstval_n : inout std_logic;
    f_pdbin    : inout std_logic;
    f_pwr_n    : inout std_logic;
    f_sm1      : inout std_logic;
    f_sout     : inout std_logic;
    f_sinp     : inout std_logic;
    f_smemr    : inout std_logic;
    f_shlta    : inout std_logic;
    f_sinta    : inout std_logic;
    f_swo_n    : inout std_logic;
    ls_bus_dir : out   std_logic;
    spare1     : inout std_logic;

    -- J4, FPGA bank 35 -----------------------------------------------------
    f_d           : inout std_logic_vector(7 downto 0);
    f_rdy         : inout std_logic;
    f_xrdy        : inout std_logic;
    f_int_n       : inout std_logic;
    f_nmi_n       : inout std_logic;
    f_hold_n      : inout std_logic;
    f_mwrt        : in    std_logic;
    f_pwrfail_n   : inout std_logic;
    f_error_n     : inout std_logic;
    f_vi_n        : inout std_logic_vector(7 downto 0);
    f_tma_n       : inout std_logic_vector(3 downto 0);
    f_sdsb_n      : inout std_logic;
    f_cdsb_n      : inout std_logic;
    f_adsb_n      : inout std_logic;
    f_dodsb_n     : inout std_logic;
    f_reset_n     : inout std_logic;
    f_slave_clr_n : inout std_logic;
    f_poc_n       : inout std_logic;
    f_phantom_n   : inout std_logic;
    ls_data_dir   : out   std_logic;
    ls_do_oe_n    : out   std_logic;
    ls_di_oe_n    : out   std_logic;
    ls_bus_oe_n   : out   std_logic;
    f_ssw_dsb_n   : in    std_logic;
    spare0        : inout std_logic
  );
end entity main;

architecture rtl of main is

  signal clk     : std_logic;
  signal bus_in  : s100_in_t;
  signal bus_out : s100_out_t;

  -- open-drain driver: '1' request pulls the line low, otherwise release it
  function od(pull : std_logic) return std_logic is
  begin
    if pull = '1' then
      return '0';
    else
      return 'Z';
    end if;
  end function;

  function od(pull : std_logic_vector) return std_logic_vector is
    variable r : std_logic_vector(pull'range);
  begin
    for i in pull'range loop
      r(i) := od(pull(i));
    end loop;
    return r;
  end function;

  -- shifter DIR pin value for a wanted direction
  function dir_pin(to_bus : std_logic) return std_logic is
  begin
    if to_bus = '1' then
      return not LS_DIR_TO_FPGA;
    else
      return LS_DIR_TO_FPGA;
    end if;
  end function;

  -- turn-around state of the push-pull lines
  signal bus_to_bus, bus_oe : std_logic := '0';

  -- data port state
  signal data_master : std_logic := '0';  -- orientation of the DO/DI transceivers
  signal d_oe        : std_logic := '0';  -- FPGA drives f_d
  signal do_en       : std_logic := '0';
  signal di_en       : std_logic := '0';
  signal tgt_do, tgt_di : std_logic;
  signal d_r         : std_logic_vector(7 downto 0) := (others => '0');
  -- synchronized SSW_DSB* (active low). Index 0 is the newest sample.
  -- '1' means the panel has released the cable.
  signal ssw_sync    : std_logic_vector(1 downto 0) := (others => '0');
  -- FPGA must not drive f_d while the panel owns the cable, nor on the
  -- first clock after the panel lets go. Starts blocked so configuration
  -- does not drive into a panel that is already jamming.
  signal ssw_block   : std_logic := '1';
  signal fpga_drive  : std_logic;

  signal heartbeat : unsigned(26 downto 0) := (others => '0');

begin

  clk <= clk_100mhz;

  ---------------------------------------------------------------------------
  -- application
  ---------------------------------------------------------------------------
  app : entity work.s100_application
    generic map (
      POC_CLKS => POC_CLKS
    )
    port map (
      clk     => clk,
      bus_in  => bus_in,
      bus_out => bus_out
    );

  ---------------------------------------------------------------------------
  -- push-pull lines: address, status, strobes, processor state
  ---------------------------------------------------------------------------
  bus_turnaround : process (clk)
  begin
    if rising_edge(clk) then
      bus_to_bus <= bus_out.master or bus_oe;
      bus_oe     <= bus_out.master and bus_to_bus;
    end if;
  end process;

  ls_bus_dir  <= dir_pin(bus_to_bus);
  ls_bus_oe_n <= not bus_out.bus_enable;

  f_a        <= bus_out.a        when bus_oe = '1' else (others => 'Z');
  f_sm1      <= bus_out.sm1      when bus_oe = '1' else 'Z';
  f_sout     <= bus_out.sout     when bus_oe = '1' else 'Z';
  f_sinp     <= bus_out.sinp     when bus_oe = '1' else 'Z';
  f_smemr    <= bus_out.smemr    when bus_oe = '1' else 'Z';
  f_shlta    <= bus_out.shlta    when bus_oe = '1' else 'Z';
  f_sinta    <= bus_out.sinta    when bus_oe = '1' else 'Z';
  f_swo_n    <= bus_out.swo_n    when bus_oe = '1' else 'Z';
  f_psync    <= bus_out.psync    when bus_oe = '1' else 'Z';
  f_pstval_n <= bus_out.pstval_n when bus_oe = '1' else 'Z';
  f_pdbin    <= bus_out.pdbin    when bus_oe = '1' else 'Z';
  f_pwr_n    <= bus_out.pwr_n    when bus_oe = '1' else 'Z';
  f_phlda    <= bus_out.phlda    when bus_oe = '1' else 'Z';
  f_phi      <= bus_out.phi      when bus_oe = '1' else 'Z';
  f_clock    <= bus_out.clock    when bus_oe = '1' else 'Z';
  f_pwait    <= bus_out.pwait    when bus_oe = '1' else 'Z';
  f_pinte    <= bus_out.pinte    when bus_oe = '1' else 'Z';

  bus_in.a        <= f_a;
  bus_in.sm1      <= f_sm1;
  bus_in.sout     <= f_sout;
  bus_in.sinp     <= f_sinp;
  bus_in.smemr    <= f_smemr;
  bus_in.shlta    <= f_shlta;
  bus_in.sinta    <= f_sinta;
  bus_in.swo_n    <= f_swo_n;
  bus_in.psync    <= f_psync;
  bus_in.pstval_n <= f_pstval_n;
  bus_in.pdbin    <= f_pdbin;
  bus_in.pwr_n    <= f_pwr_n;
  bus_in.phlda    <= f_phlda;
  bus_in.phi      <= f_phi;
  bus_in.clock    <= f_clock;
  bus_in.pwait    <= f_pwait;
  bus_in.pinte    <= f_pinte;
  bus_in.mwrt     <= f_mwrt;

  ---------------------------------------------------------------------------
  -- data port: one 8-bit FPGA port, DO / DI / CP-A cable transceivers
  --
  -- Sources that can drive the 3.3 V data net:
  --   FPGA                     d_oe
  --   DI transceiver           di_en and data_master = '1'
  --   DO transceiver           do_en and data_master = '0'
  --   CP-A cable transceiver   SSW_DSB* low (hardware; the same signal
  --                            disables the DI transceiver in hardware)
  -- Only one of them may be on. A transceiver that points away from the
  -- FPGA (DO in CPU role, DI in monitor role) may be switched at any time.
  ---------------------------------------------------------------------------
  -- a transceiver pointing towards the FPGA is never enabled while the FPGA drives
  tgt_di <= bus_out.di_enable and not (bus_out.d_drive and bus_out.data_master);
  tgt_do <= bus_out.do_enable and not (bus_out.d_drive and not bus_out.data_master);
  -- hardware enables the cable driver while SSW_DSB* is low, so this pin stays off
  fpga_drive <= bus_out.d_drive and not ssw_block;

  -- two flips synchronize the async pin; ssw_block then stays set for the
  -- clock on which the synchronized pin is first seen high again
  ssw_guard : process (clk)
  begin
    if rising_edge(clk) then
      ssw_sync  <= ssw_sync(0) & to_x01(f_ssw_dsb_n);
      ssw_block <= not ssw_sync(1);
    end if;
  end process;

  data_sequencer : process (clk)
    variable src_now, src_tgt : std_logic_vector(2 downto 0);  -- (fpga, di, do) drivers
  begin
    if rising_edge(clk) then
      if data_master /= bus_out.data_master then
        -- orientation change: everything off, then update ls_data_dir.
        -- This board straps the transceiver direction in hardware, so that
        -- pin is unused; the enables above are what the board follows.
        if do_en = '1' or di_en = '1' or d_oe = '1' then
          do_en <= '0';
          di_en <= '0';
          d_oe  <= '0';
        else
          data_master <= bus_out.data_master;
        end if;
      else
        src_now := d_oe & (di_en and data_master) & (do_en and not data_master);
        src_tgt := fpga_drive & (tgt_di and data_master) & (tgt_do and not data_master);
        if src_now /= "000" and src_now /= src_tgt then
          -- a driver is on that must go off: break before make
          d_oe  <= '0';
          di_en <= di_en and not data_master;
          do_en <= do_en and data_master;
        else
          d_oe  <= fpga_drive;
          di_en <= tgt_di;
          do_en <= tgt_do;
        end if;
      end if;
    end if;
  end process;

  ls_data_dir <= dir_pin(not data_master);   -- DIR pin of the DI transceiver
  ls_do_oe_n  <= not do_en;
  ls_di_oe_n  <= not di_en;

  -- SSW_DSB* low forces the pin off in the same cycle. ssw_block keeps it off
  -- for one clock after the synchronized pin has gone high again.
  f_d <= bus_out.d when d_oe = '1' and ssw_block = '0' and to_x01(f_ssw_dsb_n) = '1'
         else (others => 'Z');

  data_capture : process (clk)
  begin
    if rising_edge(clk) then
      if d_oe = '0' then
        d_r <= to_x01(f_d);   -- to_x01: simulated pull-ups ('H') read as '1'
      end if;
    end if;
  end process;

  bus_in.d       <= d_r;
  bus_in.d_valid <= not d_oe;

  ---------------------------------------------------------------------------
  -- open-collector lines
  ---------------------------------------------------------------------------
  f_rdy         <= od(bus_out.rdy_pull);
  f_xrdy        <= od(bus_out.xrdy_pull);
  f_int_n       <= od(bus_out.int_pull);
  f_nmi_n       <= od(bus_out.nmi_pull);
  f_hold_n      <= od(bus_out.hold_pull);
  f_pwrfail_n   <= od(bus_out.pwrfail_pull);
  f_error_n     <= od(bus_out.error_pull);
  f_vi_n        <= od(bus_out.vi_pull);
  f_tma_n       <= od(bus_out.tma_pull);
  f_sdsb_n      <= od(bus_out.sdsb_pull);
  f_cdsb_n      <= od(bus_out.cdsb_pull);
  f_adsb_n      <= od(bus_out.adsb_pull);
  f_dodsb_n     <= od(bus_out.dodsb_pull);
  f_reset_n     <= od(bus_out.reset_pull);
  f_slave_clr_n <= od(bus_out.slave_clr_pull);
  f_poc_n       <= od(bus_out.poc_pull);
  f_phantom_n   <= od(bus_out.phantom_pull);

  bus_in.rdy         <= f_rdy;
  bus_in.xrdy        <= f_xrdy;
  bus_in.int_n       <= f_int_n;
  bus_in.nmi_n       <= f_nmi_n;
  bus_in.hold_n      <= f_hold_n;
  bus_in.pwrfail_n   <= f_pwrfail_n;
  bus_in.error_n     <= f_error_n;
  bus_in.vi_n        <= f_vi_n;
  bus_in.tma_n       <= f_tma_n;
  bus_in.sdsb_n      <= f_sdsb_n;
  bus_in.cdsb_n      <= f_cdsb_n;
  bus_in.adsb_n      <= f_adsb_n;
  bus_in.dodsb_n     <= f_dodsb_n;
  bus_in.reset_n     <= f_reset_n;
  bus_in.slave_clr_n <= f_slave_clr_n;
  bus_in.poc_n       <= f_poc_n;
  bus_in.phantom_n   <= f_phantom_n;
  bus_in.ssw_dsb_n   <= f_ssw_dsb_n;

  ---------------------------------------------------------------------------
  -- misc
  ---------------------------------------------------------------------------
  spare0 <= 'Z';
  spare1 <= 'Z';

  -- LED toggles about every 0.67 s: proof that the bitstream is running
  heartbeat_counter : process (clk)
  begin
    if rising_edge(clk) then
      heartbeat <= heartbeat + 1;
    end if;
  end process;
  led <= heartbeat(heartbeat'high);

end architecture rtl;
