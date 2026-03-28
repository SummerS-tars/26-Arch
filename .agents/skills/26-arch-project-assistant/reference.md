# 26-Arch Project Reference

This file stores relatively stable project knowledge for the `26-Arch` repository.

For current implementation progress, read `status.md`.
For command/output handling, read `verification.md`.
For refreshing this skill after the project changes, read `maintenance.md`.

## Project identity

This repository is a course CPU project rather than a blank hardware template.

The repository already provides:

- simulation framework
- Difftest integration
- prebuilt test programs
- Verilator build flow
- Vivado / board-related scaffolding

The main student work is to implement and evolve the CPU inside the existing project structure.

## Stable repository map

At a high level:

- `vsrc/`: CPU-related RTL and simulation top files
- `ready-to-run/`: prebuilt test inputs grouped by Lab
- `difftest/`: reference-model co-simulation framework
- `verilate/`: Verilator build glue
- `vivado/`: board / synthesis path
- `Doc/`: project notes, lab docs, and derived documentation
- `docs/`: submission-facing report assets
- `Makefile`: standard command entry point

## Key implementation entry points

Start here unless the current repository proves otherwise:

- `vsrc/src/core.sv`: main CPU implementation entry
- `vsrc/include/common.sv`: shared types, constants, bus definitions
- `vsrc/SimTop.sv`: simulation top integrating `core`, buses, RAM, and Difftest
- `Makefile`: canonical build/test/handin flow
- `ready-to-run/lab1/*.S`: test intent and instruction boundary hints
- `ready-to-run/lab2/*.S`: next-stage capability boundary hints

## Important role distinctions

### Simulation vs board path

Do not collapse these into one mental model.

- `SimTop.sv`: simulation-facing integration
- `VTop.sv` / `mycpu_top.sv` and `vivado/`: synthesis / board-facing path

When discussing behavior, be explicit about which path the statement belongs to.

### `Doc/` vs `docs/`

- `Doc/`: project and lab documentation
- `docs/`: report and handin-facing output

### Framework code vs student code

Usually treat these as different responsibility zones:

- student implementation focus: `vsrc/src/`, some `vsrc/include/`
- provided framework: `difftest/`, most of `vsrc/util/`, Verilator glue

If the user is implementing a Lab, default to changing the CPU-side implementation, not the framework.

## Lab progression: high-level interpretation

Use these as broad expectations, not hard claims about current code support.

### Lab1

Typically centers on:

- basic integer execution
- correct fetch/decode/execute/writeback flow
- basic pipeline or staged control
- Difftest-visible architectural correctness

`lab1-extra` is usually a stronger boundary probe than base `lab1`, so do not assume passing `lab1` implies support for all extra instructions.

### Lab2

Typically introduces or stresses:

- load/store behavior
- memory request/response handling
- width selection and sign/zero extension
- more realistic interaction with the provided bus/memory path

### Lab3

Typically moves toward:

- richer control flow
- more realistic compiled program execution
- stronger whole-program behavior rather than isolated ALU functionality

## Recommended reading orders

Choose one of these depending on the task.

### For broad project understanding

1. `Makefile`
2. `vsrc/SimTop.sv`
3. `vsrc/include/common.sv`
4. `vsrc/src/core.sv`
5. `ready-to-run/lab1/*.S`

### For current implementation review

1. `status.md`
2. `vsrc/src/core.sv`
3. any submodules under `vsrc/src/`
4. `ready-to-run/lab1/*.S` or `ready-to-run/lab2/*.S`
5. `verification.md` if test results matter

### For validation-oriented debugging

1. `verification.md`
2. `Makefile`
3. current implementation files
4. the relevant test assembly or binary source path

## Common project rules

- Use the repository's standard targets before inventing custom flows.
- Treat `Makefile` as the first source of truth for test commands.
- Treat test assembly under `ready-to-run/` as a practical boundary oracle for what a Lab may require.
- Do not infer "implemented" solely from:
  - a field existing in `decode_out_t`
  - a placeholder stage existing in the pipeline
  - a test target existing in `Makefile`
- When project facts conflict across derived docs, prefer the repository files that directly drive behavior.

## Source-of-truth priority

When facts disagree, prefer this order:

1. actual repository files used by the build or simulation flow
2. current implementation files
3. maintained project summaries such as `Doc/Project_Overview.md`
4. older notes or reports

## What this file should not hold

Do not store fast-changing facts here, such as:

- which tests currently pass
- current implementation stage
- current known limitations of the latest merged code

Put those in `status.md`.
