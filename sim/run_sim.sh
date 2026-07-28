#!/usr/bin/env bash
# =============================================================================
# Roda todas as simulacoes do projeto no GHDL e gera as formas de onda (.vcd)
# para inspecao no GTKWave.
#
#   Uso:  ./sim/run_sim.sh          (a partir da raiz do projeto)
#         ./sim/run_sim.sh --wave   (abre cada onda no GTKWave ao final)
#
# Requisitos: ghdl no PATH (testado com GHDL 6.0.0 mcode) e, opcionalmente,
# gtkwave para visualizar as ondas.
#
# Cada simulacao usa uma biblioteca de trabalho separada em build/ porque o
# somador original (Projeto-VHDL/) e o adaptado (src/) declaram a MESMA entidade
# "sign_mag_add"; compilar os dois na mesma biblioteca faria um sobrescrever o
# outro.
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."          # raiz do projeto
STD="--std=08"
OUT="build"
WAVE=${1:-}

if ! command -v ghdl >/dev/null 2>&1; then
   echo "ERRO: ghdl nao encontrado no PATH." >&2
   echo "Instale o GHDL (https://github.com/ghdl/ghdl/releases) e tente de novo." >&2
   exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"/{orig,core,top,sseg}

run_tb () {                      # run_tb <dir> <entidade> <tempo> <arquivos...>
   local dir=$1 tb=$2 stop=$3; shift 3
   echo
   echo "============================================================"
   echo ">> $tb"
   echo "============================================================"
   ghdl -a $STD --workdir="$OUT/$dir" "$@"
   ghdl -e $STD --workdir="$OUT/$dir" "$tb"
   # O aviso "metavalue detected" ocorre no instante 0, antes de os estimulos
   # chegarem as entradas, e nao indica falha -- por isso e filtrado.
   ghdl -r $STD --workdir="$OUT/$dir" "$tb" \
        --vcd="$OUT/$dir/$tb.vcd" --stop-time="$stop" 2>&1 \
      | grep -v "metavalue detected" || true
   echo "   onda: $OUT/$dir/$tb.vcd"
}

# 1) Codigo ORIGINAL do livro (Listing 3.14), exatamente como fornecido.
run_tb orig sign_mag_add_orig_tb 200ns \
   Projeto-VHDL/sign_mag_add.vhd sim/sign_mag_add_orig_tb.vhd

# 2) Nucleo ADAPTADO (N=9, com overflow e normalizacao do zero).
run_tb core sign_mag_add_tb 200ns \
   src/sign_mag_add.vhd src/sign_mag_add_tb.vhd

# 3) Decodificador 7 segmentos contra o mapeamento de pinos da DE10-Lite.
run_tb sseg hex_to_sseg_tb 300ns \
   src/hex_to_sseg.vhd sim/hex_to_sseg_tb.vhd

# 4) TOP-LEVEL completo da DE10-Lite (SW simultaneos N=4, sinais no HEX, Er).
run_tb top sign_mag_add_top_tb 5us \
   src/hex_to_sseg.vhd src/sign_mag_add.vhd src/sign_mag_add_top.vhd \
   sim/sign_mag_add_top_tb.vhd

# 5) Checagem de sintetizabilidade do top-level (Quartus faz o equivalente).
echo
echo "============================================================"
echo ">> Checagem de sintese (ghdl --synth)"
echo "============================================================"
ghdl --synth $STD --workdir="$OUT/top" \
   src/hex_to_sseg.vhd src/sign_mag_add.vhd src/sign_mag_add_top.vhd \
   -e sign_mag_add_top > "$OUT/top/netlist.vhd"
echo "   OK: top-level sintetizavel -> $OUT/top/netlist.vhd"

echo
echo "############################################################"
echo "Todas as simulacoes terminaram."
echo "Nenhuma linha '(assertion error)' acima significa 100% dos testes OK."
echo "############################################################"

if [ "$WAVE" = "--wave" ]; then
   if command -v gtkwave >/dev/null 2>&1; then
      for f in "$OUT"/*/*.vcd; do gtkwave "$f" & done
   else
      echo "AVISO: gtkwave nao encontrado no PATH; ondas geradas em $OUT/." >&2
   fi
fi
