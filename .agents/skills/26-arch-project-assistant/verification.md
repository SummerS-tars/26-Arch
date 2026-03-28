# 26-Arch Verification Guide

This file stores standard command flow and output interpretation rules for the repository.

For stable project structure, read `reference.md`.
For current pass/fail state, read `status.md`.

## Standard commands

Use the repository `Makefile` flow by default.

- `make init`: initialize submodules
- `make sim`: build the simulator
- `make test-lab1`: run the Lab1 base test
- `make test-lab1-extra`: run stronger Lab1 coverage
- `make test-lab2`: run the Lab2 test
- `make test-lab3`: run the Lab3 test
- `make handin`: package submission assets

If these commands change in the future, update this file before changing the main skill.

## What success usually looks like

For runtime validation, keep an eye on:

- first instruction committed / Difftest enabled
- `HIT GOOD TRAP`
- final instruction / cycle counters if present

Typical high-signal success lines include:

- `The first instruction of core 0 has commited. Difftest enabled.`
- `Core 0: HIT GOOD TRAP at pc = ...`
- `instrCnt = ... cycleCnt = ... IPC = ...`

## What failure usually looks like

High-signal failure indicators include:

- `ABORT at pc = ...`
- `different at pc = ...`
- mismatched register name/value lines
- early commit trace ending at an unexpected instruction

For Difftest failures, the most valuable facts are usually:

- failing PC
- mismatched architectural register or CSR
- right vs wrong values
- the immediately preceding committed instruction(s)

## Output reduction rules

When summarizing a test run, keep:

- the command that was run
- pass/fail outcome
- the key success line or first critical failure line
- failing PC, register, instruction, or trap info
- one short next-step diagnosis

Usually drop or compress:

- repeated Verilator compile invocations
- long C++ compilation lines
- repeated framework warnings that do not change the diagnosis
- full commit traces after the first useful mismatch has already been found

## Recommended minimal summary format

Use this structure when reporting a test:

```text
Command: <command>
Result: PASS | FAIL
Key line: <GOOD TRAP or first mismatch>
Relevant detail: <pc / register / instruction / trap>
Next step: <most likely action>
```

## Filtering heuristics by situation

### Build succeeded, runtime failed

Ignore most compile noise and keep:

- first runtime failure marker
- mismatch location
- short commit context if useful

### Build failed

Ignore runtime interpretation and keep:

- first real compiler / elaboration error
- file path
- line or module name if available

### Difftest mismatch

Prioritize:

- failing architectural state
- corresponding committed instruction
- whether the issue looks like:
  - decode/control problem
  - data path / forwarding problem
  - memory/load-store problem
  - PC/control-flow problem
  - Difftest timing / commit problem

## Practical command interpretation tips

### `make test-lab1`

If this passes:

- the base integer subset is likely functioning
- Difftest commit/trap handling is at least minimally aligned

Do not conclude from this alone that:

- `lab1-extra` is supported
- M extension exists
- `lab2` memory behavior works

### `make test-lab1-extra`

Use this as a boundary probe.

If base `lab1` passes but `lab1-extra` fails, the implementation may still be valid for the intended base subset. Check whether the failure is caused by:

- unsupported instruction classes
- mis-decoding of stronger test instructions into existing ALU paths

### `make test-lab2`

Early failure often means one of:

- control semantics like `lui` / jumps are incomplete
- memory request path is still placeholder
- width/sign-extension logic is missing

Do not assume a `Lab2` failure is only a MEM-stage problem; control-flow support may also be missing.

## Quick debugging workflow

1. Run the standard target.
2. Decide whether the failure is build-time or runtime.
3. Extract the first critical signal:
   - compiler error
   - `ABORT`
   - `different at pc`
   - missing `GOOD TRAP`
4. Map the failure to likely subsystem:
   - decode / ALU
   - PC / control flow
   - load/store path
   - hazard / forwarding
   - Difftest timing
5. Read only the relevant implementation files after that.

## What this file should not hold

Do not store current pass/fail status here.

Put current project-state facts in `status.md`.
