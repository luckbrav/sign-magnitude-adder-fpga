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
   constant N : integer := 4; 

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
   op_a <= SW(3 downto 0);
   op_b <= SW(7 downto 4);

   add_unit: entity work.sign_mag_add
      generic map (N => N)
      port map (a => op_a, b => op_b, sum => result, ovf => ovf);

   mag_a_nib <= '0' & op_a(2 downto 0);
   mag_b_nib <= '0' & op_b(2 downto 0);
   mag_r_nib <= '0' & result(2 downto 0);

   h_a: entity work.hex_to_sseg
      port map (hex => mag_a_nib, dp => '1', sseg => mag_a_sseg);
   h_b: entity work.hex_to_sseg
      port map (hex => mag_b_nib, dp => '1', sseg => mag_b_sseg);
   h_r: entity work.hex_to_sseg
      port map (hex => mag_r_nib, dp => '1', sseg => mag_r_sseg);

   HEX5 <= SSEG_MINUS when op_a(3) = '1' else SSEG_BLANK;
   HEX4 <= mag_a_sseg;

   HEX3 <= SSEG_MINUS when op_b(3) = '1' else SSEG_BLANK;
   HEX2 <= mag_b_sseg;

   HEX1 <= SSEG_E when ovf = '1' else
           SSEG_MINUS when result(3) = '1' else
           SSEG_BLANK;
   HEX0 <= SSEG_R when ovf = '1' else mag_r_sseg;

   LEDR(0)          <= op_a(3);
   LEDR(1)          <= op_b(3);
   LEDR(2)          <= result(3) and not ovf; 
   LEDR(8 downto 3) <= (others => '0');
   LEDR(9)          <= ovf;
end arch;
