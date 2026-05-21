# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-05-21
- Method: code inspection + `./build/emu` difftest runs (existing build from 2026-03-17)

## Current project understanding

- Staged Fudan 26-Arch CPU project: simulation + Difftest + `ready-to-run/` tests + Vivado/board path.
- Main student RTL lives under `vsrc/src/`; framework under `difftest/`, `vsrc/util/`.
- Active course milestone: **Lab 5** (privilege trap + Sv39 MMU); Lab 6 (interrupts) not started.

## Current implementation snapshot

- Modular **five-stage pipeline** in `vsrc/src/` (`core.sv` + decode/ALU/regfile/forwarding/hazard/CSR).
- **Lab 1–4 baseline** in place:
  - integer ALU, branch/jump, load/store with alignment and sign/zero extension
  - CSR file (`core_csr.sv`) and Zicsr in `core_decode.sv`; CSR writes flush to `pc+4`
  - `SimTop`/`VTop`: `IBusToCBus` + `DBusToCBus` + `CBusArbiter` (no MMU)
  - Difftest commit, GPR, CSR, trap-event hooks
- **Lab 5 not implemented** (code inspection):
  - no `ECALL` / `MRET` decode or trap controller
  - `priviledgeMode` hardwired to M (`2'd3`) in `DifftestCSRState`
  - no MMU module; `satp` stored but not used for address translation
  - `core_hazard_unit.sv`: load-use stall only (no trap flush beyond CSR/branch redirect)

## Current validation snapshot

| Target | Result |
|--------|--------|
| `make test-lab1` | pass — `HIT GOOD TRAP` |
| `make test-lab1-extra` | fail — `ABORT` early |
| `make test-lab2` | pass |
| `make test-lab3` | pass |
| `make test-lab4` | pass |
| `make test-lab5` | fail — prints `xv6 kernel is booting`, then `ABORT at pc = 0x8000061c` (load mismatch on `a5`) |

Lab 5 failure occurs during early kernel init (freelist), **before** `ecall`/`mret`/`satp` paths in `kernel.asm`; full Lab 5 features still need implementation regardless.

## High-level support boundary

Supported (validated):

- base `Lab1` integer subset
- `Lab2` load/store path
- `Lab3` control-flow / broader integer programs
- `Lab4` CSR read/write + Difftest CSR visibility

Not supported (validated or evident from code):

- `lab1-extra` (stronger / M-extension-heavy boundary)
- `Lab5` privilege traps (`ECALL`/`MRET`), dynamic privilege level, Sv39 MMU
- `Lab6`-style async interrupt / CLINT handling (ports exist on `core`, unused)

## Main current gaps (Lab 5)

1. Trap flow: `ECALL` → `mtvec`, save `mepc`/`mcause`, update `mstatus` (`MPP`/`MPIE`/`MIE`), enter M-mode, flush.
2. `MRET`: restore privilege from `MPP`, update `MPIE`/`MIE`/`MPP`, jump `mepc`, flush.
3. Runtime privilege register wired to Difftest (U/M; S is bonus).
4. Sv39 MMU on unified memory path (Wiki 方式 1 or 2); enable only in U/S when `satp.mode==8`.
5. Re-run `test-lab5` and Vivado board UART check after above.

## Likely next direction

1. Add system-instruction decode (`ecall`, `mret`) and trap controller in `core`.
2. Extend redirect/flush for traps (design with Lab 6 in mind).
3. Implement MMU + bus refactor; route `priv` and `satp` from `core` through `SimTop`/`VTop` if needed.
4. Regression: `test-lab4` → `test-lab5` → board.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
