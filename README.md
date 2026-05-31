# Simple 8-bit Soft-Core CPU — Verilog / FPGA

> **Program:** Chip Design — FPT Jetking · May 2026  
> **Supervisor:** Ths. Tran Tuan Kiet

---

## Overview

A fully functional 8-bit soft-core CPU implemented in Verilog and synthesised on a Xilinx Artix-7 (Basys3/Nexys-class) FPGA using Vivado 2024.2. The processor executes programs stored in a 16-byte on-chip ROM and displays computed results on a 3-digit 7-segment display via a Double-Dabble BCD conversion chain.

---

## Architecture

| Attribute | Detail |
|---|---|
| Data width | 8-bit |
| Instruction word | 16-bit (2-byte fetch) |
| ISA | 8 instructions — MOV, ADD, SUB, ABS, NOT, AND, NEG, HLT |
| Control | 9-phase multi-cycle FSM (CLK1–CLK9), synchronous, single clock domain |
| Register file | 8 × 8-bit (R0–R7), synchronous write / combinational dual read |
| Target device | Xilinx XC7A35T @ 100 MHz |
| Toolchain | Vivado 2024.x + xsim |

**Datapath pipeline per instruction (9 phases):**

| Phase | Activity |
|---|---|
| CLK1 | ROM outputs high byte |
| CLK2 | ROM outputs low byte; IR latches opcode + operand fields |
| CLK3 | IR latches immediate; Decoder captures opcode |
| CLK4–CLK5 | Decoder sets MUX select and register-file read enables |
| CLK6 | ALU computes; result latched |
| CLK7 | MOV write-back |
| CLK8 | ALU-op write-back (ADD/SUB/ABS/NOT/AND/NEG) |
| CLK9 | Enables cleared; PC increments; next instruction starts |

> **Note:** MOV write-back occurs one phase earlier than all other ops — an asymmetry intentional to the control design but not documented in the original RTL comments.

---

## Sub-modules

| Module | File | Function |
|---|---|---|
| Machine_Code_ROM | `machine_code_rom_1.v` | 128-bit LUT-ROM; PC + master phase counter |
| Instruction_Register | `intruction_register1.v` | Latches opcode, flags, address, immediate |
| Instruction_Decoder | `intruction_decoder1.v` | Control unit; generates timed enable signals |
| Mul_Reg_to_ALU | `mul_to_alu1.v` | 2-to-1 operand MUX (immediate vs register) |
| ALU_Module | `alu_1.v` | 8-bit arithmetic/logic; registered output |
| Data_Register | `data_register_module_0.v` | 8×8 register file |
| bin_to_bcd | `bin_to_bcd.v` | Double-Dabble combinational converter |
| hex_to_7seg | `hex_to_7seg.v` | BCD → 7-segment pattern (active-low) |
| seven_seg_mux | `sen_seg_mux.v` | Time-multiplexed 3-digit scan @ ~381 Hz |

---

## Test Program & Expected Results

The ROM is pre-loaded with 8 instructions exercising all opcodes:

| # | Instruction | Result (hex) | Result (dec) |
|---|---|---|---|
| 0 | MOV R0, 60 | 0x3C | 60 |
| 1 | ADD R0, 70 | 0x82 | 130 |
| 2 | SUB R0, 180 | 0xCE | 206 (signed −50) |
| 3 | ABS R0 | 0x32 | 50 |
| 4 | NOT R0 | 0xCD | 205 |
| 5 | AND R0, 0x0F | 0x0D | 13 |
| 6 | NEG R0 | 0xF3 | 243 |
| 7 | HLT | 0xF3 | 243 (frozen) |

**Final display output: 243**

---

## Verification 
Verified an 8-bit CPU (9-phase gated-clock pipeline, 3-bit ISA, 8×8-bit register file, 8-instruction ROM) on Basys3; wrote verification plan from functional spec before writing any testbench code.

- Wrote 13 directed test cases and 7 concurrent assertions in Vivado xsim (Verilog); checked full golden trace (MOV→ADD→SUB→ABS→NOT→AND→NEG→HLT, R0 = 0x3C → 0x82 → 0xCE → 0x32 → 0xCD →0x0D→0xF3) and confirmed 9-phase sync across ROM, IR, Decoder, ALU, and write-back window against spec.
-	Built scoreboard comparing result_out to 7-entry golden reference (separate fail counter); 0 failures across 92 checks; added coverage model tracking opcode bins (7/8) and reset-phase bins (8/8) to measure how much of the state space had been tested.
-	Found RTL timing bug via assertion A7: MOV fires Enable_Write_Data at CLK7 (one cycle early), invisible to output comparison — only caught by concurrent assertion; root-caused to missing opcode guard in Decoder CLK7 case.
-	 Verified 5 RTL fixes via dedicated test cases: HLT PC freeze (opcode guard on instruction_counter), phase-skew fix (single master_phase broadcast from ROM), check_* observability mapping; confirmed reset clears all state across all 8 pipeline phases.

## RTL Issues Identified
Fix RTL decoder (P0) — xóa MOV write-back khỏi CLK7
Fix TC12 unsigned mod (P1) — để random phase coverage thực sự random đúng
Re-run simulation sau fix → A7 phải = 0 failures, TC12 phải hit phases 1–8 đủ

---

## Resource Utilisation (Estimated, XC7A35T)

| Resource | Used | Available |
|---|---|---|
| Slice LUTs | 171 | 20,800 |
| Slice Registers | 179 | 41,600 |
| IO | 21 | 106 |
| BUFG | 1 | 32 |

---

## Future Work

- Replace manual 9-phase counter with a proper one-hot FSM
- Add Program Counter + branch/jump instructions for loop support
- Extend to multi-register operands with hazard detection
- Add SVA assertions and functional coverage model
- UART runtime program loader (replace hardcoded ROM)
- Migrate toward a RISC-V RV32I subset

---

## References

1. Malvino & Brown, *Digital Computer Electronics*, McGraw-Hill, 1977  
2. Ben Eater, *Build an 8-bit computer from scratch* — eater.net/8bit  
3. C. E. Cummings, *Nonblocking Assignments in Verilog Synthesis*, SNUG 2000  
4. Xilinx, *Vivado Design Suite UG901*, 2024  
5. IEEE Std 1364-2001 — Verilog HDL  
6. Harris & Harris, *Digital Design and Computer Architecture*, 2nd ed., Morgan Kaufmann, 2012
