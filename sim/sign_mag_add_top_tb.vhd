-- Testbench do top-level adaptado para a DE10-Lite (src/sign_mag_add_top.vhd).
--
-- Verifica o circuito completo, de ponta a ponta, exatamente como ele sera
-- usado na placa: carga dos operandos pelas chaves SW com o pulso do KEY0,
-- reset pelo KEY1 e leitura do resultado nos displays HEX e nos LEDs LEDR.
--
-- Os displays sao conferidos decodificando o padrao de 7 segmentos de volta
-- para o valor hexadecimal, de modo que o teste valida a cadeia inteira
-- (registradores -> somador -> decodificador -> pinos de saida).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_mag_add_top_tb is
end sign_mag_add_top_tb;

architecture sim of sign_mag_add_top_tb is
   constant CLK_PERIOD : time := 20 ns;   -- 50 MHz, igual ao MAX10_CLK1_50

   signal clk  : std_logic := '0';
   signal SW   : std_logic_vector(9 downto 0) := (others => '0');
   signal KEY  : std_logic_vector(1 downto 0) := "11";  -- botoes ativos em nivel baixo
   signal LEDR : std_logic_vector(9 downto 0);
   signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(7 downto 0);

   signal running : boolean := true;

   -- Decodifica o padrao de 7 segmentos da DE10-Lite de volta para o nibble.
   -- E a operacao inversa de hex_to_sseg e so aceita os 16 padroes validos.
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
      return -1;  -- padrao nao reconhecido
   end function;

   -- Le os dois displays de um par como um byte (ex.: HEX1 HEX0 -> |A|).
   function pair_value(hi, lo : std_logic_vector(7 downto 0)) return integer is
   begin
      return sseg_to_hex(hi) * 16 + sseg_to_hex(lo);
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
      -- Carrega um operando pelas chaves, imitando o usuario: posiciona SW,
      -- aperta KEY0 ('0'), solta ('1') -- a carga ocorre na borda de subida.
      procedure load(constant sel : in std_logic;   -- '0' = operando A, '1' = B
                     constant sign : in std_logic;
                     constant mag  : in integer) is
      begin
         SW(9) <= sel;
         SW(8) <= sign;
         SW(7 downto 0) <= std_logic_vector(to_unsigned(mag, 8));
         wait for CLK_PERIOD*2;
         KEY(0) <= '0';                 -- botao pressionado
         wait for CLK_PERIOD*4;
         KEY(0) <= '1';                 -- botao solto -> pulso de carga
         wait for CLK_PERIOD*4;
      end procedure;

      -- Confere o resultado lido nos displays/LEDs da placa.
      procedure check_result(constant name  : in string;
                             constant emag  : in integer;
                             constant esign : in std_logic;
                             constant eovf  : in std_logic) is
      begin
         assert pair_value(HEX5, HEX4) = emag
            report "FAIL " & name & ": magnitude no display HEX5:HEX4 = " &
                   integer'image(pair_value(HEX5, HEX4)) &
                   ", esperado " & integer'image(emag)
            severity error;
         assert LEDR(2) = esign
            report "FAIL " & name & ": sinal em LEDR2 incorreto" severity error;
         assert LEDR(9) = eovf
            report "FAIL " & name & ": overflow em LEDR9 incorreto" severity error;
      end procedure;
   begin
      -- ---- reset pelo KEY1: os dois operandos devem zerar ----------------
      KEY(1) <= '0';                    -- pressiona reset
      wait for CLK_PERIOD*4;
      KEY(1) <= '1';                    -- solta
      wait for CLK_PERIOD*4;
      assert pair_value(HEX1, HEX0) = 0 and pair_value(HEX3, HEX2) = 0
         report "FAIL reset: displays dos operandos deveriam mostrar 00"
         severity error;
      report "Reset (KEY1): operandos zerados, displays em 00." severity note;

      -- ---- (+5) + (-3) = +2  (exemplo do README) ------------------------
      load('0', '0', 5);                -- A = +5
      assert pair_value(HEX1, HEX0) = 5 and LEDR(0) = '0'
         report "FAIL: operando A nao apareceu em HEX1:HEX0/LEDR0" severity error;
      load('1', '1', 3);                -- B = -3
      assert pair_value(HEX3, HEX2) = 3 and LEDR(1) = '1'
         report "FAIL: operando B nao apareceu em HEX3:HEX2/LEDR1" severity error;
      check_result("(+5)+(-3)", 2, '0', '0');
      report "(+5) + (-3) = +2  -> HEX5:HEX4=02, LEDR2=0 (positivo)." severity note;

      -- ---- (+200) + (+100): estoura 8 bits -> 44 com LEDR9 aceso --------
      load('0', '0', 200);              -- A = +200 (0xC8)
      load('1', '0', 100);              -- B = +100 (0x64)
      check_result("(+200)+(+100)", 44, '0', '1');
      report "(+200) + (+100) -> HEX5:HEX4=2C (44), LEDR9=1 (overflow)." severity note;

      -- ---- (-7) + (+7) = +0: sinal normalizado, LEDR2 apagado -----------
      load('0', '1', 7);                -- A = -7
      load('1', '0', 7);                -- B = +7
      check_result("(-7)+(+7)", 0, '0', '0');
      report "(-7) + (+7) = +0  -> LEDR2=0: zero normalizado como positivo." severity note;

      -- ---- SW9 seleciona o destino: A nao muda ao carregar B ------------
      load('0', '0', 9);                -- A = +9
      load('1', '0', 4);                -- B = +4
      assert pair_value(HEX1, HEX0) = 9
         report "FAIL: carregar B alterou o operando A" severity error;
      check_result("(+9)+(+4)", 13, '0', '0');

      -- ---- KEY0 so carrega na borda: mexer nas chaves nao afeta ---------
      SW(7 downto 0) <= x"FF";          -- muda as chaves sem apertar o botao
      wait for CLK_PERIOD*4;
      assert pair_value(HEX3, HEX2) = 4
         report "FAIL: operando B mudou sem o pulso de KEY0" severity error;
      report "Chaves alteradas sem KEY0: operandos preservados." severity note;

      report "Testbench do TOP-LEVEL (DE10-Lite) finalizado." severity note;
      running <= false;
      wait;
   end process;
end sim;
