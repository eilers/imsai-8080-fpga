-------------------------------------------------------------------------------
-- s100_application.vhdl - what the board does on the bus
--
-- Replace the body of this entity with the processor core. This demo wires
-- a tiny "exerciser" to the bus master: after reset it fetches op-codes
-- from consecutive memory addresses like an 8080 executing NOPs, so the
-- IMSAI address lamps count and the data lamps show memory contents. The
-- front panel can STOP, SINGLE STEP, EXAMINE and DEPOSIT as usual because
-- the master honours XRDY and the forced data bytes. Every 256th cycle the
-- exerciser writes the last fetched byte to output port F0h (sOUT) and
-- reads it back (sINP) so that I/O cycles can be checked too.
--
-- The processor core should drive cyc_* exactly like this demo does and
-- use cyc_rdata after cyc_ack.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.s100_pkg.all;

entity s100_application is
  generic (
    POC_CLKS : positive := 2_000_000
  );
  port (
    clk     : in  std_logic;
    bus_in  : in  s100_in_t;
    bus_out : out s100_out_t
  );
end entity s100_application;

architecture demo of s100_application is

  signal reset     : std_logic;
  signal cyc_req   : std_logic := '0';
  signal cyc_kind  : s100_cycle_t := CYC_MEM_READ;
  signal cyc_m1    : std_logic := '1';
  signal cyc_addr  : std_logic_vector(23 downto 0) := (others => '0');
  signal cyc_wdata : std_logic_vector(7 downto 0) := (others => '0');
  signal cyc_rdata : std_logic_vector(7 downto 0);
  signal cyc_ack   : std_logic;

  signal pc       : unsigned(15 downto 0) := (others => '0');
  signal last     : std_logic_vector(7 downto 0) := (others => '0');
  type step_t is (FETCH, PORT_WRITE, PORT_READ);
  signal step     : step_t := FETCH;

begin

  master : entity work.s100_master
    generic map (
      POC_CLKS => POC_CLKS
    )
    port map (
      clk       => clk,
      bus_in    => bus_in,
      bus_out   => bus_out,
      reset     => reset,
      phi_tick  => open,
      cyc_req   => cyc_req,
      cyc_kind  => cyc_kind,
      cyc_m1    => cyc_m1,
      cyc_addr  => cyc_addr,
      cyc_wdata => cyc_wdata,
      cyc_rdata => cyc_rdata,
      cyc_ack   => cyc_ack,
      halt      => '0',
      inte      => '0',
      int_req   => open,
      nmi_req   => open,
      in_hold   => open
    );

  exerciser : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        pc       <= (others => '0');
        step     <= FETCH;
        cyc_req  <= '0';
        cyc_kind <= CYC_MEM_READ;
        cyc_m1   <= '1';
        cyc_addr <= (others => '0');
      elsif cyc_req = '0' then
        -- present the next request
        cyc_req <= '1';
        case step is
          when FETCH =>
            cyc_kind <= CYC_MEM_READ;
            cyc_m1   <= '1';
            cyc_addr <= x"00" & std_logic_vector(pc);
          when PORT_WRITE =>
            cyc_kind  <= CYC_IO_WRITE;
            cyc_m1    <= '0';
            cyc_addr  <= x"0000" & x"F0";
            cyc_wdata <= last;
          when PORT_READ =>
            cyc_kind <= CYC_IO_READ;
            cyc_m1   <= '0';
            cyc_addr <= x"0000" & x"F0";
        end case;
      elsif cyc_ack = '1' then
        cyc_req <= '0';
        case step is
          when FETCH =>
            last <= cyc_rdata;
            pc   <= pc + 1;
            if pc(7 downto 0) = x"FF" then
              step <= PORT_WRITE;
            end if;
          when PORT_WRITE =>
            step <= PORT_READ;
          when PORT_READ =>
            step <= FETCH;
        end case;
      end if;
    end if;
  end process;

end architecture demo;
