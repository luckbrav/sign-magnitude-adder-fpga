-- Top-level wrapper of the sign-magnitude adder for the Intel/TerAsic
-- DE10-Lite board.
--
-- Inputs
--   SW(8 downto 0) : operand to be loaded   (SW8 = sign, SW7..0 = magnitude)
--   SW(9)          : operand selector       (0 = load A, 1 = load B)
--   KEY(0)         : load pulse (push and release to store SW into A or B)
--   KEY(1)         : asynchronous reset      (press to clear A and B)
--
-- Outputs
--   HEX1..HEX0     : magnitude of operand A  (two hex digits)
--   HEX3..HEX2     : magnitude of operand B  (two hex digits)
--   HEX5..HEX4     : magnitude of the result (two hex digits)
--   LEDR(0)        : sign of A       (1 = negative)
--   LEDR(1)        : sign of B       (1 = negative)
--   LEDR(2)        : sign of result  (1 = negative)
--   LEDR(9)        : overflow (carry-out of the magnitude addition)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add_top is
   port (
      MAX10_CLK1_50 : in  std_logic;
      SW            : in  std_logic_vector(9 downto 0);
      KEY           : in  std_logic_vector(1 downto 0);
      LEDR          : out std_logic_vector(9 downto 0);
      HEX0          : out std_logic_vector(7 downto 0);
      HEX1          : out std_logic_vector(7 downto 0);
      HEX2          : out std_logic_vector(7 downto 0);
      HEX3          : out std_logic_vector(7 downto 0);
      HEX4          : out std_logic_vector(7 downto 0);
      HEX5          : out std_logic_vector(7 downto 0)
   );
end sign_mag_add_top;

architecture arch of sign_mag_add_top is
   constant N : integer := 9;  -- 1 sign bit + 8 magnitude bits
   signal clk, rst             : std_logic;
   signal reg_a, reg_b, result : std_logic_vector(N-1 downto 0);
   signal ovf                  : std_logic;
   signal key0_sync, key0_prev : std_logic;  -- KEY0 synchronizer / edge detect
begin
   clk <= MAX10_CLK1_50;
   rst <= not KEY(1);          -- KEY1 is active-low: pressed ('0') => reset

   -- Register the operands. The switches are stored into A or B on the
   -- release (rising) edge of KEY0, selected by SW9.
   process (clk, rst)
   begin
      if rst = '1' then
         reg_a     <= (others => '0');
         reg_b     <= (others => '0');
         key0_prev <= '1';
         key0_sync <= '1';
      elsif rising_edge(clk) then
         key0_sync <= KEY(0);
         key0_prev <= key0_sync;
         if (key0_prev = '0' and key0_sync = '1') then
            if SW(9) = '0' then
               reg_a <= SW(8 downto 0);
            else
               reg_b <= SW(8 downto 0);
            end if;
         end if;
      end if;
   end process;

   -- sign-magnitude adder core
   add_unit: entity work.sign_mag_add
      generic map (N => N)
      port map (a => reg_a, b => reg_b, sum => result, ovf => ovf);

   -- operand A magnitude on HEX1:HEX0
   h0: entity work.hex_to_sseg
      port map (hex => reg_a(3 downto 0), dp => '0', sseg => HEX0);
   h1: entity work.hex_to_sseg
      port map (hex => reg_a(7 downto 4), dp => '0', sseg => HEX1);
   -- operand B magnitude on HEX3:HEX2
   h2: entity work.hex_to_sseg
      port map (hex => reg_b(3 downto 0), dp => '0', sseg => HEX2);
   h3: entity work.hex_to_sseg
      port map (hex => reg_b(7 downto 4), dp => '0', sseg => HEX3);
   -- result magnitude on HEX5:HEX4
   h4: entity work.hex_to_sseg
      port map (hex => result(3 downto 0), dp => '0', sseg => HEX4);
   h5: entity work.hex_to_sseg
      port map (hex => result(7 downto 4), dp => '0', sseg => HEX5);

   -- LED feedback: signs and overflow
   LEDR(0)          <= reg_a(8);   -- sign of A
   LEDR(1)          <= reg_b(8);   -- sign of B
   LEDR(2)          <= result(8);  -- sign of result
   LEDR(8 downto 3) <= (others => '0');
   LEDR(9)          <= ovf;        -- magnitude overflow (carry-out)
end arch;
