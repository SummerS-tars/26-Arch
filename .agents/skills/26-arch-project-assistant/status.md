# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-06-14
- Method: Refactor_TODO steps 1–7 + Lab+ tasks 0–12 + Lab4/Lab5/Lab6 recorded regression + Lab+ baseline runs

## Current project understanding

- Staged Fudan 26-Arch CPU project: simulation + Difftest + `ready-to-run/` tests + Vivado/board path.
- Main student RTL lives under `vsrc/src/`; framework under `difftest/`, `vsrc/util/`.
- Active milestone: Lab+ feature work in progress; tasks 0–12 from `Doc/Lab+/TODO.md` are completed to the current verified boundary; task 13 is marked unsupported.

## Current implementation snapshot

- Modular **five-stage pipeline**:
  - `core.sv` — pipeline orchestration
  - `core_trap_ctrl.sv` — WB trap/interrupt/ecall/mret/sret and M/S delegation decision
  - `core_difftest_adapter.sv` — Difftest hooks + skip rules
  - `core_decode.sv`, `core_alu.sv`, `core_regfile.sv`, `core_forwarding_unit.sv`, `core_hazard_unit.sv`, `core_csr.sv`
- Shared packages: `trap_pkg`, `mem_helpers_pkg`, pipeline packets in `common.sv`
- Bus path: `IBusToCBus` + `DBusToCBus` + `CBusArbiter` + `MMU` (MMU flushes walk on satp/priv change)
- RV64M integer multiply/divide support is implemented in decode/ALU
- Lab+2 performance counters are available with `make sim BENCHMARK=1`
- Lab+2 static branch prediction is implemented for conditional branches: backward taken, forward not taken
- Lab+3 A extension support covers `lr.w`, `sc.w`, and all 32-bit AMO RMW ops
- Lab+4 PMP support covers `pmpaddr0/pmpcfg0` entry0 NAPOT R/W/X checks for U/S-mode fetch/load/store/AMO
- MMU page fault core path is implemented for Sv39 invalid PTE, R/W/X/A/D checks, basic U-mode checks, and fault feedback to core
- S-mode trap/delegation/`sret` core path is implemented: delegated traps write `sepc/scause/stval`, redirect to `stvec`, and `sret` restores `SPP/SPIE/SIE`
- Full xv6 main Track has been scoped: current repo has only the Lab5 trimmed kernel, no full xv6 source/image or `fs.img`, and no RAMHelper block device/RAM-disk path yet
- Lab+12 minimal I-cache is implemented after the MMU: fetch-only, physical-address, RAM-region cache; load/store/AMO/page-table walk/MMIO bypass
- Lab+13 board extension is explicitly unsupported for this iteration
- Lab 1–6 behavior preserved after refactor

## Current validation snapshot

| Target | Result |
|--------|--------|
| `make sim` | pass — after minimal I-cache implementation |
| Lab1 extra direct run | pass — `HIT GOOD TRAP at pc = 0x8002001c` |
| `make test-lab4` | pass — `HIT GOOD TRAP at pc = 0x8001fff8`, `cycleCnt = 124,690` after I-cache |
| `make test-lab5` | pass — `Return from init! Test passed` |
| `make test-lab5-extra` | pass — `HIT GOOD TRAP at pc = 0x800002b4`, covers delegated U-mode ecall to S trap and `sret` return |
| `make test-lab6` | pass — `Privileged test finished.` / `Exit with code = 0` |
| Lab+11 xv6 attempt | scoped — existing Lab5 trimmed kernel reaches `xv6 kernel is booting` / `Return from init! Test passed`; full shell is blocked by missing full xv6 image/source and block device/RAM-disk support |
| Lab+2 direct run | partial — no mismatch; default delay passes qsort/queen before 600s timeout, `DELAY=0` passes qsort/queen/bf before 600s timeout |
| Lab+2 perf sample | pass — after I-cache 50M-cycle sample IPC ~0.307, `fetch_waits` ~18.5M/50M; previous status snapshot was IPC ~0.190, `fetch_waits` ~31.2M/50M |
| Lab+3 direct run | pass — `HIT GOOD TRAP at pc = 0x800000dc`, `cycleCnt = 221` after I-cache |
| Lab+3 full AMO W self-test | pass — `HIT GOOD TRAP at pc = 0x800001c4` |
| Lab+4 direct run | pass for front privileged/PMP phase — `Single test passed.`; 80M-cycle run proceeds through paint/CoreMark/Dhrystone and reaches stream |
| Page fault diagnostic self-test | partial — Difftest shows DUT load page fault state `mcause=13`, `mtval=0x40000000`; no-diff good-trap harness still needs polish |

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

1. Further performance work can extend the I-cache with larger lines or sequential prefetch.
2. Keep D-cache deferred unless the scope explicitly accepts store/MMIO/AMO consistency risk.
3. Continue full xv6 only after providing/importing modifiable xv6 source plus a filesystem image; prefer RAM disk before virtio-mmio.
4. Polish page-fault no-diff self-tests or refine S-level interrupt/SUM/MXR/TSR/TW/TVM semantics if needed for reports.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
