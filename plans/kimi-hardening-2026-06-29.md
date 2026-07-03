# EaxRotations Hardening Plan — For Kimi Execution

**Date**: 2026-06-29
**Author**: GLM (verified), hand-off to Kimi
**Branch**: master
**Test baseline**: 208/208 rotation suites + 11/11 leveling suites PASS
**Production files**: 416 Lua, 0 syntax errors, version 2.2.0

---

## ⚠️ READ THIS FIRST — Verification Context

A prior "deep analysis" report (by a sub-agent) claimed 3 Critical + 15 High issues.
**Manual line-by-line verification proved most were FALSE POSITIVES.** Before executing
anything, understand what was checked and debunked:

### Debunked "Critical" claims (DO NOT "fix" these — they are correct)
| Claim | Verified Reality |
|-------|------------------|
| `combat_forecast_gate` uses undocumented `is_boss()` | `is_boss()` IS documented (`apidocs/pages/dev/api/game-object.md:58`) AND nil-guarded. Correct. |
| `dispel_manager:117` `ipairs(entry.ids)` crashes on nil | HAS guard `if entry.ids and #entry.ids > 0 then`. Correct. |
| `targeting`/`stealth`/`pet_heal`/`stopcast` no-pcall crashes | All nil-guarded via `if not unit or not unit:method()` short-circuit. Low risk. |
| `_manual_target_lockout_until` "infinite extension" | Intentional design — respects manual target 3s. Correct. |
| Mage Counterspell missing in Arcane/Fire | Wired at middleware (`middleware_sylvanas.lua:102`), shared by all 3 specs. Works. |
| Hunter cliptracker is a 38-line stub | Delegates to `hunter_core_sylvanas.lua` (384 lines) with real weave math. All 3 specs use `can_cast_steady()`. Functional. |

### What is ACTUALLY verified (the real work)

Only **4 items** survived verification. This plan addresses them. Items are ordered by
value/effort ratio. Each is self-contained and independently revertable.

---

## WORK ITEM 1 — Wire `context.spell_damage` (Medium value, Low effort)

### Problem
8 specs read `context.spell_damage or 0` for DoT snapshot-upgrade logic, but
`build_context()` in `main_sylvanas.lua` never populates it. Result: snapshot logic
always sees `0`/`0` and degrades to "refresh normally" (loses the spell-power-buff
hold-refresh optimization). Low DPS impact but it's dead logic pretending to be live.

### Verified evidence
- `grep "spell_damage" EaxRotations/main_sylvanas.lua EaxRotations/core_sylvanas.lua` → empty
- Consumers: `affliction_sylvanas.lua:191`, `shadow_sylvanas.lua:329`, `elemental_sylvanas.lua`, `balance_sylvanas.lua` (×2), plus vanilla mirrors
- `should_snapshot_upgrade(0, 0, remains, ...)` → `snapshotted_dmg <= 0` branch → returns `true` (no-op pass-through)

### API available
`api/common/utility/spell_helper.lua:54` — `spell_helper:get_spell_damage(spell_id, ignore_percentage?, ignore_flat?)`
⚠️ Doc says: "parsed tooltip info, is not precise and doesnt support all spells."
`api/core.lua:1860` — `core.spell_book.get_spell_damage` is **deprecated** (commented out).

### Decision: REMOVE the dead logic (not wire it)
Rationale: The only available API is imprecise tooltip parsing. Wiring an imprecise value
into snapshot gating could cause DoTs to NOT refresh when they should — worse than the
current no-op. The safest, highest-clarity fix is to **remove the snapshot-upgrade gate**
so the code honestly reflects what it does (normal pandemic refresh).

### Steps
1. In each consumer file, the `should_snapshot_upgrade(...)` call in the DoT `matches`
 function is wrapped in a `not` guard. Remove that guard line and the
 `snapshot_*_dmg` state field writes in the `execute` function.
2. Leave `should_snapshot_upgrade` helper defined (used by cat druid for attack-power
 snapshots which ARE wired via `context.attack_power`).
3. Files to edit (Sylvanas only — leave vanilla mirrors for a separate pass):
 - `EaxRotations/classes/warlock/affliction_sylvanas.lua`
 - `EaxRotations/classes/priest/shadow_sylvanas.lua`
 - `EaxRotations/classes/shaman/elemental_sylvanas.lua`
 - `EaxRotations/classes/druid/balance_sylvanas.lua`
4. Per-file: remove the `not should_snapshot_upgrade(state.spell_damage or 0, ...)` line
 and the `if ok and aff_state.spell_damage then aff_state.snapshot_*_dmg = ...` line.
 Keep the `remains > DOT_REFRESH_WINDOW` guard (that's the real refresh logic).
5. Remove `spell_damage = 0,` from each spec's state table init (dead field).

### Validation
- `luac -p` on each edited file
- `lua EaxRotations/tests/run_rotation_tests.lua` → must stay 208/208
- `lua EaxRotations/tests/run_leveling_tests.lua` → must stay 11/11
- Grep confirms no remaining `state.spell_damage` reads in Sylvanas specs

### Risk
Low. Removing a no-op gate. DoTs will refresh on the pandemic window as they effectively
already do. Revertable per-file.

---

## WORK ITEM 2 — Static buffers for hot-path allocations (Low value, Low effort, Pattern 4)

### Problem
Three shared modules allocate fresh tables per call in hot paths, violating AGENTS.md
Pattern 4 (static table reuse). Minor GC pressure, not a crash risk.

### Verified evidence
- `ttd_tracker_sylvanas.lua:209-210` — `local xs = {}`, `local ys = {}` per `estimate_ttd()`
- `incoming_heal_predictor_sylvanas.lua:382, 572` — `local units = {}`, `local out = {}`
- `hot_tick_tracker_sylvanas.lua:236` — `local out = {}` per `get_all()`

### Steps (per file)
1. Declare module-level static buffer(s) near top: `local _xs, _ys = {}, {}`
2. In the function, replace `local xs = {}` with:
 ```lua
 for i = #_xs, 1, -1 do _xs[i] = nil end
 for i = #_ys, 1, -1 do _ys[i] = nil end
 local xs, ys = _xs, _ys
 ```
3. For `out = {}` patterns returning a table to callers: **CANNOT** reuse if caller retains
 the reference. Check each call site — if the result is consumed immediately (iterated,
 summed, discarded), a static buffer is safe. If it's stored/returned up-stack, leave as
 `local out = {}` (allocation is correct there).

### ⚠️ Caution
`ttd_tracker` `estimate_ttd` builds `xs`/`ys` and passes to `linear_regression` which
**consumes them synchronously** — safe to reuse. Verify `incoming_heal_predictor.scan`
and `hot_tick_tracker.get_all` return tables that are NOT retained by callers before
converting. When in doubt, LEAVE the allocation (it's correct, just not optimal).

### Validation
- `luac -p` each file
- Full test suite 208+11 must pass
- No test should depend on table identity across calls

### Risk
Low if call-site retention is checked. If a caller retains the returned table, reusing the
buffer would cause aliasing bugs. **Verify call sites first.**

---

## WORK ITEM 3 — Make `test_cross_expansion_spell_validation.lua` portable (Low value, Low effort)

### Problem
`EaxRotations/tests/test_cross_expansion_spell_validation.lua:43` uses
`io.popen("dir /s /b EaxRotations\\classes\\*_vanilla.lua 2>NUL")` — Windows-only.
Breaks on Linux CI. Also `io.popen` is a banned API (acceptable in tests, but the
Windows-specificity is the real issue).

### Verified evidence
Line 43: `local pipe = io.popen("dir /s /b EaxRotations\\classes\\*_vanilla.lua 2>NUL")`

### Steps
1. Replace `find_vanilla_files()` with a portable Lua directory walker using `lfs`
 (`require("lfs")`) if available, else a hardcoded list fallback:
 ```lua
 local function find_vanilla_files()
  local files = {}
  local ok, lfs = pcall(require, "lfs")
  if ok and lfs then
   local function walk(dir)
    for entry in lfs.dir(dir) do
     local p = dir .. "/" .. entry
     local mode = lfs.attributes(p, "mode")
     if mode == "directory" and entry ~= "." and entry ~= ".." then
      walk(p)
     elseif mode == "file" and entry:match("_vanilla%.lua$") then
      files[#files + 1] = p
     end
    end
   end
   walk("EaxRotations/classes")
  else
   -- Fallback: hardcode the known vanilla files (auto-generated list)
   -- [Kimi: run `find EaxRotations/classes -name "*_vanilla.lua"` and paste here]
  end
  return files
 end
 ```
2. If `lfs` is unavailable in the test runner, generate the fallback list by running
 `find EaxRotations/classes -name "*_vanilla.lua" | sort` and embedding the result.

### Validation
- `lua EaxRotations/tests/run_rotation_tests.lua` → 208/208
- Specifically `test_cross_expansion_spell_validation.lua` must PASS

### Risk
Very low. Test-only change.

---

## WORK ITEM 4 — Clean up stale `plans/` directory (Low value, Low effort, clarity)

### Problem
`plans/` mixes active plans with historical audit notes. ~20 items documented as "gaps"
are already fixed (Phases 1-5). New agents waste cycles re-investigating fixed issues.

### Verified already-fixed items (move to `plans/_archive/fixed-*.md`)
- Berserker Rage / Death Wish fear break (arms, fury)
- Druid powershifting (cat)
- Seal twisting (retribution)
- Frenzied Regen / Barkskin (bear)
- Feign Death / Bestial Wrath (hunter)
- Vanish / Evasion / Cloak (rogue)
- Ice Barrier (mage)
- Conflagrate / Incinerate (warlock destruction)
- Raw unit comparison crashes (cross-class sweep)
- Arms stance typo / scoping / mortal_strike bypass (Phase 1)
- `get_spell_id` / `_context.lowest` allocations (Phase 1)
- Duplicate `_settings_cache` (Phase 1)
- `filter_spell_ids_for_expansion` no-op (Phase 1)
- BM Hunter global leak (Phase 1)
- Enemy cache / immunity cache / `is_hostile_unit` (Phase 4)
- `safe()` pcall overhead (Phase 4)

### Steps
1. Create `plans/_archive/fixed-2026-06-29-batch.md` listing all the above with one-line
 "fixed in Phase X / commit Y" notes.
2. From each source plan in `plans/_archive/` that documents these, add a header line:
 `> STATUS: SUPERSEDED — see fixed-2026-06-29-batch.md`
3. Do NOT delete any plan files (preserve audit trail).
4. Update `plans/_active.md` to remove completed items.

### Validation
- No code changes → no test run needed
- `git status` should show only `plans/` additions/modifications

### Risk
Zero (documentation only).

---

## EXECUTION ORDER & GATES

1. **WORK ITEM 4 first** (plans cleanup) — no code risk, establishes clean baseline.
2. **WORK ITEM 1** (remove dead spell_damage logic) — highest clarity value.
3. **WORK ITEM 3** (portable test) — independent, safe.
4. **WORK ITEM 2** (static buffers) — last, requires call-site verification.

### Hard gate after EACH item
```bash
luac -p <edited files>
lua EaxRotations/tests/run_rotation_tests.lua # must be 208/208
lua EaxRotations/tests/run_leveling_tests.lua # must be 11/11
```
If ANY suite fails: `git checkout -- <file>` and re-investigate. Do NOT proceed to the
next item until green.

### Stop conditions (from AGENTS.md contract)
- If an item loops >2 attempts to get green tests: STOP. Write a note in
 `plans/kimi-hardening-blockers.md` describing the failure. Do not retry.
- One concern per commit. Commit after each green gate.

---

## WHAT NOT TO DO (anti-patterns from the false-positive report)

- ❌ Do NOT add `pcall` wrapping to `targeting_sylvanas.lua` / `stealth_helper` /
 `pet_heal` / `stopcast` — they are already nil-guarded. Mass pcall'ing would add
 overhead with no safety benefit.
- ❌ Do NOT "fix" `combat_forecast_gate_sylvanas.lua` `is_boss()` — it's a documented
 API and the code is correct.
- ❌ Do NOT add a Counterspell strategy to Arcane/Fire mage — it's wired via middleware
 (`middleware_sylvanas.lua:102`) and works for all 3 specs already.
- ❌ Do NOT expand the Hunter cliptracker — it delegates to a real 384-line
 `hunter_core_sylvanas.lua` with weave math; all 3 specs use `can_cast_steady()`.
- ❌ Do NOT wire `context.spell_damage` to `spell_helper:get_spell_damage()` — that API
 is imprecise tooltip parsing and could cause DoTs to miss refreshes. Removing the dead
 gate (Work Item 1) is safer.

---

## SUMMARY TABLE

| Item | Value | Effort | Risk | Files touched |
|------|-------|--------|------|---------------|
| 4: Plans cleanup | Clarity | 30 min | None | `plans/` only |
| 1: Remove dead spell_damage | Clarity | 1-2 hr | Low | 4 spec files |
| 3: Portable test | Portability | 30 min | Very low | 1 test file |
| 2: Static buffers | Perf (minor) | 1-2 hr | Low* | 3 shared files |

*Item 2 requires call-site retention verification before converting `out = {}` patterns.

---

## FINAL VERIFICATION (after all items)

```bash
git status --short --branch
git log --oneline -8
luac -p $(git diff --name-only HEAD~4..HEAD | grep '\.lua$')
lua EaxRotations/tests/run_rotation_tests.lua # 208/208
lua EaxRotations/tests/run_leveling_tests.lua # 11/11
```

All green = done. Commit each item separately with conventional format:
- `docs(plans): mark fixed items as superseded`
- `refactor(specs): remove dead spell_damage snapshot gate`
- `test(cross-expansion): portable vanilla file discovery`
- `perf(shared): static buffers for ttd/heal predictors`

---

*This plan reflects only verified findings. The codebase is in strong shape — this is
hardening, not repair.*
