# Sign-Magnitude Adder on FPGA Board

## 👥​ Team:
* Lucas Gois Carneiro Batista

## 🌐​ Overview:
This project is based on coding an Intel FPGA board with the aim of correctly and safely implementing a simplified **sign-magnitude adder**, following the example presented in section 3.7.2 of *FPGA Prototyping by VHDL Examples* (Pong P. Chu, 2008). The circuit adds two numbers represented in sign-magnitude notation, deciding — from the signs of the operands — whether it must add or subtract the magnitudes, and it is adapted to run on the Intel/Altera/TerAsic DE10-Lite board using the switches and pushbuttons as inputs and the LEDs and seven-segment displays as outputs.

## 🤔​ What Is An FPGA Board:
An FPGA (Field-Programmable Gate Array) is essentially a "blank" integrated circuit that can be completely reconfigured by the developer after it has been manufactured.

Unlike a common processor in your computer or cell phone, which comes with pre-defined and immutable circuit factories, an FPGA allows you to create your own digital hardware from scratch.

![DE10-Lite Board](img/DE10-LITE.webp)

## 🔥​ Motivation:
The presented project is based on the development of VHDL code that implements a sign-magnitude adder on the Intel/Altera/TerAsic DE10-Lite board, using the board's switches (SW) and pushbuttons (KEY) as inputs and the LEDs (LEDR) and six seven-segment displays (HEX) as outputs. Regarding the importance of this project, it's worth noting that sign-magnitude is one of the classic ways of representing signed numbers in digital systems, and the adder that operates on it is a compact yet complete example of RT-level combinational design: it involves comparison, conditional addition/subtraction, sign selection and result normalization. Understanding how these blocks cooperate is a solid foundation for the more complex arithmetic units (such as two's-complement and floating-point adders) found in modern CPUs and GPUs.

## 🔢​ Number Structure:
Each operand is represented in **sign-magnitude** notation with the following elements:

* Sign (1 bit): `0` = positive (`+`), `1` = negative (`-`)
* Magnitude (8 bits): an unsigned value in the range `0x00`–`0xFF`

So a full operand is 9 bits wide (`sign & magnitude`). On the board the value is entered through the switches:

* `SW9` — operand selector (`0` = load into A, `1` = load into B)
* `SW8` — sign of the number being entered
* `SW7..SW0` — magnitude of the number being entered (two hex digits)

Example: the number `-0x2A` (decimal −42) is entered with `SW8 = 1` and `SW7..SW0 = 00101010`.

## 🔨​ How It Works:
The implementation is divided into three distinct stages: data reception, data processing, and data output on the seven-segment displays and LEDs.

* **Input / control — `sign_mag_add_top.vhd`**: reads the switches and stores each operand into an internal register on the release edge of `KEY0` (which operand is selected by `SW9`). `KEY1` resets both registers to zero. This module also drives the displays and LEDs.
* **Processing — `sign_mag_add.vhd`**: the core sign-magnitude adder. It compares the signs of the two operands and, based on that, either adds the magnitudes (same sign) or subtracts the smaller magnitude from the larger one (different signs), choosing the correct output sign and flagging overflow.
* **Output — `hex_to_sseg.vhd`**: a hexadecimal-to-seven-segment decoder that converts each 4-bit nibble into the pattern that lights up the corresponding LEDs of a display.

Therefore:

* Input: `sign_mag_add_top.vhd`
* Processing: `sign_mag_add.vhd`
* Output: `hex_to_sseg.vhd` (instantiated inside the top-level)

The magnitudes are shown on the displays and the signs are shown on the LEDs:

| Display / LED | Meaning |
|---------------|---------|
| `HEX1 HEX0`   | magnitude of operand A (`\|A\|`) |
| `HEX3 HEX2`   | magnitude of operand B (`\|B\|`) |
| `HEX5 HEX4`   | magnitude of the result (`\|A + B\|`) |
| `LEDR0`       | sign of A (on = negative) |
| `LEDR1`       | sign of B (on = negative) |
| `LEDR2`       | sign of the result (on = negative) |
| `LEDR9`       | overflow (carry-out of the magnitude addition) |

## 🔧​ Tools Used:
The development of this project focused on two tools: GHDL (with GTKWave) and Quartus Prime. Both are geared towards the analysis, compilation, and simulation of digital circuit designs. GHDL offers a very simple way to simulate testbenches and, being free software, allows its use by a larger number of people; the resulting waveforms are inspected in GTKWave. Quartus Prime is Intel's software (with a free *Lite* edition) and is a more complete tool, used here for the **logic synthesis** of the circuit and for programming the DE10-Lite board. In this project, GHDL + GTKWave was used to functionally validate the arithmetic behavior of the adder, and Quartus Prime Lite was used for logic synthesis and to run the design on real hardware.

## ​🎯​ Fundamental Operations:
1. **Split**: each operand is split into its sign bit and its magnitude field.
2. **Compare signs**: the signs of the two operands are compared to decide the operation.
3. **Add / Subtract**:
   * If the signs are **equal**, the magnitudes are added and the common sign is kept.
   * If the signs are **different**, the smaller magnitude is subtracted from the larger one, and the sign of the larger magnitude is kept.
4. **Normalization**: a zero result always receives the `+` sign (there is no "−0"). When the magnitudes are added and the sum does not fit in 8 bits, an **overflow** flag is raised (`LEDR9`).

## ​🧩​ Example:
* A: Sign = `0` (+), Magnitude = `05` (HEX) = `5` (DEC) → **+5**
* B: Sign = `1` (−), Magnitude = `03` (HEX) = `3` (DEC) → **−3**

Since the signs are different, the adder subtracts the magnitudes (`5 − 3 = 2`) and keeps the sign of the larger magnitude (A, positive):

`(+5) + (−3) = +2` → result magnitude `02` on `HEX5 HEX4`, with `LEDR2` off (positive).

A second example showing overflow:

* A: Sign = `0` (+), Magnitude = `C8` (HEX) = `200` (DEC) → **+200**
* B: Sign = `0` (+), Magnitude = `64` (HEX) = `100` (DEC) → **+100**

Same sign, so the magnitudes are added: `200 + 100 = 300`, which does not fit in 8 bits. The result magnitude wraps to `2C` (HEX) = `44` (DEC) and `LEDR9` (overflow) turns on.

## ​🧪​ Simulation Micro-Tutorial (GHDL + GTKWave):

The whole simulation suite runs with a single command from the project root:

```bash
./sim/run_sim.sh            # add --wave to open the waveforms in GTKWave
```

It runs four testbenches and a synthesis check, writing the waveforms to `build/`:

| Testbench | What it verifies | Result |
|---|---|---|
| `sign_mag_add_orig_tb` | The **original book adder** (Listing 3.14, N=4), unmodified | 6/6 ✅ |
| `sign_mag_add_tb` | The **adapted core** (N=9, overflow + zero normalization) | 7/7 ✅ |
| `hex_to_sseg_tb` | The 7-seg decoder against the DE10-Lite pin mapping | 16/16 ✅ |
| `sign_mag_add_top_tb` | The **complete top-level**: switches, KEY0 load, KEY1 reset, HEX displays and LEDs | 6/6 ✅ |

All testbenches self-check with `assert`, so **any line containing `(assertion error)` means a failure**; a clean run prints only `report note` lines. The `metavalue detected` warnings at time 0 are expected (they occur before the stimuli reach the inputs) and are filtered by the script.

To run a single simulation manually — for example the original book code:

```bash
ghdl -a --std=08 --workdir=build/orig Projeto-VHDL/sign_mag_add.vhd sim/sign_mag_add_orig_tb.vhd
ghdl -e --std=08 --workdir=build/orig sign_mag_add_orig_tb
ghdl -r --std=08 --workdir=build/orig sign_mag_add_orig_tb --vcd=orig.vcd --stop-time=200ns
gtkwave orig.vcd
```

> **Note on work libraries:** the original adder and the adapted one declare the *same* entity name (`sign_mag_add`), so each simulation must use its own `--workdir`, otherwise one overwrites the other.

In GTKWave, add `a`, `b`, `sum` (and `ovf`, in the adapted version) to observe each test case.

## ​🔬​ Comparative Analysis (original × adapted):

Both versions implement the same algorithm from Chu, and the four sign combinations produce identical results. Simulation revealed **two limitations of the original code**, both reproduced in `sign_mag_add_orig_tb`:

| Case | Original (Listing 3.14) | Adapted (`src/`) |
|---|---|---|
| `(+5) + (−5)` | `1000` = **−0**: the sort takes the `else` branch when the magnitudes are equal, so it keeps `sign_b` | `+0`: a zero result is normalized to `+` |
| `(+7) + (+7)` | `0110` = **+6**: 14 does not fit in 3 bits and is truncated **silently** | magnitude wraps *and* raises `ovf` → `LEDR9` |

A third difference is in the **7-segment decoder**. The book's `hex_to_sseg` (Listing 3.12) puts segment `a` in the *most* significant bit (`sseg(6)=a … sseg(0)=g`), but on the DE10-Lite the pin order is the opposite (`HEX0[0]=a … HEX0[6]=g`, see `de10_lite.qsf`). The decoder in `src/` is therefore **bit-reversed** relative to the book's. `hex_to_sseg_tb` proves this is required: the adapted decoder passes 16/16 digits, while the book's original fails 14/16 on this board (only `8` and `A` pass, since their patterns happen to be palindromes).

Finally, the book's testing circuit (`sm_add_test.vhd` + `disp_mux.vhd`) time-multiplexes four displays and uses the pushbuttons to select which value to show, because the target DE1 board shares the segment pins between displays. The DE10-Lite has **six independent, non-multiplexed HEX displays**, so `disp_mux` is unnecessary: the top-level drives A, B and the result simultaneously and reuses the pushbuttons for loading and reset instead — which also makes the operands visible at the same time as the result.

## ​🧠​ Usage Tutorial: DE10-Lite + Quartus Prime Board:
1. Open Quartus Prime (Lite) version 20.1 or newer.
2. In the upper left corner, click "File" and then "New Project Wizard".
3. Click "Next". In the next tab, choose a folder and name the project **`sign_mag_add`**. Click "Next".
4. Choose "Empty project" and click "Next".
5. In the "Add Files" tab, add `sign_mag_add.vhd`, `hex_to_sseg.vhd` and `sign_mag_add_top.vhd` (from the `src` folder). Click "Next".
6. In the "Family, Device & Board Settings" tab:
   * In the "Family" field, select "MAX 10 (DA/DF/DC/SA/SC)".
   * In the "Name filter" field, type **`10M50DAF484C7G`**.
   * Select the device that appears and click "Next".
7. In the "EDA Tool Settings" tab you may leave the defaults (or select "ModelSim-Altera" / "VHDL" for simulation). Click "Next".
8. Review the summary and click "Finish".
9. Set the top-level entity to **`sign_mag_add_top`** (right-click the entity in the Project Navigator → "Set as Top-Level Entity").
10. Import the pin assignments: click "Assignments" → "Import Assignments...", select `src/de10_lite.qsf` and click "OK". This maps the switches, pushbuttons, LEDs and displays used by the design.
11. Connect the DE10-Lite board to the computer via USB cable.
12. Click "Processing" → "Start Compilation" and wait for it to finish with zero errors.
13. In the "Task" window, double-click "Program Device (Open Programmer)".
14. In the Programmer window, click "Hardware Setup", select the USB-Blaster in "Currently selected hardware" and close. Make sure "Mode" is set to "JTAG".
15. Click "Start" to program the board.

After these steps the board is running and ready to perform sign-magnitude additions.

## ​🧠​ User Tutorial: Arithmetic Tests on the DE10-Lite Board:
Both operands are loaded through the switches, one at a time, and the result is shown continuously.

1. Press `KEY1` to reset. Both operands become `+00` and all displays show zero.
2. Set `SW9 = 0` to select operand **A**. Set the sign on `SW8` and the magnitude on `SW7..SW0`, then press and release `KEY0` to store A. Its magnitude appears on `HEX1 HEX0` and its sign on `LEDR0`.
3. Set `SW9 = 1` to select operand **B**. Set the sign on `SW8` and the magnitude on `SW7..SW0`, then press and release `KEY0` to store B. Its magnitude appears on `HEX3 HEX2` and its sign on `LEDR1`.
4. The result is computed automatically: its magnitude appears on `HEX5 HEX4`, its sign on `LEDR2`, and `LEDR9` lights up if the magnitude addition overflowed.
5. To try another operation, change the switches and reload A and/or B (repeat steps 2–3). If you make a mistake at any point, press `KEY1` to reset.
