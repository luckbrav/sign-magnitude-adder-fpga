library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add_tb is
end sign_mag_add_tb;

architecture sim of sign_mag_add_tb is
   constant N   : integer := 9;
   signal a, b  : std_logic_vector(N-1 downto 0);
   signal sum   : std_logic_vector(N-1 downto 0);
   signal ovf   : std_logic;

   function smag(sign : std_logic; mag : integer) return std_logic_vector is
   begin
      return sign & std_logic_vector(to_unsigned(mag, N-1));
   end function;

   procedure check(constant name : in string;
                   signal   s    : in std_logic_vector(N-1 downto 0);
                   signal   o    : in std_logic;
                   constant esign: in std_logic;
                   constant emag : in integer;
                   constant eovf : in std_logic) is
   begin
      assert s = (esign & std_logic_vector(to_unsigned(emag, N-1)))
                 and o = eovf
         report "FAIL: " & name severity error;
   end procedure;
begin
   uut: entity work.sign_mag_add
      generic map (N => N)
      port map (a => a, b => b, sum => sum, ovf => ovf);

   stim: process
   begin
      -- (+5) + (+3) = +8
      a <= smag('0', 5); b <= smag('0', 3); wait for 20 ns;
      check("+5 + +3", sum, ovf, '0', 8, '0');

      -- (+5) + (-3) = +2
      a <= smag('0', 5); b <= smag('1', 3); wait for 20 ns;
      check("+5 + -3", sum, ovf, '0', 2, '0');

      -- (-5) + (+3) = -2
      a <= smag('1', 5); b <= smag('0', 3); wait for 20 ns;
      check("-5 + +3", sum, ovf, '1', 2, '0');

      -- (-5) + (-3) = -8
      a <= smag('1', 5); b <= smag('1', 3); wait for 20 ns;
      check("-5 + -3", sum, ovf, '1', 8, '0');

      -- (+7) + (-7) = +0  (sign normalized to '+')
      a <= smag('0', 7); b <= smag('1', 7); wait for 20 ns;
      check("+7 + -7", sum, ovf, '0', 0, '0');

      -- (+200) + (+100) = 300 -> magnitude wraps to 44, overflow = 1
      a <= smag('0', 200); b <= smag('0', 100); wait for 20 ns;
      check("+200 + +100", sum, ovf, '0', 44, '1');

      -- (+255) + (+1) = 256 -> magnitude wraps to 0, overflow = 1
      a <= smag('0', 255); b <= smag('0', 1); wait for 20 ns;
      check("+255 + +1", sum, ovf, '0', 0, '1');

      report "Sign-magnitude adder testbench finished." severity note;
      wait;
   end process;
end sim;
