-- Testbench do top-level adaptado para a DE10-Lite (src/sign_mag_add_top.vhd).
--
-- Verifica o circuito completo com a interface do laboratorio:
--   * entrada simultanea A=SW(3..0), B=SW(7..4)  (N=4)
--   * 3 digitos de magnitude + 3 digitos de sinal
--   * resultado no par direito (HEX1/HEX0), com "Er" em overflow
--   * ponto decimal apagado em todos os digitos
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add_top_tb is
end sign_mag_add_top_tb;

architecture sim of sign_mag_add_top_tb is
   constant CLK_PERIOD : time := 20 ns;

   signal clk  : std_logic := '0';
   signal SW   : std_logic_vector(9 downto 0) := (others => '0');
   signal KEY  : std_logic_vector(1 downto 0) := "11";
   signal LEDR : std_logic_vector(9 downto 0);
   signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(7 downto 0);

   signal running : boolean := true;

   -- Padroes de 7 segmentos da DE10-Lite (ativos em nivel baixo, DP=bit7).
   constant SSEG_BLANK : std_logic_vector(7 downto 0) := "11111111";
   constant SSEG_MINUS : std_logic_vector(7 downto 0) := "10111111";
   constant SSEG_E     : std_logic_vector(7 downto 0) := "10000110";
   constant SSEG_R     : std_logic_vector(7 downto 0) := "10101111";

   -- Decodifica o padrao de 7 segmentos de volta para o nibble (0..15),
   -- ou -1 se o padrao nao for um digito hexadecimal reconhecido.
   function sseg_to_hex(s : std_logic_vector(7 downto 0)) return integer is
      constant TABLE : std_logic_vector(0 to 15*7+6) :=
         "1000000" & "1111001" & "0100100" & "0110000" &
         "0011001" & "0010010" & "0000010" & "1111000" &
         "0000000" & "0010000" & "0001000" & "0000011" &
         "1000110" & "0100001" & "0000110" & "0001110";
   begin
      for i in 0 to 15 loop
         if s(6 downto 0) = TABLE(i*7 to i*7+6) then
            return i;
         end if;
      end loop;
      return -1;
   end function;

   -- Monta um operando sign-magnitude de 4 bits.
   function smag(sign : std_logic; mag : integer) return std_logic_vector is
   begin
      return sign & std_logic_vector(to_unsigned(mag, 3));
   end function;
begin
   clk <= (not clk) after CLK_PERIOD/2 when running else '0';

   uut: entity work.sign_mag_add_top
      port map (
         MAX10_CLK1_50 => clk,
         SW => SW, KEY => KEY, LEDR => LEDR,
         HEX0 => HEX0, HEX1 => HEX1, HEX2 => HEX2,
         HEX3 => HEX3, HEX4 => HEX4, HEX5 => HEX5);

   stim: process
      -- Aplica A e B de uma vez (entrada simultanea) e espera estabilizar.
      procedure apply(constant a_sign : in std_logic;
                      constant a_mag  : in integer;
                      constant b_sign : in std_logic;
                      constant b_mag  : in integer) is
      begin
         SW(3 downto 0) <= smag(a_sign, a_mag);
         SW(7 downto 4) <= smag(b_sign, b_mag);
         SW(9 downto 8) <= "00";
         wait for CLK_PERIOD*2;
      end procedure;

      -- Confere magnitude + sinal de um par (sign_hex, mag_hex).
      procedure check_pair(constant name     : in string;
                           constant sign_hex : in std_logic_vector(7 downto 0);
                           constant mag_hex  : in std_logic_vector(7 downto 0);
                           constant esign    : in std_logic;
                           constant emag     : in integer) is
      begin
         if esign = '1' then
            assert sign_hex = SSEG_MINUS
               report "FAIL " & name & ": sinal negativo ausente no display"
               severity error;
         else
            assert sign_hex = SSEG_BLANK
               report "FAIL " & name & ": display de sinal deveria estar apagado"
               severity error;
         end if;
         assert sseg_to_hex(mag_hex) = emag
            report "FAIL " & name & ": magnitude = " &
                   integer'image(sseg_to_hex(mag_hex)) &
                   ", esperado " & integer'image(emag)
            severity error;
         -- Ponto decimal deve estar apagado (ativo-baixo => '1').
         assert mag_hex(7) = '1' and sign_hex(7) = '1'
            report "FAIL " & name & ": ponto decimal deveria estar apagado"
            severity error;
      end procedure;
   begin
      -- ---- zeros iniciais ------------------------------------------------
      apply('0', 0, '0', 0);
      check_pair("A=0",  HEX5, HEX4, '0', 0);
      check_pair("B=0",  HEX3, HEX2, '0', 0);
      check_pair("sum",  HEX1, HEX0, '0', 0);
      assert LEDR(9) = '0' report "FAIL: overflow indevido em 0+0" severity error;
      report "Zeros: displays em branco/0, sem overflow." severity note;

      -- ---- (+5) + (-3) = +2  (exemplo do livro / README) ----------------
      apply('0', 5, '1', 3);
      check_pair("A=+5", HEX5, HEX4, '0', 5);
      check_pair("B=-3", HEX3, HEX2, '1', 3);
      check_pair("sum=+2", HEX1, HEX0, '0', 2);
      assert LEDR(0) = '0' and LEDR(1) = '1' and LEDR(2) = '0' and LEDR(9) = '0'
         report "FAIL (+5)+(-3): LEDs de sinal/overflow incorretos"
         severity error;
      report "(+5) + (-3) = +2  -> HEX0=2, HEX1 em branco (positivo)." severity note;

      -- ---- (-5) + (+3) = -2 ---------------------------------------------
      apply('1', 5, '0', 3);
      check_pair("A=-5", HEX5, HEX4, '1', 5);
      check_pair("B=+3", HEX3, HEX2, '0', 3);
      check_pair("sum=-2", HEX1, HEX0, '1', 2);
      assert LEDR(2) = '1' and LEDR(9) = '0'
         report "FAIL (-5)+(+3): sinal/overflow incorretos" severity error;
      report "(-5) + (+3) = -2  -> HEX1=menos, HEX0=2." severity note;

      -- ---- (-4) + (-3) = -7 ---------------------------------------------
      apply('1', 4, '1', 3);
      check_pair("sum=-7", HEX1, HEX0, '1', 7);
      assert LEDR(9) = '0'
         report "FAIL (-4)+(-3): nao deveria haver overflow" severity error;
      report "(-4) + (-3) = -7  -> dentro do intervalo." severity note;

      -- ---- (+7) + (+1) = +8 -> overflow, display "Er" -------------------
      apply('0', 7, '0', 1);
      assert HEX1 = SSEG_E and HEX0 = SSEG_R
         report "FAIL (+7)+(+1): esperado 'Er' no par direito" severity error;
      assert LEDR(9) = '1'
         report "FAIL (+7)+(+1): LEDR9 deveria indicar overflow" severity error;
      report "(+7) + (+1) -> Er (acima de +7)." severity note;

      -- ---- (-7) + (-1) = -8 -> overflow, display "Er" -------------------
      apply('1', 7, '1', 1);
      assert HEX1 = SSEG_E and HEX0 = SSEG_R
         report "FAIL (-7)+(-1): esperado 'Er' no par direito" severity error;
      assert LEDR(9) = '1'
         report "FAIL (-7)+(-1): LEDR9 deveria indicar overflow" severity error;
      report "(-7) + (-1) -> Er (abaixo de -7)." severity note;

      -- ---- (-7) + (+7) = +0: zero normalizado sem sinal -----------------
      apply('1', 7, '0', 7);
      check_pair("sum=+0", HEX1, HEX0, '0', 0);
      assert LEDR(2) = '0' and LEDR(9) = '0'
         report "FAIL (-7)+(+7): zero deveria ser positivo, sem overflow"
         severity error;
      report "(-7) + (+7) = +0  -> sinal normalizado." severity note;

      -- ---- Entrada simultanea: mudar A e B juntos atualiza na hora ------
      apply('0', 2, '0', 3);            -- +2 + +3 = +5
      check_pair("sum=+5", HEX1, HEX0, '0', 5);
      SW(3 downto 0) <= smag('0', 6);   -- muda so A para +6 -> +6 + +3 = +9 -> Er
      wait for CLK_PERIOD*2;
      assert HEX1 = SSEG_E and HEX0 = SSEG_R
         report "FAIL: mudanca simultanea de A nao refletiu overflow"
         severity error;
      report "Entrada simultanea: A/B seguem as chaves sem KEY0/SW9." severity note;

      report "Testbench do TOP-LEVEL (DE10-Lite) finalizado." severity note;
      running <= false;
      wait;
   end process;
end sim;
