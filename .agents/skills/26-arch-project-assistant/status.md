# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-06-14
- Method: Refactor_TODO steps 1–7 + Lab+ tasks 0–12 + Lab+11 RAM-disk loader micro-test + xv6 source/build/RAM-disk adaptation attempt + Lab4/Lab5/Lab6 recorded regression + Lab+ baseline runs

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
- Full xv6 main Track has been scoped: current repo has the Lab5 trimmed kernel plus imported modifiable upstream `xv6-riscv` source under `third_party/xv6-riscv`; emu has a fixed-address `--fs-image` RAM-disk loading path; RISC-V GCC/binutils are installed; xv6-side RAM-disk driver/platform bring-up reaches kernel boot banner and user-entry vicinity but not shell
- Lab+12 minimal I-cache is implemented after the MMU: fetch-only, physical-address, RAM-region cache; load/store/AMO/page-table walk/MMIO bypass
- Lab+13 board extension is explicitly unsupported for this iteration
- Full xv6 import path recommendation: keep flat `kernel.bin` loading and use the verified `--fs-image` RAM-disk path before attempting virtio-mmio
- S-mode timer delegation diagnostic assets exist under `ready-to-run/lab+/11/`, but the current no-diff run reaches a cycle cap instead of a clean good/bad trap
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
| Lab+11 RAM-disk loader micro-test | pass — `--fs-image ./ready-to-run/lab+/11/ramdisk_magic.img` loads 4 bytes to `0x87000000`; `ramdisk_magic_test.bin` reads `0x12345678` and hits good trap at `0x80000028` |
| Lab+11 xv6 source build | pass — `make labplus-xv6-build` produces `ready-to-run/lab+/11/xv6-kernel.bin` and `xv6-fs.img`; QEMU is still absent but not needed for emu |
| Lab+11 xv6 RAM-disk run | partial — `--fs-image` loads 2,048,000-byte `xv6-fs.img` to `0x87000000`; after switching xv6 to `rv64g`, the full kernel prints `xv6 kernel is booting`; S-mode `mret` path reaches cycle cap at user VA `pc = 0x0`, but shell/init output is not visible yet |
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

1. Next small xv6 step: instrument `init`/`usertrap`/`sys_open`/`sys_write` to locate why `init: starting sh` is not printed after reaching user VA `pc = 0x0`.
2. Keep xv6 built as `rv64g`; the current CPU does not implement RVC, so `rv64gc` binaries diverge at the entry path.
3. Refine S-level timer interrupt delegation after the current diagnostic can be made to end cleanly.
4. Further performance work can extend the I-cache with larger lines or sequential prefetch; keep D-cache deferred unless the scope accepts store/MMIO/AMO consistency risk.

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
