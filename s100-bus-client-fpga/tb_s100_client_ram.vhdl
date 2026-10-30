library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_s100_client_ram is
end entity tb_s100_client_ram;

architecture test of tb_s100_client_ram is
  signal clk        : std_logic := '0';
  signal led        : std_logic;
  signal a          : std_logic_vector(23 downto 0) := (others => '0');
  signal d          : std_logic_vector(7 downto 0) := (others => 'Z');
  signal do_data    : std_logic_vector(7 downto 0) := (others => '0');
  signal do_drive   : std_logic := '0';
  signal pdbin      : std_logic := '0';
  signal pwr_n      : std_logic := '1';
  signal smemr      : std_logic := '0';
  signal sout       : std_logic := '0';
  signal reset_n    : std_logic := '0';
  signal poc_n      : std_logic := '0';
  signal di_oe_n    : std_logic;
  signal do_oe_n    : std_logic;
begin
  clk <= not clk after 5 ns;
  d <= do_data when do_drive = '1' else (others => 'Z');

  dut : entity work.s100_client_ram
    port map (
      clk_100mhz => clk,
      led => led,
      f_a => a,
      f_d => d,
      f_pdbin => pdbin,
      f_pwr_n => pwr_n,
      f_smemr => smemr,
      f_sout => sout,
      f_reset_n => reset_n,
      f_poc_n => poc_n,
      ls_di_oe_n => di_oe_n,
      ls_do_oe_n => do_oe_n
    );

  stimulus : process
  begin
    wait for 50 ns;
    reset_n <= '1';
    poc_n <= '1';
    wait for 50 ns;

    -- Write A5 to address 1234.  This models the byte on S-100 DO.
    a(15 downto 0) <= x"1234";
    do_data <= x"A5";
    do_drive <= '1';
    pwr_n <= '0';
    wait for 100 ns;
    pwr_n <= '1';
    do_drive <= '0';
    wait for 80 ns;

    -- A selected memory read must tri-state the DO receiver, then drive DI.
    pdbin <= '1';
    smemr <= '1';
    wait for 100 ns;
    assert di_oe_n = '0' report "DI driver was not enabled" severity failure;
    assert do_oe_n = '1' report "DO receiver was not disabled" severity failure;
    assert d = x"A5" report "RAM read did not return the written byte" severity failure;

    pdbin <= '0';
    smemr <= '0';
    wait for 80 ns;
    assert di_oe_n = '1' report "DI driver remained enabled after read" severity failure;
    assert d = (d'range => 'Z') report "FPGA still drove DI after read" severity failure;

    -- An output-port write must not alter memory, even though pWR* goes low.
    do_data <= x"5A";
    do_drive <= '1';
    sout <= '1';
    pwr_n <= '0';
    wait for 100 ns;
    pwr_n <= '1';
    sout <= '0';
    do_drive <= '0';
    wait for 80 ns;

    pdbin <= '1';
    smemr <= '1';
    wait for 100 ns;
    assert d = x"A5" report "Output-port write changed RAM" severity failure;
    assert false report "Test passed" severity note;
    wait;
  end process;
end architecture test;
