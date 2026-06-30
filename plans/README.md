# Plans

This is the **single active plans directory** for the EAX codebase.

## Rules

1. **One plan per effort.** If you're starting new work, create one file here
   (e.g. `plans/<effort>-<date>.md`) and add a row to `_active.md`.
2. **Check `_active.md` first.** It tells you what's in progress so you don't
   duplicate an effort another agent already started. (That duplication was the
   #1 cause of agents "running in loops".)
3. **Finished or abandoned → `_archive/`.** Don't leave dead plans in the active
   list. Move the file to `plans/_archive/` and delete its row from `_active.md`.
4. **Reference-system plans are out of scope.** `tbc-main/`, `_external_tbc_explore/`,
   `tbc_roblox/`, `ClassResearchTBC/`, `EaxESP/` are external clones — do not
   plan work against them.

## Layout

```
plans/
├── _active.md          ← READ THIS FIRST: what's currently being worked on
├── README.md           ← this file
├── <effort>.md         ← active plan files
└── _archive/
    ├── omo/            ← plans previously in .omo/plans (archived 2026-06-19)
    ├── opencode/       ← plans previously in .opencode/plans
    └── eaxautoquester/ ← plans previously in EaxAutoQuester/plans
```

## Why this consolidation happened

Before 2026-06-19 there were **five** separate `plans/` directories — one per AI
tool (`.omo/`, `.opencode/`, `EaxAutoQuester/`, `EaxRotations/`, top-level).
Each tool created its own scratch space and none knew about the others, so
multiple agents would independently plan and start the *same* effort, then
appear to "loop" when their work collided. Consolidating to one directory with
an `_active.md` index fixes that at the root cause.
