# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-06-08
- Method: code inspection + Lab6 simulation + Lab4/Lab5 regression

## Current project understanding

- Staged Fudan 26-Arch CPU project: simulation + Difftest + `ready-to-run/` tests + Vivado/board path.
- Main student RTL lives under `vsrc/src/`; framework under `difftest/`, `vsrc/util/`.
- Active course milestone: **Lab 6** implemented and simulation-validated. Lab5 privilege trap + Sv39 MMU has passed simulation and board UART validation.

## Current implementation snapshot

- Modular **five-stage pipeline** in `vsrc/src/` (`core.sv` + decode/ALU/regfile/forwarding/hazard/CSR).
- **Lab 1–6 baseline** in place:
  - integer ALU, branch/jump, load/store with alignment and sign/zero extension
  - CSR file (`core_csr.sv`) and Zicsr in `core_decode.sv`; CSR writes flush to `pc+4`
  - `ECALL` / `MRET` decode and WB-boundary trap/mret redirect with dynamic privilege mode
  - Lab6 exception packet propagation for illegal instruction, instruction misalignment, load/store misalignment, and `ecall`
  - Lab6 machine interrupt handling for software, timer, and external interrupt pending lines
  - `SimTop`/`VTop`: `IBusToCBus` + `DBusToCBus` + `CBusArbiter` + unified CBus `MMU`
  - Difftest commit, GPR, CSR, trap-event hooks
- Lab 5 test image in this workspace is locally restored from `kernel.coe` to `kernel.bin`, padded through BSS, and patched for Difftest PMP / PTE A-D compatibility.
- Lab 6 test assets are present:
  - `ready-to-run/lab6/lab6-test.bin`
  - `ready-to-run/lab6/lab6-test.S`
  - `Makefile` target `test-lab6` runs `./build/emu --no-diff -i ./ready-to-run/lab6/lab6-test.bin`

## Current validation snapshot

| Target | Result |
|--------|--------|
| `make test-lab1` | pass — `HIT GOOD TRAP` |
| `make test-lab1-extra` | fail — `ABORT` early |
| `make test-lab2` | pass |
| `make test-lab3` | pass |
| `make test-lab4` | pass |
| `make test-lab5` | pass — prints `Return from init! Test passed` (then hangs as expected) |
| `make test-lab6` / direct Lab6 emu run | pass — prints `Privileged test finished.` and `Exit with code = 0` |

Lab 5 board UART output has been reported successful after synchronizing `kernel.coe` and adding an MMU response-separation state for board BRAM timing.

## High-level support boundary

Supported (validated):

- base `Lab1` integer subset
- `Lab2` load/store path
- `Lab3` control-flow / broader integer programs
- `Lab4` CSR read/write + Difftest CSR visibility
- `Lab5` `ECALL`/`MRET`, dynamic U/M privilege state, Sv39 MMU on unified CBus path, board UART validation
- `Lab6` precise exceptions and machine software/timer/external interrupt handling in simulation

Not supported (validated or evident from code):

- `lab1-extra` (stronger / M-extension-heavy boundary)
- Lab6 Bonus page-fault exception is not implemented.

## Main current gaps

1. Keep Lab6 report and handin assets synchronized with the final RTL.
2. If board validation is later required, re-check the unified CBus/MMU timing path separately from Lab6 simulation.

## Likely next direction

1. Package handin assets with `make handin` when ready.
2. Preserve Lab4/Lab5 regression checks when changing CSR/trap behavior.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
