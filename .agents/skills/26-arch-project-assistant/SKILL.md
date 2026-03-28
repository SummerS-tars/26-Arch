---
name: 26-arch-project-assistant
description: Project-specific guide for the Fudan 26-Arch repository. Use proactively whenever work happens in this repository or the user mentions Lab1/Lab2/Lab3, core.sv, SimTop, difftest, ready-to-run tests, Verilator, Vivado, report/handin flow, project structure, implementation strategy, validation, debugging, or current progress. Prefer this skill for repository analysis, implementation review, test-log interpretation, and project-status follow-up instead of giving generic CPU advice.
---
# 26-Arch Project Assistant

Use this skill as the default project guide for this repository. The goal is to keep answers aligned with the actual course project, its repository layout, and its standard validation flow.

## Core principle

Prefer project-specific facts over generic CPU knowledge.

In particular:

- Trust the repository's current `Makefile`, `README.md`, `Doc/`, `ready-to-run/`, `vsrc/`, and simulation top files more than abstract assumptions.
- Keep stable project knowledge separate from the current implementation snapshot.
- Compress noisy logs aggressively and preserve only information that changes diagnosis or next steps.

## Read the minimum useful context first

Before giving substantial guidance, identify the task type and read only the relevant files:

- For project structure, requirements, entry files, or implementation direction:
  - read `reference.md`
  - read `status.md`
- For test commands, log interpretation, Difftest output, or validation workflow:
  - read `verification.md`
  - read `status.md`
- For refreshing this skill after the repository evolves:
  - read `maintenance.md`
- For a human-oriented, fuller project summary:
  - read `Doc/Specification/26-Arch-Project-Specification.md`

If the user is asking about a specific implementation file, also read that file directly after loading the relevant project references.

## Task routing

### 1. Repository or Lab understanding

Use this route when the user asks:

- what the project is
- which files matter
- what Lab1/Lab2/Lab3 broadly require
- how the repository is organized

Action:

- Load `reference.md`
- Use `status.md` to avoid describing outdated implementation state as current fact

### 2. Current implementation analysis

Use this route when the user asks:

- how a current implementation works
- what has or has not been implemented
- whether the current code supports a later Lab
- how to understand a specific module or design choice

Action:

- Load `status.md`
- Load `reference.md`
- Read the concrete implementation files in question
- Distinguish clearly between:
  - stable project constraints
  - current implementation choices
  - inferred future work

### 3. Validation, debugging, or output interpretation

Use this route when the user asks:

- which command to run
- whether a test passed
- what part of a long terminal output matters
- how to interpret a Difftest mismatch

Action:

- Load `verification.md`
- Keep only the command, success/failure indicator, first critical mismatch, relevant PC/register/instruction info, and next action
- Avoid replaying full build logs unless the build itself failed

### 4. Skill or project-reference refresh

Use this route when:

- the repository structure changed
- commands changed
- new Labs were added
- the current implementation status changed enough to invalidate old summaries

Action:

- Load `maintenance.md`
- Update the smallest necessary layer first:
  - `status.md` for current progress
  - `reference.md` for project facts
  - `verification.md` for command/output rules
  - `SKILL.md` only if trigger/workflow behavior changed

## Working rules

- Prefer concise, high-signal summaries.
- Always separate "repository fact" from "current implementation status".
- Do not assume a Lab is supported just because the repository contains its test files.
- When discussing tests, say explicitly whether the statement is based on:
  - repository structure
  - code inspection
  - actual test execution
- Treat `SimTop.sv`, `VTop.sv`, and `mycpu_top.sv` as different roles unless the current files prove otherwise.
- Treat `Doc/` and `docs/` as different purposes unless the repository changes them.

## Output expectations

When reporting project-related conclusions:

- State the current scope in one line.
- Give the minimal reasoning needed to support the conclusion.
- If tests were run, include:
  - command
  - pass/fail
  - key success or failure line
  - the most relevant next step

When the user asks for broad guidance, prefer:

1. project entry points
2. validation path
3. current status
4. recommended next direction

## Avoid these failure modes

- Giving generic CPU advice without anchoring it to this repository
- Treating stale summaries as source of truth after the repository changes
- Dumping full compiler or Verilator logs into the response
- Confusing "field exists in decode struct" with "feature is implemented"
- Confusing "has a test target" with "current implementation passes that target"

## Reference files

- `reference.md`: stable project map, key files, and common rules
- `verification.md`: standard commands, output filtering, and validation guidance
- `maintenance.md`: how to refresh this skill as the project evolves
- `status.md`: current high-level implementation and validation snapshot
