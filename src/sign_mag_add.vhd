-- Sign-magnitude adder
-- Based on P. P. Chu, "FPGA Prototyping by VHDL Examples", section 3.7.2.
-- A number is represented in sign-magnitude form: the MSB is the sign
-- (0 = positive, 1 = negative) and the remaining bits are the magnitude.
-- This version also exposes an overflow flag (carry-out of the magnitude
-- addition) so it can be shown on a board LED.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add is
   generic (
      N : integer := 9  -- total width: 1 sign bit + (N-1) magnitude bits
   );
   port (
      a, b : in  std_logic_vector(N-1 downto 0);
      sum  : out std_logic_vector(N-1 downto 0);
      ovf  : out std_logic
   );
end sign_mag_add;

architecture arch of sign_mag_add is
   constant M    : integer := N - 1;                     -- magnitude width
   constant ZERO : unsigned(M-1 downto 0) := (others => '0');
   signal sign_a, sign_b, sign_r : std_logic;
   signal mag_a, mag_b, mag_r    : unsigned(M-1 downto 0);
   signal mag_sum_ext            : unsigned(M downto 0); -- extra MSB = carry
   signal carry                  : std_logic;
begin
   -- split operands into sign and magnitude
   sign_a <= a(N-1);
   sign_b <= b(N-1);
   mag_a  <= unsigned(a(M-1 downto 0));
   mag_b  <= unsigned(b(M-1 downto 0));

   -- extended magnitude sum (its MSB is the carry-out); only meaningful
   -- when both signs are equal
   mag_sum_ext <= ('0' & mag_a) + ('0' & mag_b);

   -- core sign-magnitude datapath
   process (sign_a, sign_b, mag_a, mag_b, mag_sum_ext)
   begin
      carry <= '0';
      if sign_a = sign_b then
         -- same sign: add magnitudes and keep the common sign
         mag_r  <= mag_sum_ext(M-1 downto 0);
         carry  <= mag_sum_ext(M);
         sign_r <= sign_a;
      else
         -- different signs: subtract the smaller magnitude from the larger
         -- one and keep the sign of the larger magnitude
         if mag_a >= mag_b then
            mag_r  <= mag_a - mag_b;
            sign_r <= sign_a;
         else
            mag_r  <= mag_b - mag_a;
            sign_r <= sign_b;
         end if;
      end if;
   end process;

   -- normalize the sign of a zero result to '+' (avoid the "-0" case)
   sum <= ('0' & std_logic_vector(mag_r)) when mag_r = ZERO
          else (sign_r & std_logic_vector(mag_r));
   ovf <= carry;
end arch;
