-- Testbench de verificacao do decodificador hexadecimal -> 7 segmentos
-- adaptado para a DE10-Lite (src/hex_to_sseg.vhd).
--
-- Motivacao: o decodificador do livro (Projeto-VHDL/hex_to_sseg.vhd, Listing
-- 3.12) foi escrito para a placa do Chu, onde o vetor sseg tem o segmento 'a'
-- no bit MAIS significativo: sseg(6)=a, sseg(5)=b, ..., sseg(0)=g.
--
-- Na DE10-Lite a ordem dos pinos e a INVERSA (ver de10_lite.qsf):
--   HEX0[0]=PIN_C14=a, HEX0[1]=b, HEX0[2]=c, HEX0[3]=d,
--   HEX0[4]=e,          HEX0[5]=f, HEX0[6]=g, HEX0[7]=ponto decimal
-- ou seja sseg(0)=a ... sseg(6)=g, todos ativos em nivel BAIXO.
--
-- Este testbench monta a tabela-verdade dos 16 digitos a partir dos segmentos
-- que devem acender e confere, bit a bit, contra o decodificador adaptado.
-- Serve como prova de que a inversao de bits em src/hex_to_sseg.vhd e
-- necessaria e esta correta para esta placa.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_to_sseg_tb is
end hex_to_sseg_tb;

architecture sim of hex_to_sseg_tb is
   signal hex  : std_logic_vector(3 downto 0);
   signal sseg : std_logic_vector(7 downto 0);

   -- Segmentos que devem ACENDER em cada digito, na ordem "abcdefg"
   -- ('1' = aceso). Tabela-verdade classica de display de 7 segmentos.
   type pattern_array is array (0 to 15) of std_logic_vector(1 to 7);
   constant ON_SEGMENTS : pattern_array := (
      0  => "1111110",  -- 0: a b c d e f
      1  => "0110000",  -- 1: b c
      2  => "1101101",  -- 2: a b d e g
      3  => "1111001",  -- 3: a b c d g
      4  => "0110011",  -- 4: b c f g
      5  => "1011011",  -- 5: a c d f g
      6  => "1011111",  -- 6: a c d e f g
      7  => "1110000",  -- 7: a b c
      8  => "1111111",  -- 8: todos
      9  => "1111011",  -- 9: a b c d f g
      10 => "1110111",  -- A: a b c e f g
      11 => "0011111",  -- b: c d e f g
      12 => "1001110",  -- C: a d e f
      13 => "0111101",  -- d: b c d e g
      14 => "1001111",  -- E: a d e f g
      15 => "1000111"   -- F: a e f g
   );
   constant DIGIT_NAME : string(1 to 16) := "0123456789AbCdEF";
begin
   uut: entity work.hex_to_sseg
      port map (hex => hex, dp => '0', sseg => sseg);

   stim: process
      variable expected : std_logic_vector(6 downto 0);
      variable ok       : integer := 0;
   begin
      for i in 0 to 15 loop
         hex <= std_logic_vector(to_unsigned(i, 4));
         wait for 10 ns;

         -- Monta o vetor esperado na ordem da DE10-Lite: bit 0 = 'a' ... bit 6 = 'g',
         -- invertendo a logica porque os segmentos sao ativos em nivel baixo.
         for seg in 1 to 7 loop            -- seg 1='a', 2='b', ... 7='g'
            expected(seg-1) := not ON_SEGMENTS(i)(seg);
         end loop;

         if sseg(6 downto 0) = expected then
            ok := ok + 1;
         else
            report "FAIL: digito " & DIGIT_NAME(i+1) &
                   " esperado=" & to_string(expected) &
                   " obtido="   & to_string(sseg(6 downto 0))
               severity error;
         end if;
      end loop;

      -- o bit 7 do vetor e o ponto decimal, ligado direto na entrada dp
      assert sseg(7) = '0'
         report "FAIL: ponto decimal deveria seguir a entrada dp" severity error;

      report "Decodificador 7-seg: " & integer'image(ok) &
             "/16 digitos conferem com o mapeamento da DE10-Lite."
         severity note;
      wait;
   end process;
end sim;
