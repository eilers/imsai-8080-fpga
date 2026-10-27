-------------------------------------------------------------------------------
-- s100_master.vhdl - permanent bus master (CPU card) for the S-100 bus
--
-- Generates 8080-style S-100 bus cycles for a processor core that lives in
-- the FPGA (for example an 8085 core). The core only sees a simple request /
-- acknowledge interface; this block produces PHI, CLOCK, pSYNC, pSTVAL*,
-- pDBIN, pWR*, the status lines, the 8080 status word on the data bus during
-- pSYNC, PWAIT, PINTE, pHLDA and POC*, and it honours RDY/XRDY wait states,
-- HOLD (DMA), the disable lines and RESET*.
--
-- Bus cycle (one T state = one PHI period, TPHI = 500 ns at 2 MHz):
--
--   T1  address and status valid, pSYNC high, status word on the data bus,
--       pSTVAL* low in the second half of T1
--   T2  pSYNC low; read: pDBIN high. RDY and XRDY are sampled at the
--       falling PHI edge. If either is low the cycle continues with TW.
--   TW  wait state, PWAIT high, RDY/XRDY sampled again every TW
--   T3  write: pWR* low, write data on DO (already valid since T2); pWR*
--       ends 30 ns before the end of T3 so address, status and data are
--       held after its trailing edge (MWRT follows pWR*);
--       read: data sampled at the falling PHI edge, pDBIN high until the
--       end of T3. cyc_ack is pulsed at the falling PHI edge of T3.
--
-- The IMSAI CP-A front panel stops the processor by taking XRDY low while
-- pSYNC and the M1 status bit are active; the cycle then waits in TW with
-- PWAIT high, which lights the WAIT lamp. EXAMINE/DEPOSIT force bytes onto
-- the processor data bus through the cable and SSW_DSB*; the hardware
-- switches the data transceivers, the core simply reads the forced byte.
--
-- Timing of the core interface: cyc_req, cyc_kind, cyc_m1, cyc_addr and
-- cyc_wdata must be stable from the clock in which cyc_req is first seen
-- until cyc_ack. After cyc_ack the core has half a T state (at least 25
-- clk cycles at 2 MHz PHI) to drop cyc_req or to present the next request;
-- a request that is still pending at the end of T3 starts the next T1
-- immediately (back-to-back cycles).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.s100_pkg.all;

entity s100_master is
  generic (
    CLK_HZ     : positive := 100_000_000;  -- clk frequency
    PHI_HZ     : positive :=   2_000_000;  -- bus clock PHI (2 MHz on an IMSAI)
    CLOCK_HZ   : positive :=   2_000_000;  -- CLOCK line (pin 49), 2 MHz per IEEE-696
    PIN25_PHI1 : boolean  := false;        -- true: drive PHI1 (IMSAI) instead of pSTVAL* on pin 25
    POC_CLKS   : positive := 2_000_000     -- POC* pulse length in clk cycles (20 ms)
  );
  port (
    clk     : in  std_logic;
    bus_in  : in  s100_in_t;
    bus_out : out s100_out_t;

    -- core interface ------------------------------------------------------
    reset     : out std_logic;                      -- '1' while POC*/RESET* active
    phi_tick  : out std_logic;                      -- one clk pulse per rising PHI edge
    cyc_req   : in  std_logic;
    cyc_kind  : in  s100_cycle_t;
    cyc_m1    : in  std_logic;                      -- op-code fetch (sets sM1)
    cyc_addr  : in  std_logic_vector(23 downto 0);
    cyc_wdata : in  std_logic_vector(7 downto 0);
    cyc_rdata : out std_logic_vector(7 downto 0);   -- valid from cyc_ack on
    cyc_ack   : out std_logic;                      -- one clk pulse
    halt      : in  std_logic;                      -- core executed HLT: sHLTA + PWAIT
    inte      : in  std_logic;                      -- interrupt enable flag -> PINTE
    int_req   : out std_logic;                      -- INT* asserted (synchronized)
    nmi_req   : out std_logic;                      -- NMI* asserted (synchronized)
    in_hold   : out std_logic                       -- bus given to a temporary master
  );
end entity s100_master;

architecture rtl of s100_master is

  constant PHI_DIV   : positive := CLK_HZ / PHI_HZ;
  -- pWR* is released this many clk cycles before the end of T3 so that
  -- address, status and data stay valid after its trailing edge
  constant HOLD_CLKS : positive := 3;
  constant CLOCK_DIV : positive := CLK_HZ / CLOCK_HZ;

  -- PHI generator. The T state starts with the rising PHI edge (count 0).
  signal phi_cnt   : integer range 0 to PHI_DIV - 1 := 0;
  signal phi       : std_logic := '0';
  signal phi1      : std_logic := '0';
  signal phi_rise  : std_logic := '0';   -- clk pulse in the cycle where phi goes high
  signal phi_fall  : std_logic := '0';
  signal phi_pre   : std_logic := '0';   -- clk pulse HOLD_CLKS cycles before phi_rise
  signal clock_cnt : integer range 0 to CLOCK_DIV - 1 := 0;
  signal clock_q   : std_logic := '0';

  -- synchronized bus inputs (2 flip-flops each)
  signal rdy_s, xrdy_s, hold_s, reset_s, int_s, nmi_s : std_logic_vector(1 downto 0) := (others => '1');
  signal adsb_s, cdsb_s, sdsb_s, dodsb_s             : std_logic_vector(1 downto 0) := (others => '1');

  type state_t is (ST_IDLE, ST_T1, ST_T2, ST_TW, ST_T3, ST_HALT1, ST_HALT, ST_HOLD);
  signal state : state_t := ST_IDLE;

  -- registered bus outputs
  signal a_r      : std_logic_vector(23 downto 0) := (others => '0');
  signal status_r : std_logic_vector(7 downto 0)  := x"02";  -- 8080 status word
  signal psync_r, pdbin_r : std_logic := '0';
  signal pstval_n_r       : std_logic;
  signal pwr_n_r          : std_logic := '1';
  signal pwait_r, phlda_r                      : std_logic := '0';
  signal d_r       : std_logic_vector(7 downto 0) := (others => '0');
  signal d_drive_r : std_logic := '1';
  signal di_en_r   : std_logic := '0';
  signal wdata_r   : std_logic_vector(7 downto 0) := (others => '0');
  signal is_read   : std_logic := '0';
  signal ready_r   : std_logic := '1';
  signal rdata_r   : std_logic_vector(7 downto 0) := (others => '0');
  signal ack_r     : std_logic := '0';

  signal poc_cnt   : integer range 0 to POC_CLKS := 0;
  signal poc_r     : std_logic := '1';

  -- 8080 status word bits
  constant SB_INTA  : integer := 0;
  constant SB_WO_N  : integer := 1;
  constant SB_STACK : integer := 2;
  constant SB_HLTA  : integer := 3;
  constant SB_OUT   : integer := 4;
  constant SB_M1    : integer := 5;
  constant SB_INP   : integer := 6;
  constant SB_MEMR  : integer := 7;

  function status_word(kind : s100_cycle_t; m1 : std_logic) return std_logic_vector is
    variable s : std_logic_vector(7 downto 0) := (others => '0');
  begin
    case kind is
      when CYC_MEM_READ  => s(SB_MEMR) := '1'; s(SB_WO_N) := '1'; s(SB_M1) := m1;
      when CYC_MEM_WRITE => null;
      when CYC_IO_READ   => s(SB_INP)  := '1'; s(SB_WO_N) := '1';
      when CYC_IO_WRITE  => s(SB_OUT)  := '1';
      when CYC_INT_ACK   => s(SB_INTA) := '1'; s(SB_WO_N) := '1'; s(SB_M1) := '1';
    end case;
    return s;
  end function;

  constant STATUS_HALT : std_logic_vector(7 downto 0) := (SB_HLTA => '1', SB_WO_N => '1', SB_MEMR => '1', others => '0');

begin

  pstval_n_r <= '0' when state = ST_T1 and phi = '0' else '1';

  ---------------------------------------------------------------------------
  -- clocks
  ---------------------------------------------------------------------------
  clocks : process (clk)
  begin
    if rising_edge(clk) then
      phi_rise <= '0';
      phi_fall <= '0';
      phi_pre  <= '0';
      if phi_cnt = PHI_DIV - 1 - HOLD_CLKS then
        phi_pre <= '1';
      end if;
      if phi_cnt = PHI_DIV - 1 then
        phi_cnt  <= 0;
        phi      <= '1';
        phi_rise <= '1';
      else
        phi_cnt <= phi_cnt + 1;
        if phi_cnt = PHI_DIV / 2 - 1 then
          phi      <= '0';
          phi_fall <= '1';
        end if;
      end if;
      -- PHI1 (8080 clock phase 1): short pulse just before PHI rises
      if phi_cnt >= (PHI_DIV * 3) / 4 - 1 and phi_cnt < (PHI_DIV * 7) / 8 - 1 then
        phi1 <= '1';
      else
        phi1 <= '0';
      end if;
      if clock_cnt = CLOCK_DIV - 1 then
        clock_cnt <= 0;
        clock_q   <= not clock_q;
      elsif clock_cnt = CLOCK_DIV / 2 - 1 then
        clock_cnt <= clock_cnt + 1;
        clock_q   <= not clock_q;
      else
        clock_cnt <= clock_cnt + 1;
      end if;
    end if;
  end process;

  phi_tick <= phi_rise;

  ---------------------------------------------------------------------------
  -- input synchronizers
  ---------------------------------------------------------------------------
  sync : process (clk)
  begin
    if rising_edge(clk) then
      -- to_x01 maps the 'H' of simulated pull-ups to '1'; free in hardware
      rdy_s   <= rdy_s(0)   & to_x01(bus_in.rdy);
      xrdy_s  <= xrdy_s(0)  & to_x01(bus_in.xrdy);
      hold_s  <= hold_s(0)  & to_x01(bus_in.hold_n);
      reset_s <= reset_s(0) & to_x01(bus_in.reset_n);
      int_s   <= int_s(0)   & to_x01(bus_in.int_n);
      nmi_s   <= nmi_s(0)   & to_x01(bus_in.nmi_n);
      adsb_s  <= adsb_s(0)  & to_x01(bus_in.adsb_n);
      cdsb_s  <= cdsb_s(0)  & to_x01(bus_in.cdsb_n);
      sdsb_s  <= sdsb_s(0)  & to_x01(bus_in.sdsb_n);
      dodsb_s <= dodsb_s(0) & to_x01(bus_in.dodsb_n);
    end if;
  end process;

  int_req <= not int_s(1);
  nmi_req <= not nmi_s(1);

  ---------------------------------------------------------------------------
  -- power-on clear: POC* low after configuration and while RESET* is low,
  -- released POC_CLKS after RESET* goes high
  ---------------------------------------------------------------------------
  poc : process (clk)
  begin
    if rising_edge(clk) then
      if reset_s(1) = '0' then
        poc_cnt <= 0;
        poc_r   <= '1';
      elsif poc_cnt /= POC_CLKS then
        poc_cnt <= poc_cnt + 1;
      else
        poc_r <= '0';
      end if;
    end if;
  end process;

  reset <= poc_r;

  ---------------------------------------------------------------------------
  -- bus cycle state machine; state changes on the rising PHI edge
  ---------------------------------------------------------------------------
  cycle : process (clk)
    variable start_cycle : boolean;   -- a T1 begins with this rising PHI edge
    variable start_halt  : boolean;
  begin
    if rising_edge(clk) then
      ack_r <= '0';

      if poc_r = '1' then
        state     <= ST_IDLE;
        psync_r   <= '0';
        pdbin_r   <= '0';
        pwr_n_r   <= '1';
        pwait_r   <= '0';
        phlda_r   <= '0';
        di_en_r   <= '0';
        d_drive_r <= '1';
        status_r  <= (others => '0');
      else
        start_cycle := phi_rise = '1' and cyc_req = '1' and
                       ((state = ST_IDLE and hold_s(1) = '1') or state = ST_T3);
        start_halt  := phi_rise = '1' and cyc_req = '0' and halt = '1' and
                       state = ST_IDLE and hold_s(1) = '1';

        case state is

          when ST_IDLE =>
            if phi_rise = '1' and hold_s(1) = '0' then
              state   <= ST_HOLD;
              phlda_r <= '1';
            end if;

          when ST_HOLD =>
            if phi_rise = '1' and hold_s(1) = '1' then
              phlda_r <= '0';
              state   <= ST_IDLE;
            end if;

          -- T1: one PHI period with pSYNC; entered at phi_rise
          when ST_T1 =>
            if phi_rise = '1' then
              state   <= ST_T2;
              psync_r <= '0';
              if is_read = '1' then
                pdbin_r   <= '1';
                d_drive_r <= '0';   -- release the data port for DI / cable
                di_en_r   <= '1';
              else
                d_r <= wdata_r;     -- write data replaces the status word
              end if;
            end if;

          -- RDY/XRDY are sampled at the falling PHI edge; the decision
          -- (T3 or another TW) is taken at the following rising edge
          when ST_T2 | ST_TW =>
            if phi_fall = '1' then
              ready_r <= rdy_s(1) and xrdy_s(1);
            end if;
            if phi_rise = '1' then
              if ready_r = '1' then
                state   <= ST_T3;
                pwait_r <= '0';
                if is_read = '0' then
                  pwr_n_r <= '0';
                end if;
              else
                state   <= ST_TW;
                pwait_r <= '1';
              end if;
            end if;

          when ST_T3 =>
            if phi_fall = '1' then
              rdata_r <= bus_in.d;
              ack_r   <= '1';
            end if;
            if phi_pre = '1' then
              pwr_n_r <= '1';         -- trailing edge with address/data hold
            end if;
            if phi_rise = '1' then
              pdbin_r   <= '0';
              di_en_r   <= '0';
              d_drive_r <= '1';
              state     <= ST_IDLE;   -- overridden below for back-to-back cycles
            end if;

          -- HLT: one status cycle, then wait with PWAIT high until an
          -- interrupt makes the core drop halt
          when ST_HALT1 =>
            if phi_rise = '1' then
              psync_r <= '0';
              pwait_r <= '1';
              state   <= ST_HALT;
            end if;

          when ST_HALT =>
            if phi_rise = '1' and halt = '0' then
              pwait_r <= '0';
              state   <= ST_IDLE;
            end if;

        end case;

        if start_cycle then
          state    <= ST_T1;
          a_r      <= cyc_addr;
          status_r <= status_word(cyc_kind, cyc_m1);
          d_r      <= status_word(cyc_kind, cyc_m1);
          wdata_r  <= cyc_wdata;
          psync_r  <= '1';
          if cyc_kind = CYC_MEM_WRITE or cyc_kind = CYC_IO_WRITE then
            is_read <= '0';
          else
            is_read <= '1';
          end if;
        elsif start_halt then
          state    <= ST_HALT1;
          status_r <= STATUS_HALT;
          d_r      <= STATUS_HALT;
          psync_r  <= '1';
        end if;
      end if;
    end if;
  end process;

  cyc_ack   <= ack_r;
  cyc_rdata <= rdata_r;
  in_hold   <= phlda_r;

  ---------------------------------------------------------------------------
  -- bus outputs
  ---------------------------------------------------------------------------
  bus_out.master     <= '1';
  bus_out.bus_enable <= (not phlda_r) and adsb_s(1) and cdsb_s(1) and sdsb_s(1);

  bus_out.a     <= a_r;
  bus_out.sm1   <= status_r(SB_M1);
  bus_out.sout  <= status_r(SB_OUT);
  bus_out.sinp  <= status_r(SB_INP);
  bus_out.smemr <= status_r(SB_MEMR);
  bus_out.shlta <= status_r(SB_HLTA);
  bus_out.sinta <= status_r(SB_INTA);
  bus_out.swo_n <= status_r(SB_WO_N);

  bus_out.psync    <= psync_r;
  bus_out.pstval_n <= phi1 when PIN25_PHI1 else pstval_n_r;
  bus_out.pdbin    <= pdbin_r;
  bus_out.pwr_n    <= pwr_n_r;

  bus_out.phlda <= phlda_r;
  bus_out.phi   <= phi;
  bus_out.clock <= clock_q;
  bus_out.pwait <= pwait_r;
  bus_out.pinte <= inte;

  bus_out.data_master <= '1';
  bus_out.d           <= d_r;
  bus_out.d_drive     <= d_drive_r;
  bus_out.do_enable   <= (not phlda_r) and dodsb_s(1);
  bus_out.di_enable   <= di_en_r;

  bus_out.rdy_pull       <= '0';
  bus_out.xrdy_pull      <= '0';
  bus_out.int_pull       <= '0';
  bus_out.nmi_pull       <= '0';
  bus_out.hold_pull      <= '0';
  bus_out.pwrfail_pull   <= '0';
  bus_out.error_pull     <= '0';
  bus_out.vi_pull        <= (others => '0');
  bus_out.tma_pull       <= (others => '0');
  bus_out.sdsb_pull      <= '0';
  bus_out.cdsb_pull      <= '0';
  bus_out.adsb_pull      <= '0';
  bus_out.dodsb_pull     <= '0';
  bus_out.reset_pull     <= '0';
  bus_out.slave_clr_pull <= '0';
  bus_out.poc_pull       <= poc_r;
  bus_out.phantom_pull   <= '0';

end architecture rtl;
