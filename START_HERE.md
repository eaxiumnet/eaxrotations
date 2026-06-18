# START HERE 👋

**If you are an AI agent (Claude, Kimi, DeepSeek, MiniMax, or any other) opening
this repo: read this file first, then `AGENTS.md`. That's it. Two files.**

---

## What this project is

WoW TBC Classic bot rotations for **Project Sylvanas**, written in
**Lua 5.1 / LuaJIT**. The live product is `EaxRotations/` (29 class specs).
There's also `EaxAutoQuester/` (autonomous questing). Both run on the Sylvanas
engine and use only the `api/` + `apidocs/` surfaces.

## The two files you actually need

1. **`AGENTS.md`** (repo root) — the **single source of truth**. Project rules,
   directory map, API reference, coding patterns, the Agent Contract, current
   spec/test counts. Read it fully before writing any code.
2. **`plans/_active.md`** — what's currently being worked on. **Read this before
   starting any task** so you don't duplicate an effort another agent already
   began (that duplication was the #1 cause of agents "looping").

Everything else (`EaxRotations/CLAUDE.md`, `.cursorrules`, etc.) is a **pointer**
back to `AGENTS.md`. Don't read them for rules — they're pointers by design, to
stop the drift that used to make agents contradict each other.

## The 30-second "where is everything"

```
C:\newbot\scripts\
├── AGENTS.md                    ← READ FIRST (rules, map, contract)
├── START_HERE.md                ← you are here
├── plans/                       ← active plans + _active.md index
│   └── _archive/                ← old/done plans, by tool
├── EaxRotations/                ← THE PRODUCT (29 rotation specs)
│   ├── main_sylvanas.lua        ← dispatcher (entry point)
│   ├── core_sylvanas.lua        ← NS.* helpers (god-file — see refactor plan)
│   ├── classes/<class>/*.lua    ← one file per spec
│   ├── shared/*.lua             ← ~65 cross-class modules
│   └── tests/                   ← 127 rotation + 11 leveling suites
├── EaxAutoQuester/              ← autonomous questing (secondary product)
├── eax_refactor/                ← SANDBOX: proof-of-concept for the refactor
│   └── (not wired into the live engine — safe to ignore for normal work)
├── api/  apidocs/               ← Sylvanas engine API + docs (read-only)
├── wowheadScrape/dbc_extract/   ← DBC: authoritative spell/item data
└── wowhead_data/                ← supplementary spell/item detail (JSON)
```

## What is NOT ours (do not edit, do not plan against)

These are **external reference clones** on other platforms, mined for ideas only:

- `tbc-main/` and `_flux_tbc_explore/` — a GGL-platform rotation system (inspiration)
- `tbc_roblox/`, `ClassResearchTBC/`, `EaxESP/` — other external clones

Their `CLAUDE.md` / `AGENTS.md` files belong to *those* systems. Leave them alone.

## Before you write any code

1. Read `AGENTS.md` (rules + patterns — especially the **nil-guard** and
   **banned APIs** rules; those are where most agent-introduced bugs come from).
2. Check `plans/_active.md` (don't duplicate work).
3. `luac -p` any `.lua` file before editing it.
4. After editing: `luac -p` the changed file, then
   `lua EaxRotations/tests/run_rotation_tests.lua` — both must pass.
5. If a task loops more than 2 attempts, **stop and write a debugging note**
   in `plans/` instead of retrying.

## If you feel like you're going in circles

You probably are — and it's probably because you skipped one of the two files
above. Go back and read `AGENTS.md` and `plans/_active.md`. The Agent Contract
in `AGENTS.md` exists specifically to break loops. Rule 5: if you're stuck after
2 attempts, stop retrying and write down the failure.
