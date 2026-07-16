-- Testbench para o somador sign-magnitude ORIGINAL do livro
-- (P. P. Chu, "FPGA Prototyping by VHDL Examples", Listing 3.14),
-- tal como fornecido na pasta Projeto-VHDL, sem qualquer modificacao.
--
-- Objetivo: obter as formas de onda do codigo dos autores no GHDL/GTKWave,
-- conforme exigido pelo enunciado, e servir de base para a analise
-- comparativa contra a versao adaptada para a DE10-Lite (src/).
--
-- O somador original usa N=4: 1 bit de sinal + 3 bits de magnitude (0..7).
-- Os casos 5 e 6 documentam as duas limitacoes do codigo original:
--   * caso 5: resultado zero recebe sinal negativo ("-0");
--   * caso 6: a soma das magnitudes estoura 3 bits e trunca silenciosamente.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add_orig_tb is
end sign_mag_add_orig_tb;

architecture sim of sign_mag_add_orig_tb is
   constant N  : integer := 4;
   signal a, b : std_logic_vector(N-1 downto 0);
   signal sum  : std_logic_vector(N-1 downto 0);

   -- monta um operando sign-magnitude a partir do sinal e da magnitude
   function smag(sign : std_logic; mag : integer) return std_logic_vector is
   begin
      return sign & std_logic_vector(to_unsigned(mag, N-1));
   end function;

   -- confere o resultado contra o que o codigo do livro realmente produz
   procedure check(constant name  : in string;
                   signal   s     : in std_logic_vector(N-1 downto 0);
                   constant esign : in std_logic;
                   constant emag  : in integer) is
   begin
      assert s = (esign & std_logic_vector(to_unsigned(emag, N-1)))
         report "FAIL: " & name severity error;
   end procedure;
begin
   uut: entity work.sign_mag_add
      generic map (N => N)
      port map (a => a, b => b, sum => sum);

   stim: process
   begin
      -- ---- casos em que o codigo original acerta ----------------------
      -- (+3) + (+2) = +5   (mesmo sinal: soma as magnitudes)
      a <= smag('0', 3); b <= smag('0', 2); wait for 20 ns;
      check("+3 + +2 = +5", sum, '0', 5);

      -- (+5) + (-3) = +2   (sinais diferentes: subtrai, mantem sinal do maior)
      a <= smag('0', 5); b <= smag('1', 3); wait for 20 ns;
      check("+5 + -3 = +2", sum, '0', 2);

      -- (-5) + (+3) = -2
      a <= smag('1', 5); b <= smag('0', 3); wait for 20 ns;
      check("-5 + +3 = -2", sum, '1', 2);

      -- (-3) + (-2) = -5
      a <= smag('1', 3); b <= smag('1', 2); wait for 20 ns;
      check("-3 + -2 = -5", sum, '1', 5);

      -- ---- limitacoes do codigo original -----------------------------
      -- (+5) + (-5) deveria ser +0, mas o livro produz "-0" ("1000"):
      -- como mag_a > mag_b e falso, o sort escolhe sign_sum = sign_b = '1'.
      a <= smag('0', 5); b <= smag('1', 5); wait for 20 ns;
      check("+5 + -5 = -0 (limitacao: sinal negativo em zero)", sum, '1', 0);
      report "Caso 5: (+5)+(-5) resultou em -0 (sinal = '1'), " &
             "confirmando a ausencia de normalizacao do zero." severity note;

      -- (+7) + (+7) deveria ser +14, mas a magnitude tem so 3 bits:
      -- 14 mod 8 = 6, e o codigo original nao sinaliza o estouro.
      a <= smag('0', 7); b <= smag('0', 7); wait for 20 ns;
      check("+7 + +7 = +6 (limitacao: estouro truncado sem aviso)", sum, '0', 6);
      report "Caso 6: (+7)+(+7) resultou em +6 (14 truncado em 3 bits), " &
             "confirmando a ausencia de flag de overflow." severity note;

      report "Testbench do somador ORIGINAL (Listing 3.14) finalizado." severity note;
      wait;
   end process;
end sim;
