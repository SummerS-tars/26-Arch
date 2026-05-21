# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-05-21
- Method: code inspection + `make test-lab4` / `make test-lab5`

## Current project understanding

- Staged Fudan 26-Arch CPU project: simulation + Difftest + `ready-to-run/` tests + Vivado/board path.
- Main student RTL lives under `vsrc/src/`; framework under `difftest/`, `vsrc/util/`.
- Active course milestone: **Lab 5** implemented in simulation (privilege trap + Sv39 MMU); board validation/report finalization still pending.

## Current implementation snapshot

- Modular **five-stage pipeline** in `vsrc/src/` (`core.sv` + decode/ALU/regfile/forwarding/hazard/CSR).
- **Lab 1–5 simulation baseline** in place:
  - integer ALU, branch/jump, load/store with alignment and sign/zero extension
  - CSR file (`core_csr.sv`) and Zicsr in `core_decode.sv`; CSR writes flush to `pc+4`
  - `ECALL` / `MRET` decode and WB-boundary trap/mret redirect with dynamic privilege mode
  - `SimTop`/`VTop`: `IBusToCBus` + `DBusToCBus` + `CBusArbiter` + unified CBus `MMU`
  - Difftest commit, GPR, CSR, trap-event hooks
- Lab 5 test image in this workspace is locally restored from `kernel.coe` to `kernel.bin`, padded through BSS, and patched for Difftest PMP / PTE A-D compatibility.

## Current validation snapshot

| Target | Result |
|--------|--------|
| `make test-lab1` | pass — `HIT GOOD TRAP` |
| `make test-lab1-extra` | fail — `ABORT` early |
| `make test-lab2` | pass |
| `make test-lab3` | pass |
| `make test-lab4` | pass |
| `make test-lab5` | pass — prints `Return from init! Test passed` (then hangs as expected) |

Lab 5 board validation is still pending; report draft has placeholders for Vivado/serial output.

## High-level support boundary

Supported (validated):

- base `Lab1` integer subset
- `Lab2` load/store path
- `Lab3` control-flow / broader integer programs
- `Lab4` CSR read/write + Difftest CSR visibility
- `Lab5` `ECALL`/`MRET`, dynamic U/M privilege state, Sv39 MMU on unified CBus path

Not supported (validated or evident from code):

- `lab1-extra` (stronger / M-extension-heavy boundary)
- `Lab6`-style async interrupt / CLINT handling (ports exist on `core`, unused)

## Main current gaps

1. Complete Lab5 Vivado board run and fill report serial-output placeholders.
2. Export `docs/report.pdf` and run `make handin` after board evidence is added.
3. Lab6-style async interrupts / timer handling are still not implemented.

## Likely next direction

1. Fill Lab5 board evidence in `Doc/Lab5/report.md`.
2. Convert final report to `docs/report.pdf`.
3. Run `make handin` for the final submission zip.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
