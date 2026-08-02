library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add is
   generic (
      N : integer := 9  
   );
   port (
      a, b : in  std_logic_vector(N-1 downto 0);
      sum  : out std_logic_vector(N-1 downto 0);
      ovf  : out std_logic
   );
end sign_mag_add;

architecture arch of sign_mag_add is
   constant M    : integer := N - 1;                    
   constant ZERO : unsigned(M-1 downto 0) := (others => '0');
   signal sign_a, sign_b, sign_r : std_logic;
   signal mag_a, mag_b, mag_r    : unsigned(M-1 downto 0);
   signal mag_sum_ext            : unsigned(M downto 0); 
   signal carry                  : std_logic;
begin
   sign_a <= a(N-1);
   sign_b <= b(N-1);
   mag_a  <= unsigned(a(M-1 downto 0));
   mag_b  <= unsigned(b(M-1 downto 0));

   mag_sum_ext <= ('0' & mag_a) + ('0' & mag_b);

   process (sign_a, sign_b, mag_a, mag_b, mag_sum_ext)
   begin
      carry <= '0';
      if sign_a = sign_b then
         mag_r  <= mag_sum_ext(M-1 downto 0);
         carry  <= mag_sum_ext(M);
         sign_r <= sign_a;
      else
         if mag_a >= mag_b then
            mag_r  <= mag_a - mag_b;
            sign_r <= sign_a;
         else
            mag_r  <= mag_b - mag_a;
            sign_r <= sign_b;
         end if;
      end if;
   end process;

   sum <= ('0' & std_logic_vector(mag_r)) when mag_r = ZERO
          else (sign_r & std_logic_vector(mag_r));
   ovf <= carry;
end arch;
