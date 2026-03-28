# 26-Arch Skill Maintenance Guide

This file explains how to keep the project skill accurate as the repository evolves.

The main idea is to separate stable guidance from fast-changing facts so updates stay small and cheap.

## Layer model

Update the smallest necessary layer first.

### Stable layer

These should change rarely:

- `SKILL.md`: trigger behavior, task routing, default workflow
- the overall structure of the skill itself

### Semi-stable layer

These change when repository facts or workflows evolve:

- `reference.md`: project map, key file roles, stable rules
- `verification.md`: commands, output interpretation, noise filtering
- `Doc/Specification/26-Arch-Project-Specification.md`: human-facing summary of the same model

### Fast-changing layer

This should be updated most often:

- `status.md`: current implementation stage, current validation state, main gaps, likely next direction

## Typical change triggers

Update this skill when any of the following happens:

- repository structure changed
- key implementation entry points moved
- standard test commands changed
- log patterns changed enough that the filtering rules are no longer accurate
- a new Lab or phase became relevant
- current implementation status changed in a way future analysis should know about

## Source-of-truth files to inspect first

When refreshing the skill, check these before editing any summary:

- `Makefile`
- `README.md`
- `Doc/`
- `ready-to-run/`
- `vsrc/include/common.sv`
- `vsrc/SimTop.sv`
- `vsrc/src/`

If current code behavior matters, also run the standard relevant test target.

## Update workflow

### 1. Reconfirm repository facts

Check whether any of these changed:

- key directories
- canonical commands
- important entry files
- Lab boundaries inferred from tests

If yes, update `reference.md` and possibly `verification.md`.

### 2. Refresh current project status

If the repository facts are mostly the same but implementation progress changed, update only `status.md`.

Typical examples:

- a new test now passes
- a previously known limitation was removed
- current work shifted from Lab1 to Lab2
- the likely next direction changed

### 3. Refresh validation rules if needed

Update `verification.md` only when:

- commands changed
- output patterns changed
- a new class of high-value runtime evidence became relevant
- existing noise-filter rules are no longer enough

### 4. Change `SKILL.md` only when necessary

Edit `SKILL.md` only if one of these changed:

- when the skill should trigger
- how proactive it should be
- which reference files it should load first
- the default task routing model

Do not put current implementation details into `SKILL.md`.

### 5. Keep the human-facing spec aligned

If the project model changed materially, update:

- `Doc/Specification/26-Arch-Project-Specification.md`

This document should match the skill's structure, but it can be more explanatory.

## Minimal-change editing rules

- Prefer updating one lower layer rather than rewriting everything.
- Keep `status.md` short and high-level.
- Avoid copying the same fact into multiple files unless it is truly stable.
- If a fact changed and appears in several files, correct the source-oriented file first:
  - project fact -> `reference.md`
  - command/output handling -> `verification.md`
  - current progress -> `status.md`

## Quick regression check after updates

After editing, verify:

1. The paths referenced in `SKILL.md` still exist.
2. The standard commands in `verification.md` still match `Makefile`.
3. `status.md` reflects the latest known project state.
4. The skill still separates:
   - stable project facts
   - current implementation snapshot
   - validation interpretation

## Recommended cadence

Update:

- `status.md` whenever the current implementation stage or validated support boundary changes
- `reference.md` when the repository or project structure changes
- `verification.md` when command or output interpretation changes
- `SKILL.md` only when the skill's own behavior should change

## Anti-patterns

Avoid these:

- rewriting `SKILL.md` for every implementation milestone
- putting volatile pass/fail facts into `reference.md`
- storing detailed debug transcripts in `status.md`
- copying full test logs into any skill reference file

## If unsure what to update

Use this fallback:

- Only implementation progress changed -> update `status.md`
- A project fact or file role changed -> update `reference.md`
- A command or log-reading rule changed -> update `verification.md`
- The skill should trigger or behave differently -> update `SKILL.md`
