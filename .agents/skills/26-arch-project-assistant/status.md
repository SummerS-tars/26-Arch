# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-06-08
- Method: Refactor_TODO steps 1–7 + incremental commits + Lab4/Lab5/Lab6 regression

## Current project understanding

- Staged Fudan 26-Arch CPU project: simulation + Difftest + `ready-to-run/` tests + Vivado/board path.
- Main student RTL lives under `vsrc/src/`; framework under `difftest/`, `vsrc/util/`.
- Active milestone: **Refactor_TODO 1–7 complete** on `refactor/before_labplus`; ready to start lab+ feature work.

## Current implementation snapshot

- Modular **five-stage pipeline**:
  - `core.sv` (~560 lines) — pipeline orchestration
  - `core_trap_ctrl.sv` — WB trap/interrupt/ecall/mret
  - `core_difftest_adapter.sv` — Difftest hooks + skip rules
  - `core_decode.sv`, `core_alu.sv`, `core_regfile.sv`, `core_forwarding_unit.sv`, `core_hazard_unit.sv`, `core_csr.sv`
- Shared packages: `trap_pkg`, `mem_helpers_pkg`, pipeline packets in `common.sv`
- Bus path: `IBusToCBus` + `DBusToCBus` + `CBusArbiter` + `MMU` (MMU flushes walk on satp/priv change)
- Lab 1–6 behavior preserved after refactor

## Current validation snapshot

| Target | Result |
|--------|--------|
| `make test-lab4` | pass — post-refactor verified |
| `make test-lab5` | pass — `Return from init! Test passed` |
| `make test-lab6` | pass — `Privileged test finished.` / `Exit with code = 0` |
| `test-labplus-2/3/4` | not run yet — next lab+ baseline |

## Refactor boundary (completed)

Steps 1–7 from `Doc/Refactor_TODO.md` are done on branch `refactor/before_labplus`:

1. `trap_pkg` constants
2. `mem_helpers_pkg`
3. pipeline packets (`id_ex_t` / `ex_mem_t` / `mem_wb_t`)
4. `core_trap_ctrl.sv`
5. `core_difftest_adapter.sv`
6. `core_csr.sv` section cleanup + mip/mie comment
7. MMU context flush; IBus/CBus timing notes (no behavior change that breaks Lab5)

## Likely next direction

1. Run `test-labplus-2/3/4` to record failure baseline.
2. Implement lab+ in `core_trap_ctrl.sv` / `core_csr.sv` on separate commits.
3. Revisit IBus addr latch / CBus `saved_req` hold after lab+ with board regression if needed.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
