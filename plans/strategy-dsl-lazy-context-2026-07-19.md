# Plan: Strategy DSL + Lazy Context — Finish & Commit In-Flight Work

**Created:** 2026-07-19 (Sisyphus orchestration session)
**Status:** COMPLETE (2026-07-19 — commits 4c4ab694 + 37f4bb01; gate 316+21 green)
**One concern:** land the uncommitted strategy-DSL / lazy-context enhancement so HEAD is self-consistent, then gate.

## Background

An earlier session left a two-part engine enhancement uncommitted:

1. **Lazy context** — `shared/lazy_context_sylvanas.lua` (127 lines): per-tick,
   dependency-aware context proxy. `main_sylvanas.lua` `build_context()` converted so
   expensive fields (TTD fallback chain, party/group scans, `lowest_unit`/`lowest_hp`)
   resolve on demand instead of every tick.
2. **Strategy DSL** — `shared/strategy_dsl_sylvanas.lua` (396 lines): compiles
   declarative `{conditions, action}` definitions into `{name, matches, execute}`
   strategy tables. `classes/warrior/arms_sylvanas.lua` is the first adopter:
   6 strategies (BattleShout, VictoryRush, Execute, Overpower, Rend, Hamstring)
   declared in `DSL_DEFS` and substituted in-place by name, preserving priority order.

**Problem found (2026-07-19):** `tests/run_rotation_tests.lua` in HEAD already references
`test_lazy_context_sylvanas.lua`, `test_strategy_dsl_sylvanas.lua`, and
`test_arms_dsl_priority.lua`, but those files plus the two shared modules are untracked,
and `main_sylvanas.lua` / `arms_sylvanas.lua` are modified-uncommitted. HEAD is therefore
in a broken intermediate state (runner references missing files).

## Verification (done 2026-07-19)

- 316 rotation suites PASS (Lua 5.1, incl. the 3 new suites)
- 21 leveling suites PASS
- File mtimes show no active concurrent writer

## Steps

1. [x] Audit in-flight diffs — coherent, tests green
2. [x] `luac -p` on all 4 changed/new Lua files
3. [x] Commit A (lazy context): `4c4ab694` — `shared/lazy_context_sylvanas.lua`,
       `tests/test_lazy_context_sylvanas.lua`, `main_sylvanas.lua`
4. [x] Commit B (strategy DSL): `37f4bb01` — `shared/strategy_dsl_sylvanas.lua`,
       `tests/test_strategy_dsl_sylvanas.lua`, `tests/test_arms_dsl_priority.lua`,
       `classes/warrior/arms_sylvanas.lua`
5. [x] Removed stale debris `tests/run_rotation_tests.lua.tmp` (2026-07-16 leftover)
6. [x] Re-ran full gate post-commit — 316 rotation + 21 leveling green

## Environment fix landed along the way

`.git/hooks/pre-commit` (local-only) pinned to the Lua 5.1 toolchain
(`LUAC`/`LUA` vars, portable conditional). Root cause of prior commit failures:
a stray `lua` **directory** inside `C:\Program Files (x86)\Lua\5.1\` shadows
`lua.exe` during PATH resolution in Git Bash, so bare `lua`/"luac" in the hook
either missed or hit the wrong toolchain. Hook now passes end-to-end
(613 files luac + vanilla audit 31/31 + sylvanas DBC audit 61/61).

## Follow-ups (NOT this plan)

- Second-spec DSL adoption (fury warrior is the natural sibling) to validate DSL
  generality beyond arms — separate plan/commit if pursued.
- `tests/_staging/` (test_wotlk_integration.lua, phase2_hide) — decide promote or delete.
- Update `plans/_active.md` + HANDOFF.md after landing.
