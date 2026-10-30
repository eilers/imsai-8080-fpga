-------------------------------------------------------------------------------
-- 64 KiB S-100 RAM client for the TE0725.
--
-- The card is a bus slave.  Address, DO, status, and strobe signals enter the
-- FPGA through 5 V to 3.3 V receivers.  Only DI is driven, and only during a
-- selected memory-read cycle.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity s100_client_ram is
  port (
    clk_100mhz : in  std_logic;
    led        : out std_logic;

    -- S-100 signals after the level translators.
    f_a        : in  std_logic_vector(23 downto 0);
    f_d        : inout std_logic_vector(7 downto 0);
    f_pdbin    : in  std_logic;
    f_pwr_n    : in  std_logic;
    f_smemr    : in  std_logic;
    f_sout     : in  std_logic;
    f_reset_n  : in  std_logic;
    f_poc_n    : in  std_logic;

    -- 74ACT245 FPGA-to-DI enable and 74LVC245 DO-to-FPGA enable.
    -- Both enables are active low.  Pull-ups on the board keep both disabled
    -- while the FPGA configures.
    ls_di_oe_n : out std_logic;
    ls_do_oe_n : out std_logic
  );
end entity s100_client_ram;

architecture rtl of s100_client_ram is
  type ram_t is array (0 to 65535) of std_logic_vector(7 downto 0);
  signal ram : ram_t;

  type read_state_t is (READ_IDLE, READ_BREAK, READ_DRIVE);
  signal read_state : read_state_t := READ_IDLE;

  signal a_q         : std_logic_vector(15 downto 0) := (others => '0');
  signal d_q         : std_logic_vector(7 downto 0) := (others => '0');
  signal pdbin_meta  : std_logic := '0';
  signal pdbin_s     : std_logic := '0';
  signal pwr_meta    : std_logic := '1';
  signal pwr_s       : std_logic := '1';
  signal smemr_meta  : std_logic := '0';
  signal smemr_s     : std_logic := '0';
  signal sout_meta   : std_logic := '0';
  signal sout_s      : std_logic := '0';
  signal reset_meta  : std_logic := '0';
  signal reset_s     : std_logic := '0';
  signal poc_meta    : std_logic := '0';
  signal poc_s       : std_logic := '0';
  signal write_seen  : std_logic := '0';
  signal led_counter : unsigned(25 downto 0) := (others => '0');

  signal reset_active : std_logic;
  signal read_request : std_logic;
  signal write_request : std_logic;
begin
  -- The RAM covers the complete 8080 address space.  A later ROM, peripheral,
  -- or banked-RAM personality changes this decoder, not the electrical I/O.
  reset_active  <= (not reset_s) or (not poc_s);
  read_request  <= pdbin_s and smemr_s and not reset_active;
  write_request <= (not pwr_s) and (not sout_s) and not reset_active;

  -- Do not ever drive the shared FPGA data nets while the DO receiver is
  -- enabled.  READ_BREAK provides a 10 ns dead interval before DI is enabled.
  ls_di_oe_n <= '0' when read_state = READ_DRIVE else '1';
  ls_do_oe_n <= '1' when read_state /= READ_IDLE else '0';
  f_d <= d_q when read_state = READ_DRIVE else (others => 'Z');

  process (clk_100mhz)
  begin
    if rising_edge(clk_100mhz) then
      -- Synchronize only control strobes.  Address and DO are held stable for
      -- a complete S-100 cycle, so they are captured after the strobes arrive.
      pdbin_meta <= f_pdbin;
      pdbin_s    <= pdbin_meta;
      pwr_meta   <= f_pwr_n;
      pwr_s      <= pwr_meta;
      smemr_meta <= f_smemr;
      smemr_s    <= smemr_meta;
      sout_meta  <= f_sout;
      sout_s     <= sout_meta;
      reset_meta <= f_reset_n;
      reset_s    <= reset_meta;
      poc_meta   <= f_poc_n;
      poc_s      <= poc_meta;
      a_q        <= f_a(15 downto 0);

      -- A low write strobe persists through the complete write interval.
      -- write_seen changes that interval into exactly one RAM write.
      if write_request = '0' then
        write_seen <= '0';
      elsif write_seen = '0' then
        ram(to_integer(unsigned(a_q))) <= f_d;
        write_seen <= '1';
      end if;

      if reset_active = '1' then
        read_state <= READ_IDLE;
      else
        case read_state is
          when READ_IDLE =>
            if read_request = '1' then
              -- Synchronous-read form lets synthesis infer FPGA block RAM.
              d_q <= ram(to_integer(unsigned(a_q)));
              read_state <= READ_BREAK;
            end if;

          when READ_BREAK =>
            -- DO receiver is off in this state, before the DI driver turns on.
            if read_request = '1' then
              read_state <= READ_DRIVE;
            else
              read_state <= READ_IDLE;
            end if;

          when READ_DRIVE =>
            if read_request = '0' then
              read_state <= READ_IDLE;
            end if;
        end case;
      end if;

      led_counter <= led_counter + 1;
    end if;
  end process;

  led <= led_counter(led_counter'high);
end architecture rtl;
