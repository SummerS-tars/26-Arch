# 26-Arch Current Status

This file is the fast-changing snapshot for the repository.

Keep it short.
Update it whenever the current implementation stage or verified support boundary changes.

## Last checked

- Date: 2026-03-28

## Current project understanding

- The repository is a staged CPU course project built around provided simulation, Difftest, test programs, and later board flow.
- The main implementation focus is still centered on the CPU-side RTL under `vsrc/`.
- Standard validation is driven by `Makefile` targets such as `make test-lab1`, `make test-lab1-extra`, and `make test-lab2`.

## Current implementation snapshot

- A modular five-stage pipeline-style implementation exists in `vsrc/src/`.
- The current code includes:
  - register file
  - decode
  - ALU
  - hazard detection skeleton
  - forwarding unit
  - Difftest commit / register-state handling
- The current implementation is best described as:
  - `Lab1` base subset implementation
  - not yet a full `Lab1-extra` or `Lab2` implementation

## Current validation snapshot

- `make test-lab1`: passes
- `make test-lab1-extra`: fails
- `make test-lab2`: fails

## High-level support boundary

Currently supported at a high level:

- base integer ALU-style `Lab1` path
- basic pipeline progression
- basic forwarding / stall framework
- Difftest-visible commit path for the current supported subset

Currently not yet validated as supported:

- M-extension-heavy `lab1-extra`
- `Lab2` control and memory behavior
- load/store data path
- broader control-flow support

## Main current gaps

- unsupported or mis-decoded stronger instruction classes beyond the base `Lab1` subset
- MEM stage is not yet a full load/store implementation
- later-Lab control semantics are not yet established as working

## Likely next direction

- expand decode/control semantics
- implement real MEM-stage behavior
- continue validation against stronger tests
- refresh this status after every meaningful pass/fail boundary change

## Update rule

When the project advances, update this file before touching the main skill unless the trigger/workflow itself needs to change.
