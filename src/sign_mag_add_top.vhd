-- Top-level wrapper of the sign-magnitude adder for the Intel/TerAsic
-- DE10-Lite board.
--
-- Follows the lab constraints (and the book testing circuit idea):
--   * N = 4  → 1 sign bit + 3 magnitude bits (range −7 … +7)
--   * 3 HEX digits show magnitudes; the other 3 show the minus sign
--   * Result is on the rightmost pair of displays
--   * Decimal point is kept off on every digit
--   * A and B are entered simultaneously (no SW9 selector)
--
-- Inputs
--   SW(3 downto 0) : operand A   (SW3 = sign, SW2..0 = magnitude)
--   SW(7 downto 4) : operand B   (SW7 = sign, SW6..4 = magnitude)
--   SW(9 downto 8) : unused
--   KEY(1 downto 0): unused (kept for pin compatibility)
--
-- Outputs (HEX5 is leftmost, HEX0 is rightmost on the board)
--   HEX5 / HEX4    : sign of A  / magnitude of A
--   HEX3 / HEX2    : sign of B  / magnitude of B
--   HEX1 / HEX0    : sign of sum / magnitude of sum
--                    (or "Er" when |sum| > 7, i.e. magnitude overflow)
--   LEDR(0)        : sign of A       (1 = negative)
--   LEDR(1)        : sign of B       (1 = negative)
--   LEDR(2)        : sign of result  (1 = negative)
--   LEDR(9)        : overflow (|sum| > 7)
library ieee;
use ieee.std_logic_1164.all;

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
   constant N : integer := 4;  -- 1 sign bit + 3 magnitude bits

   -- DE10-Lite segments are active-low; bit 7 is the decimal point.
   -- Blank = all off; minus = only segment g lit; E/r used for overflow.
   constant SSEG_BLANK : std_logic_vector(7 downto 0) := "11111111";
   constant SSEG_MINUS : std_logic_vector(7 downto 0) := "10111111"; -- g on
   constant SSEG_E     : std_logic_vector(7 downto 0) := "10000110"; -- "E"
   constant SSEG_R     : std_logic_vector(7 downto 0) := "10101111"; -- "r" (e+g)

   signal op_a, op_b, result : std_logic_vector(N-1 downto 0);
   signal ovf                : std_logic;
   signal mag_a_nib          : std_logic_vector(3 downto 0);
   signal mag_b_nib          : std_logic_vector(3 downto 0);
   signal mag_r_nib          : std_logic_vector(3 downto 0);
   signal mag_a_sseg         : std_logic_vector(7 downto 0);
   signal mag_b_sseg         : std_logic_vector(7 downto 0);
   signal mag_r_sseg         : std_logic_vector(7 downto 0);
begin
   -- Simultaneous inputs (same mapping as Listing 3.15 of the book).
   -- MAX10_CLK1_50 and KEY are unused: the design is purely combinational,
   -- but the ports remain so the DE10-Lite pin assignments stay valid.
   op_a <= SW(3 downto 0);
   op_b <= SW(7 downto 4);

   add_unit: entity work.sign_mag_add
      generic map (N => N)
      port map (a => op_a, b => op_b, sum => result, ovf => ovf);

   -- Magnitudes: zero-extend the 3-bit field to a nibble for hex_to_sseg.
   -- These go through signals because VHDL-93 (the Quartus default) only
   -- accepts a static signal name or a globally static expression as the
   -- actual of a port; an inline concatenation would need VHDL-2008.
   mag_a_nib <= '0' & op_a(2 downto 0);
   mag_b_nib <= '0' & op_b(2 downto 0);
   mag_r_nib <= '0' & result(2 downto 0);

   -- dp = '1' keeps the decimal point OFF (active-low on the DE10-Lite).
   h_a: entity work.hex_to_sseg
      port map (hex => mag_a_nib, dp => '1', sseg => mag_a_sseg);
   h_b: entity work.hex_to_sseg
      port map (hex => mag_b_nib, dp => '1', sseg => mag_b_sseg);
   h_r: entity work.hex_to_sseg
      port map (hex => mag_r_nib, dp => '1', sseg => mag_r_sseg);

   -- Operand A on the left pair
   HEX5 <= SSEG_MINUS when op_a(3) = '1' else SSEG_BLANK;
   HEX4 <= mag_a_sseg;

   -- Operand B in the middle pair
   HEX3 <= SSEG_MINUS when op_b(3) = '1' else SSEG_BLANK;
   HEX2 <= mag_b_sseg;

   -- Result on the right pair; show "Er" when |sum| does not fit in 3 bits
   HEX1 <= SSEG_E when ovf = '1' else
           SSEG_MINUS when result(3) = '1' else
           SSEG_BLANK;
   HEX0 <= SSEG_R when ovf = '1' else mag_r_sseg;

   -- LED feedback: signs and overflow
   LEDR(0)          <= op_a(3);
   LEDR(1)          <= op_b(3);
   LEDR(2)          <= result(3) and not ovf;  -- meaningful only when no error
   LEDR(8 downto 3) <= (others => '0');
   LEDR(9)          <= ovf;
end arch;
