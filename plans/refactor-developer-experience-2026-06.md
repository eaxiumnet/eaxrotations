# Implementation Plan: EaxRotations Optimization & Refactor for Sustainable Development

**Created:** 2026-06-19
**API Surface:** No new API usage — pure restructure of existing `api/`, `apidocs/`, and `EaxRotations/` code.
**Docs References:** `AGENTS.md` (327 lines), `EaxRotations/CLAUDE.md` (10KB, duplicate), `.agents/skills/*` (8 skills, 1,641 lines)
**Scope:** Architectural refactor + agent workflow consolidation. Read-only analysis complete.

---

## Overview

**The problem (evidence-based):** AI agents are running in loops because there is no single source of truth, no clear ownership boundaries, and no enforced "definition of done." Specifically:

1. **Scattered agent-instruction files for *our* code** (`AGENTS.md` + `EaxRotations/CLAUDE.md`) — agents read different ones, get different context, redo work. *(NOTE: `tbc-main/`, `_external_tbc_explore/`, `tbc_roblox/`, `ClassResearchTBC/`, `EaxESP/` are external **reference clones** on the GGL platform — untracked, not ours to refactor. Their `CLAUDE.md`/`AGENTS.md` are instructions for THEIR system and must be left untouched. `tbc-main`/`external` is the inspiration source, mined for ideas only.)*
2. **Scattered `plans/` dirs across multiple AI tools for *our* code** (`.omo/plans`, `.opencode/plans`, `EaxAutoQuester/plans`, `EaxRotations/plans`, top-level `plans/`) — every AI tool created its own scratch space; plans duplicate and contradict. *(The `plans/` inside `tbc-main/` and `_external_tbc_explore/` belong to the reference system — ignored.)*
3. **`core_sylvanas.lua` is 6,431 lines / 258 functions** in one god-file mixing ~15 unrelated domains (settings, units, items, equipment, casting, TTD, talent inference, spell resolution, cooldowns, diagnostics). Any change risks unrelated regressions.
4. **Repeated nil-guard commits** — `fix(subtlety): nil-guard...`, `fix(bear): nil-guard...`, `fix(resto): nil-guard...`, `fix(specs): add nil-guards...` show the same bug class fixed spec-by-spec because there is no shared safe-state accessor. Each new spec reintroduces it.
5. **~60% copy-paste spec boilerplate** — every spec re-implements the `NS = _G.EaxRotations` guard, `spell()` resolver helper, `ACTION = {}` table, state table, and threshold constants from scratch.
6. **No enforced completion gate** — `luac -p` + test suites exist but agents skip them, regressions appear later, agents loop back.

**The fix:** Three layers, executed in order:

- **Layer A — Single source of truth** for agent instructions and plans (kills the "which file do I read" loop).
- **Layer B — Architectural refactor** of `core_sylvanas.lua` into focused domain modules + a `spec_kit` that gives every spec the safe-state accessor and boilerplate it currently hand-rolls (kills the "fix same nil-guard in 14 files" loop).
- **Layer C — Enforced dev loop** via a single validation gate command + status tracking (kills the "regression surfaces next session" loop).

**Hard constraint:** Behavior must not change. This is a refactor. All 95 rotation + 11 leveling suites must stay green at every commit. Every commit is independently valid (`luac -p` + tests).

---

## API Integration

This plan reuses only already-adopted APIs. No new integration.

| Function | File | Purpose |
|----------|------|---------|
| `NS.get_setting`, `NS.set_setting` | `EaxRotations/core_sylvanas.lua` | Settings access (preserved) |
| `NS.time_now`, `NS.game_time_ms` | `EaxRotations/core_sylvanas.lua` | Time caching (preserved) |
| `NS.buff_up`, `NS.debuff_remains`, `NS.buff_points` | `EaxRotations/core_sylvanas.lua` | Aura access (preserved) |
| `NS.try_cast`, `NS.action_execute` | `EaxRotations/core_sylvanas.lua` | Cast path (preserved) |
| `izi.spell()`, `izi.me()` | `api/common/izi_sdk.lua` | Already adopted |
| `core.object_manager.*`, `core.spell_book.*` | `api/core.lua` | Already adopted |

---

## Files to Touch (summary — detail per task below)

| File | Change |
|------|--------|
| `AGENTS.md` | Becomes the **only** agent-instruction file for our code; absorbs unique content from `EaxRotations/CLAUDE.md` |
| `EaxRotations/CLAUDE.md` | Becomes single-line pointer to `../AGENTS.md` (reference-system `CLAUDE.md` files in `tbc-main/`/`_external_tbc_explore/` are NOT ours — untouched) |
| `plans/` (top-level) | Becomes the **only** active plans dir; others archived under `plans/_archive/<tool>/` |
| `EaxRotations/core_sylvanas.lua` | Split 6,431-line god-file into focused domain modules under `EaxRotations/core/` |
| `EaxRotations/core/*.lua` (new) | `settings.lua`, `units.lua`, `items.lua`, `casting.lua`, `cooldowns.lua`, `ttd.lua`, `talents.lua`, `diagnostics.lua` |
| `EaxRotations/core_sylvanas.lua` | Shrinks to ~400-line facade re-exporting the split modules (backward compatible) |
| `EaxRotations/shared/spec_kit_sylvanas.lua` (new) | Boilerplate elimination: `define_spec()`, `safe_state()`, nil-guarded state accessors |
| `EaxRotations/classes/**/*.lua` | One spec converted to `spec_kit` per phase as proof, then incremental migration |
| `EaxRotations/scripts/validate.cmd` (new) | Single gate command: `luac -p` + rotation tests + leveling tests + LSP |
| `.agents/skills/do/SKILL.md` | Enforce running `validate.cmd` before marking a task complete |

---

## Task List

### Phase 1: Single Source of Truth (kills the "which file" loop)

**Goal:** Every AI tool reads the same instructions and writes plans to the same place. Zero code-behavior change.

- [ ] **Task 1.1: Consolidate OUR agent-instruction files**
  - **Files:** `AGENTS.md` (expand), `EaxRotations/CLAUDE.md` (→ pointer)
  - **Scope guard:** Only `AGENTS.md` and `EaxRotations/CLAUDE.md` are ours. Do **NOT** touch `tbc-main/tbc-main/CLAUDE.md`, `_external_tbc_explore/CLAUDE.md`, `tbc_roblox/AGENTS.md`, or `ClassResearchTBC/AGENTS.md` — those belong to the external GGL reference system (untracked), mined for inspiration only.
  - **Change:**
    - `AGENTS.md` becomes canonical. Add a top section: "This is the only agent-instruction file for EaxRotations. If you are an AI agent, read this first."
    - `EaxRotations/CLAUDE.md` becomes a 1-line pointer: `→ See ../AGENTS.md` (kept, not deleted — some tools auto-load `CLAUDE.md`; a pointer prevents divergence).
  - **Acceptance:**
    - `EaxRotations/CLAUDE.md` is a single-line pointer.
    - `AGENTS.md` contains all rules currently in `EaxRotations/CLAUDE.md` (audit its 10KB for unique content; merge any rules not already in `AGENTS.md`).
    - `git status` shows ONLY `.md` files inside the repo root / `EaxRotations/` — reference-system dirs untouched.
    - No behavioral change to any Lua file.
  - **Verify:** `git diff --stat` shows only our `.md` files; reference dirs unchanged.

- [ ] **Task 1.2: Consolidate OUR plans into one active directory**
  - **Files:** `plans/` (canonical), `.omo/plans/`, `.opencode/plans/`, `EaxAutoQuester/plans/`, `EaxRotations/plans/`
  - **Scope guard:** Only consolidate plans dirs that belong to OUR code. Do **NOT** touch `tbc-main/tbc-main/docs/plans/` or `_external_tbc_explore/docs/plans/` — those belong to the external GGL reference system (untracked).
  - **Change:**
    - Create `plans/_archive/<tool>/` and move each of OUR tool's existing plans there (`.omo`, `.opencode`, `EaxAutoQuester`, `EaxRotations`) — preserved history, out of active sight.
    - Move `EaxRotations/plans/*.md` up to top-level `plans/` (they're the most current — `api-integration-2026-06.md`, this refactor plan, etc.). This very file moves too.
    - Add `plans/README.md`: "Active plans live here. Completed/abandoned plans move to `_archive/`. One active plan per effort. Reference-system plans (tbc-main/external) are out of scope — they live with the reference clone."
    - Add `plans/_active.md` index: a one-line-per-effort status table (effort, status, owner-skill).
  - **Acceptance:**
    - `find EaxRotations .omo .opencode EaxAutoQuester -type d -name plans` returns no active (non-archived) plans dirs for our code.
    - `plans/_active.md` lists current efforts with status.
    - `tbc-main/`, `_external_tbc_explore/` untouched.
  - **Verify:** `git status --short` shows only moves inside our dirs.

- [ ] **Task 1.3: Add "agent contract" section to `AGENTS.md`**
  - **Files:** `AGENTS.md`
  - **Change:** Add a short, mandatory section near the top:
    ```
    ## Agent Contract (mandatory for all AI tools)
    1. Read THIS file first. Ignore CLAUDE.md/cursorrules content beyond the pointer.
    2. All plans live in plans/. Create one plan per effort. Check plans/_active.md before starting.
    3. Never edit more than one concern per commit.
    4. Before marking any task complete: run scripts/validate.cmd. It must exit 0.
    5. If a task loops >2 attempts, STOP. Write a debugging plan in plans/ instead of retrying.
    ```
  - **Acceptance:** Section present and unambiguous. Existing `.agents/skills/do/SKILL.md` references it.
  - **Verify:** manual read; no Lua change.

---

### Phase 2: Split `core_sylvanas.lua` (kills the "god-file regression" loop)

**Goal:** Decompose the 6,431-line file into focused modules behind a backward-compatible facade. No external caller changes. Each commit is independently green.

**Strategy:** Extract one domain at a time, lowest-risk first. After each extraction, `core_sylvanas.lua` `require()`s the new module and re-exports its functions on `NS.*` so every existing caller keeps working unchanged.

- [ ] **Task 2.1: Create `EaxRotations/core/` package skeleton**
  - **Files:** `EaxRotations/core/init.lua` (new)
  - **Change:** Package loader that `require`s each domain module and merges into a table. Pattern matches existing `shared/` pcall-load style.
  - **Acceptance:** `require("EaxRotations/core")` returns a table; loading it changes nothing else.
  - **Verify:** `luac -p EaxRotations/core/init.lua`; full test suite green.

- [ ] **Task 2.2: Extract `settings` domain (lines ~245, 1158–1280)**
  - **Files:** `EaxRotations/core/settings.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move `NS.settings`, `NS.get_setting`, `NS.set_setting`, `NS.get_setting_cached`, `NS.setting`, `NS.setting_number`, `NS.setting_bool`, `NS.get_any_setting`, `NS.refresh_settings_cache`, `NS.register_izi_buff_events` into `core/settings.lua`. `core_sylvanas.lua` keeps `NS.get_setting = core_settings.get_setting` re-exports.
  - **Acceptance:** All `NS.get_setting(...)` callers unchanged. `core_sylvanas.lua` shrinks by ~130 lines.
  - **Verify:** `luac -p` on both files; `lua EaxRotations/tests/run_rotation_tests.lua` green.

- [ ] **Task 2.3: Extract `units` domain (player/pet/party/target/focus)**
  - **Files:** `EaxRotations/core/units.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move `NS.GetPlayer`, `NS.GetPet`, `NS.has_pet`, `NS.get_pet_hp`, `NS.GetTarget`, `NS.GetFocus`, `NS.GetPartyMembers`, `NS.is_hostile_unit`, `NS.is_in_party`, `NS.unit_alive`, `NS.unit_health_pct`, `NS.same_unit`, `NS.not_same_unit`, `NS.safe_field`.
  - **Acceptance:** Callers unchanged. `main_sylvanas.lua` continues to cache `NS.GetPlayer` etc. at load.
  - **Verify:** `luac -p`; full rotation suite.

- [ ] **Task 2.4: Extract `items` + `equipment` domain**
  - **Files:** `EaxRotations/core/items.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move `NS.EQUIPMENT_SLOTS`, `NS.get_equipped_item_id`, `NS.get_equipped_item_ids`, `NS.is_item_equipped`, `NS.is_item_ready`, `NS.register_item_manual_cooldown`, `NS.use_item_by_id`, `NS.has_item`, `NS.count_equipped_set`, `NS.has_set_bonus`.
  - **Acceptance:** All item callers unchanged.
  - **Verify:** `luac -p`; full rotation suite (esp. trinket/healing specs).

- [ ] **Task 2.5: Extract `cooldowns` domain**
  - **Files:** `EaxRotations/core/cooldowns.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move `NS.cooldown_registry`, `NS.register_cooldown`, `NS.unregister_cooldown`, `NS.get_cooldown_suggestions`, `NS.get_best_offensive_cooldown`, `NS.get_best_defensive_cooldown`, `NS.clear_cooldown_registry`.
  - **Acceptance:** Cooldown consumers (burst_logic, trinket_manager) unchanged.
  - **Verify:** `luac -p`; full rotation suite.

- [ ] **Task 2.6: Extract `ttd` + `talents` domain**
  - **Files:** `EaxRotations/core/ttd.lua`, `EaxRotations/core/talents.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move TTD fallback chain helpers and talent-build detection (`_get_talent_info`, `_cached_talent_build`).
  - **Acceptance:** `context.ttd`, `context.talent_build` unchanged.
  - **Verify:** `luac -p`; `test_talent_context.lua`, `test_threat_pct_wired_2026_06.lua` pass.

- [ ] **Task 2.7: Extract `diagnostics` domain**
  - **Files:** `EaxRotations/core/diagnostics.lua` (new), `EaxRotations/core_sylvanas.lua`
  - **Change:** Move `NS.log`, `NS.log_warning`, `NS.log_error`, `NS.is_api_health_broken`, `NS.reset_api_health`, `NS.dump_class_spells`.
  - **Acceptance:** All logging callers unchanged.
  - **Verify:** `luac -p`; full rotation suite.

- [ ] **Task 2.8: Final facade + size audit**
  - **Files:** `EaxRotations/core_sylvanas.lua`
  - **Change:** Confirm `core_sylvanas.lua` is now a thin facade (~400–600 lines): expansion helpers, `NS` namespace init, casting core (`NS.try_cast`, `NS.action_execute`, `NS.spell_action`, `NS.spell_ready`), and re-exports of the extracted modules. Do NOT split casting in this phase (highest risk, leave for Phase 4 if needed).
  - **Acceptance:**
    - `wc -l EaxRotations/core_sylvanas.lua` < 1,500 lines.
    - No caller anywhere had to change.
    - All 95 + 11 suites pass.
  - **Verify:** `scripts/validate.cmd` (created in Phase 3, or inline equivalent now).

---

### Phase 3: Enforced Dev Loop (kills the "regression next session" loop)

**Goal:** One command tells an agent definitively whether a change is done. No more silent skips.

- [ ] **Task 3.1: Create `scripts/validate.cmd` single gate**
  - **Files:** `EaxRotations/scripts/validate.cmd` (new), or `scripts/validate.cmd` at repo root
  - **Change:** A `cmd.exe` batch script that runs, in order, and exits non-zero on the first failure:
    1. `luac -p` on every `.lua` file staged/modified (`git diff --name-only --cached` + unstaged, filter `*.lua`).
    2. `lua EaxRotations/tests/run_rotation_tests.lua`
    3. `lua EaxRotations/tests/run_leveling_tests.lua`
    4. Print `OK <counts>` on success, or the first failing command's output on failure.
  - **Acceptance:**
    - Running it on a clean tree prints `OK` and exits 0.
    - Introducing a syntax error in any spec → exits non-zero with the `luac` error.
    - Introducing a test failure → exits non-zero with the failing test.
  - **Verify:** run on clean tree (pass), run after deliberate break (fail), fix, re-run (pass).

- [ ] **Task 3.2: Wire `validate.cmd` into the `do` skill**
  - **Files:** `.agents/skills/do/SKILL.md`
  - **Change:** Make the final step mandatory and explicit: "Before marking the task `- [x]`, run `scripts\validate.cmd`. If non-zero, the task is NOT complete — fix or revert."
  - **Acceptance:** Skill text unambiguous; no path where a task is marked done without validation.
  - **Verify:** manual read.

- [ ] **Task 3.3: Add `plans/_active.md` enforcement**
  - **Files:** `plans/_active.md`
  - **Change:** Every active effort has a row: `| <slug> | in-progress | <next-task> |`. The `plan` skill creates a row on plan creation; the `do` skill updates status; completion moves the plan to `_archive/`.
  - **Acceptance:** At any time, `plans/_active.md` answers "what is being worked on right now and what's next."
  - **Verify:** manual read; reflects this plan.

---

### Phase 4: `spec_kit` — eliminate boilerplate + nil-guard class of bugs

**Goal:** New specs start from a template that bakes in the nil-guards and resolver logic, so the repeated "fix(spec): nil-guard..." commits stop recurring.

**This is the highest-value-but-highest-risk phase.** Approach: build the kit, prove it on ONE spec end-to-end (including tests), then offer incremental migration of the rest (do NOT big-bang all 29 specs in this plan).

- [ ] **Task 4.1: Build `spec_kit` module**
  - **Files:** `EaxRotations/shared/spec_kit_sylvanas.lua` (new), `EaxRotations/tests/test_spec_kit.lua` (new)
  - **API Used:** `NS.get_setting`, `NS.buff_up`, `NS.debuff_remains`, `izi.spell`, `NS.spell_action`
  - **Change:** Provide:
    - `spec_kit.ns()` — returns `NS` or nil (one place for the `_G.EaxRotations` guard).
    - `spec_kit.define_action(spell_field, rank_ids, label)` — the `spell()` helper every spec currently copy-pastes.
    - `spec_kit.safe_state(raw_state, schema)` — returns a proxy/metatable where `state.rage` returns `(raw.rage or 0)` automatically per AGENTS.md Pattern 14 defaults. This is the fix for the recurring nil-guard bug: **the default is safe by construction.**
    - `spec_kit.setting(context, key, fallback)` — the Pattern 8 helper, centralized.
  - **Acceptance:**
    - `test_spec_kit.lua` proves: `safe_state({}).rage == 0`, `safe_state({hp=nil}).hp == 100`, `safe_state({enemy_count=nil}).enemy_count == 0`.
    - `define_action` returns the same value the existing copy-pasted `spell()` does for the same inputs.
    - `luac -p` clean.
  - **Verify:** `lua EaxRotations/tests/test_spec_kit.lua` passes; full suite still green (kit is additive).

- [ ] **Task 4.2: Prove `spec_kit` on one spec — `warrior/arms_sylvanas.lua`**
  - **Files:** `EaxRotations/classes/warrior/arms_sylvanas.lua`, `EaxRotations/tests/test_arms_custom_matches.lua`
  - **Change:** Refactor `arms_sylvanas.lua` to use `spec_kit.define_action` and `spec_kit.safe_state`. Remove the local `spell()` helper and the hand-rolled state defaults. Keep ALL match-function logic identical.
  - **Acceptance:**
    - `test_arms_custom_matches.lua`, `test_arms_hamstring_tactician.lua`, `test_arms_rage_gating.lua`, `test_arms_healthstone.lua` all pass unchanged.
    - `arms_sylvanas.lua` shrinks (boilerplate removed).
    - Behavior identical (this is a refactor, not a logic change).
  - **Verify:** `scripts/validate.cmd` exits 0; specifically the 4 arms tests pass.

- [ ] **Task 4.3: Document the migration path (no big-bang)**
  - **Files:** `AGENTS.md` (add Pattern 15: `spec_kit`), `plans/spec_kit-migration.md` (new)
  - **Change:**
    - Add AGENTS.md Pattern 15 documenting `spec_kit.define_action` / `safe_state` as the preferred way for new specs and any spec already being edited.
    - Create `plans/spec_kit-migration.md` listing all 29 specs with a checkbox each. Migration is opportunistic: convert a spec only when you're already editing it. Do NOT schedule a dedicated "convert all specs" effort (that's what causes loops).
  - **Acceptance:** Pattern 15 present; migration plan exists with 0/29 checked.
  - **Verify:** manual read.

---

### Phase 5: Validation & Documentation

- [ ] **Task 5.1: Full regression**
  - **Verify:** `scripts\validate.cmd` exits 0 on clean tree. All 95 rotation + 11 leveling suites pass. `luac -p` clean on every modified/new file. LSP zero errors on changed files.

- [ ] **Task 5.2: Update `AGENTS.md` directory map**
  - **Files:** `AGENTS.md`
  - **Change:** Reflect new `EaxRotations/core/` directory, `EaxRotations/shared/spec_kit_sylvanas.lua`, `scripts/validate.cmd`, `plans/` consolidation. Remove stale references.
  - **Acceptance:** Directory map matches reality.
  - **Verify:** manual read; cross-check `ls EaxRotations/core/`.

- [ ] **Task 5.3: Retrospective note in `plans/_active.md`**
  - **Files:** `plans/_active.md`
  - **Change:** Mark this effort complete; record what the loop-root-causes were and which layer addressed each, so future agents inherit the lesson.
  - **Acceptance:** Row shows `complete`.
  - **Verify:** manual read.

---

## Why This Stops the Loops (root-cause → fix map)

| Observed loop symptom | Root cause | Fix in this plan |
|-----------------------|-----------|------------------|
| Agent re-reads different instruction files, gets conflicting context | 2 scattered files for our code (`AGENTS.md` + `EaxRotations/CLAUDE.md`) | Phase 1.1 — single canonical file + pointer |
| Two agents plan the same effort independently | 5 separate `plans/` dirs for our code (`.omo`, `.opencode`, `EaxAutoQuester`, `EaxRotations`, top-level) | Phase 1.2 — one active `plans/` + `_active.md` index |
| Agent edits `core_sylvanas.lua`, breaks unrelated spec | 6,431-line god-file | Phase 2 — split into domain modules |
| Same nil-guard bug fixed in 14+ commits across specs | No safe-by-default state accessor | Phase 4.1 — `spec_kit.safe_state` |
| Regression surfaces sessions later, agent loops back | No enforced completion gate | Phase 3.1 — `scripts/validate.cmd` enforced by `do` skill |
| Agent retries a failing task repeatedly | No "stop and plan" rule | Phase 1.3 — Agent Contract rule 5 |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Splitting `core_sylvanas.lua` breaks a caller that caches `NS.X` at load | Silent nil at runtime | Phase 2 extracts one domain per commit; `main_sylvanas.lua`'s load-time caching (lines 63–92) is re-verified after each extraction; full test suite gates every commit |
| `spec_kit.safe_state` metatable has different semantics than raw table access in some hot path | Subtle behavior change | Prove on ONE spec (arms) with its full test battery before any migration; metatable is opt-in |
| `luac -p` only checks syntax, not the test-suite regressions | False-green gate | `validate.cmd` runs BOTH `luac -p` AND the test suites — Phase 3.1 step order |
| Consolidating `CLAUDE.md` to pointers breaks a tool that requires non-empty file | Tool refuses to load | Pointer file is non-empty (1 line), so loaders still find content; verified per-tool if any complains |
| Big-bang spec migration reintroduces loops | Repeats the original problem | Phase 4.3 explicitly forbids big-bang; opportunistic migration only |

---

## Execution Order

```
Phase 1 (no code change — safe to do first):
  ├─ 1.1 Consolidate agent-instruction files
  ├─ 1.2 Consolidate plans/
  └─ 1.3 Agent Contract in AGENTS.md

Phase 3 (enables safe Phase 2 — build the gate before using it):
  └─ 3.1 Create scripts/validate.cmd   ← do this BEFORE Phase 2

Phase 2 (one commit per task, gate after each):
  ├─ 2.1 core/ package skeleton
  ├─ 2.2 settings
  ├─ 2.3 units
  ├─ 2.4 items/equipment
  ├─ 2.5 cooldowns
  ├─ 2.6 ttd/talents
  ├─ 2.7 diagnostics
  └─ 2.8 facade + size audit

Phase 3 (remainder):
  ├─ 3.2 Wire validate into do skill
  └─ 3.3 plans/_active.md enforcement

Phase 4 (highest value, prove on one spec):
  ├─ 4.1 spec_kit module + tests
  ├─ 4.2 Prove on arms_sylvanas.lua
  └─ 4.3 Document migration path (no big-bang)

Phase 5:
  ├─ 5.1 Full regression
  ├─ 5.2 Update AGENTS.md directory map
  └─ 5.3 Retrospective note
```

**Critical ordering rule:** Phase 3.1 (`validate.cmd`) MUST land before Phase 2, so every Phase 2 extraction commit is gated by the single command. This is what makes the refactor safe to do incrementally without loops.

---

## Files Summary

### New Files
- `EaxRotations/core/init.lua`
- `EaxRotations/core/settings.lua`
- `EaxRotations/core/units.lua`
- `EaxRotations/core/items.lua`
- `EaxRotations/core/cooldowns.lua`
- `EaxRotations/core/ttd.lua`
- `EaxRotations/core/talents.lua`
- `EaxRotations/core/diagnostics.lua`
- `EaxRotations/shared/spec_kit_sylvanas.lua`
- `EaxRotations/tests/test_spec_kit.lua`
- `scripts/validate.cmd` (or `EaxRotations/scripts/validate.cmd`)
- `plans/README.md`
- `plans/_active.md`
- `plans/_archive/` (directory)

### Modified Files
- `AGENTS.md` (canonical, expanded with Agent Contract + Pattern 15 + new dir map)
- `EaxRotations/CLAUDE.md` → single-line pointer (reference-system `CLAUDE.md`s untouched)
- `EaxRotations/core_sylvanas.lua` (shrinks from 6,431 → ~500 lines, becomes facade)
- `EaxRotations/classes/warrior/arms_sylvanas.lua` (proves `spec_kit`)
- `.agents/skills/do/SKILL.md` (enforce `validate.cmd`)

### Moved (archived) — OUR code only
- `.omo/plans/*`, `.opencode/plans/*`, `EaxAutoQuester/plans/*`, `EaxRotations/plans/*` → `plans/_archive/<tool>/`
- Reference-system `tbc-main/`, `_external_tbc_explore/`, `tbc_roblox/`, `ClassResearchTBC/`, `EaxESP/` are **untracked** and out of scope.

---

*Plan created via `/skill:plan`. Execute incrementally with `/skill:do`, one task per commit, gated by `scripts\validate.cmd`.*
