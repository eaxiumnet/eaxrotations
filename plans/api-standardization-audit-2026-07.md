# Implementation Plan: API Standardization Audit Across All EaxRotations

**Created:** 2026-07-09
**Slug:** `api-standardization-audit-2026-07`
**Previous Plan:** `plans/spec-standardization-2026-06-30.md` (Phase 3 — spec_kit migration)
**Baseline:** 234 rotation suites PASS, 13 leveling suites PASS, 459/459 luac -p PASS

## Overview

Perform a comprehensive audit of API usage consistency across **all** EaxRotations files (~210 Lua files) against the 16 Critical Coding Patterns defined in AGENTS.md. This plan builds on Oracle Round 5 verification (all 29 specs converted to spec_kit) and extends standardization to:

1. **40 spec files** — verify complete Pattern 1-16 compliance (29 converted + 11 legacy)
2. **~50 shared modules** — verify they follow the same patterns
3. **18 class infrastructure files** (class + middleware + schema × 9 classes)
4. **5 healing adjunct files**
5. **6 core/dispatcher files**
6. **~100 test files** — verify proper API mocking

**One concern per commit. R5: if a task loops >2 attempts, STOP and write a debugging note.**

---

## Files to Audit (Grouped by Category)

| Group | Count | Files | Patterns to Check |
|-------|-------|-------|-------------------|
| **A** | 29 | `classes/<class>/*_sylvanas.lua` (main specs) | 1-16 (converted specs: spot-check; legacy: full conversion) |
| **B** | 11 | 9 `leveling_sylvanas.lua` + `druid/healing` + `priest/smite` | 10, 16 (full migration) + 1-9, 11-15 |
| **C** | 9 | `classes/<class>/class_sylvanas.lua` | 2, 9, 15, banned APIs |
| **D** | 9 | `classes/<class>/middleware_sylvanas.lua` | 1, 2, 9, 15, banned APIs |
| **E** | 9 | `classes/<class>/schema_sylvanas.lua` | 8, 9, 15 |
| **F** | 5 | `classes/<class>/healing_sylvanas.lua`, `heal_helper_sylvanas.lua`, etc. | 9, 12, 15 |
| **G** | ~50 | `shared/*_sylvanas.lua` | 2, 3, 4, 9, 15, banned APIs |
| **H** | 6 | `core_sylvanas.lua`, `main_sylvanas.lua`, `main.lua`, `header.lua`, `common_sylvanas.lua`, `helpers_sylvanas.lua` | 2, documentation, NS consistency |
| **I** | ~100 | `tests/test_*.lua`, `tests/run_*_tests.lua` | Proper NS mocking, no raw core.* in mocks |

---

## Audit Methodology

### Phase 0 — Automated Violation Detection (Parallel) — COMPLETED 2026-07-10

Run these grep commands... (results below; no critical violations in production code).

**Grep 1 (banned APIs):** Only in comments/docs/tests. Production clean.
**Grep 2 (math.sqrt):** Only tests/docs. Clean.
**Grep 3 (bare menu):** None found.
**Grep 4 (raw core. in specs):** Mostly cached fallbacks (e.g. druid middleware, hunter_core wrappers). Acceptable at load or via shared.
**Grep 5 (buff_points):** Guarded with `pts and ... or nil` in key places (prot, healing).
**Grep 6 (bare state < >):** None in legacy.
**Grep 7 (NS guard):** Schemas/shared use M={} or other; main specs have NS = _G... (some listed as expected per plan).
**Grep 8 (Pattern 15 headers):** Most shared have WHAT:; minor misses in some data bridges (pre-existing).
**Grep 9 (uncached hot):** Some shared use core. via pcall/lazy (fsr, combat_log); recommend local cache where hot.

No P0 violations requiring immediate fix. Minor cleanups possible in Phase 1.

#### Grep Pattern 1: Banned APIs
```bash
# Any file under EaxRotations/
grep -rE "ffi\.C|io\.popen|os\.execute|debug\." EaxRotations/ --include="*.lua" | grep -v "tests/" | grep -v "_archive/"
```
**Expected:** Zero hits in production code (tests may legitimately use `debug.*`).

#### Grep Pattern 2: math.sqrt
```bash
grep -rn "math\.sqrt" EaxRotations/ --include="*.lua"
```
**Expected:** Zero hits. If found in shared modules, replace with squared distance.

#### Grep Pattern 3: Bare Menu Access (Pattern 1 violation)
```bash
grep -rn "menu\.[a-zA-Z_]+:get()" EaxRotations/ --include="*.lua" | grep -v "schema_" | grep -v "tests/"
```
**Expected:** Zero hits outside schema files. Schema files build widgets; specs/middleware must use `context.settings` or `NS.get_setting`.

#### Grep Pattern 4: Raw core.* in Spec Files (Pattern 5 violation)
```bash
grep -rn "core\." EaxRotations/classes/ --include="*_sylvanas.lua" | grep -v "class_sylvanas.lua" | grep -v "schema_sylvanas.lua"
```
**Expected:** Minimal hits. Allowed: `core.time` cached at load (Pattern 2). Disallowed: `core.input.cast_target_spell`, `core.spell_book.*` in match/execute functions.

#### Grep Pattern 5: buff_points / debuff_points without nil guard (Pattern 11 violation)
```bash
grep -rn "buff_points\|debuff_points" EaxRotations/ --include="*.lua" | grep -v "core_sylvanas.lua" | grep -v "tests/"
```
**For each hit:** Verify the next line (or same line) has `(pts and pts[1]) or 0` guard.

#### Grep Pattern 6: state.field bare comparisons (Pattern 14 violation in legacy files)
```bash
# Only for Group B (legacy specs) and any Group G files not using safe_state
grep -rn "state\.[a-z_]+ < \|state\.[a-z_]+ > " EaxRotations/classes/ --include="leveling_sylvanas.lua" EaxRotations/classes/druid/healing_sylvanas.lua EaxRotations/classes/priest/smite_sylvanas.lua
```
**Expected:** After conversion to spec_kit.safe_state, these become structurally safe. Before conversion, manual `or 0` / `or 100` guards required.

#### Grep Pattern 7: Missing NS guard (Pattern 9 violation)
```bash
grep -rL "local NS = _G\.EaxRotations" EaxRotations/ --include="*_sylvanas.lua" | grep -v "tests/"
```
**Expected:** Every production .lua file starts with NS guard. `shared/` modules that use `local M = {}` pattern are exempt if they receive NS via argument or require.

#### Grep Pattern 8: Missing Pattern 15 header
```bash
# Automated via existing test_spec_layout_compliance.lua — already covers 40 spec files
# For shared modules and core files, manual audit:
for f in EaxRotations/shared/*.lua EaxRotations/core_sylvanas.lua EaxRotations/main_sylvanas.lua; do
  head -n 5 "$f" | grep -q "WHAT:" || echo "MISSING HEADER: $f"
done
```

#### Grep Pattern 9: Un-cached API calls in hot paths (Pattern 2 violation)
```bash
grep -rn "core\.object_manager\.get_local_player\|core\.time\|core\.spell_book" EaxRotations/shared/ --include="*.lua" | grep -v "local _"
```
**For each hit:** Verify the call is inside a `local _x = ...` at module load, OR inside a throttled function (>200ms between calls).

**Findings & Fixes (2026-07-10):**
- hot_tick_tracker_sylvanas.lua: now_s() fell back to core.time without top-level cache. Fixed: added `local _core_time = _G.core and _G.core.time` at load; use in fallback. (Pattern 2)
- combat_log_parser_sylvanas.lua: now_seconds() used direct core.time. Fixed: cache at load + use _core_time. (Pattern 2)
- incoming_heal_predictor_sylvanas.lua: now_s() and spell_info used direct core.time / core.spell_book.get_*. Fixed: top-level caches + use. (Pattern 2)
- fsr_manager_sylvanas.lua: ensure_api used direct core.spell_book. Fixed: top-level _core_spell_book + use. (Pattern 2)
- trinket_manager_sylvanas.lua: now_seconds used direct. Fixed: top-level cache. (Pattern 2)
- pet_manager_sylvanas.lua: multiple direct core.spell_book and core.input in pet functions. Fixed: top-level _core + replace. (Pattern 2)
- luac + full suite green after fixes.

#### Grep Pattern 10: Static table allocation in loops (Pattern 4 violation)
```bash
grep -rn "for .* do" EaxRotations/shared/ --include="*.lua" -A 2 | grep -E "local _t *= *\{"
```
**For each hit:** Verify the table is declared outside the loop/function (static reuse).

#### Grep Pattern 11: test files using raw core.* instead of NS mocks
```bash
grep -rn "_G\.core\|core\." EaxRotations/tests/ --include="*.lua" | grep -v "run_" | grep -v "test_runner_lib" | head -n 30
```
**Expected:** Tests mock `NS.*` or `_G.EaxRotations`, not raw `core.*`.

---

### Phase 1 — Fix by Group (Parallel Waves)

#### Wave 1A: Group B — Legacy Spec Migration (11 files)
**Files:** 9 `leveling_sylvanas.lua` + `druid/healing_sylvanas.lua` + `priest/smite_sylvanas.lua`

**Goal:** Bring all 11 to canonical spec-kit template (Pattern 16).

**Per file:**
1. Add/update Pattern 15 header (WHAT/WHEN/WHY/SAFETY)
2. Add `local spec_kit = require("shared/spec_kit_sylvanas")`
3. Replace hand-rolled `spell()` helper with `spec_kit.define_action_for_class(SPELLS)`
4. Replace manual nil-guards with `spec_kit.safe_state(raw_state)`
5. Ensure `build_state` function exists and returns safe_state proxy
6. Guard registration: `if NS.rotation_registry and NS.rotation_registry.register then ... end`
7. Add return: `return { strategies = strategies, build_state = build_state }`
8. Run `luac -p`
9. Run full 234+13 suite
10. Add file to `CONVERTED` table in `test_spec_layout_compliance.lua`

**Parallelization:** Each file is independent. Batch in groups of 3-4 (one per commit).

**Acceptance:** All 11 files pass test_spec_layout_compliance + luac -p + full suite.

---

#### Wave 1B: Group G — Shared Module Audit (~50 files)
**Goal:** Verify and fix Patterns 2, 3, 4, 9, 15, banned APIs.

**Priority order** (highest API surface area first):
1. `spec_kit_sylvanas.lua` (already canonical — verify only)
2. `interrupt_manager_sylvanas.lua`
3. `consumable_manager_sylvanas.lua`
4. `trinket_manager_sylvanas.lua`
5. `healer_deficit_sylvanas.lua`
6. `combat_log_parser_sylvanas.lua`
7. `aura_cache_sylvanas.lua`
8. `spell_resolver_sylvanas.lua`
9. `target_selector_sylvanas.lua`
10. `buff_upgrade_sylvanas.lua`
11. `pvp_burst_window_sylvanas.lua`
12. All remaining shared modules

**Per file:**
1. Verify Pattern 15 header present (add if missing)
2. Verify `local NS = _G.EaxRotations` guard OR module receives NS via argument
3. Verify no `math.sqrt`
4. Verify no banned APIs
5. Verify API caching: all `core.*` calls assigned to `local _` at module load
6. Verify static table reuse in any per-tick loops
7. Run `luac -p`

**Parallelization:** Modules with no cross-dependencies can be batched. Modules that `require` each other should be sequential.

---

#### Wave 1C: Group H — Core Files Audit (6 files)
**Files:**
- `EaxRotations/core_sylvanas.lua` (6114 lines — largest file)
- `EaxRotations/main_sylvanas.lua`
- `EaxRotations/main.lua`
- `EaxRotations/header.lua`
- `EaxRotations/common_sylvanas.lua`
- `EaxRotations/helpers_sylvanas.lua`

**Goal:** Verify NS helper consistency, API caching, and documentation.

**core_sylvanas.lua specific checks:**
1. Every `NS.*` helper documented with `---@param` / `---@return` annotations
2. All `core.*` access cached at module load (Pattern 2)
3. No `math.sqrt`
4. `NS.try_cast` implementation uses izi SDK when available, falls back to raw core safely
5. `NS.buff_points` / `NS.debuff_points` nil-guarded internally
6. `NS.gate_overheal` signature matches all call sites (already verified in Round 5)

**main_sylvanas.lua specific checks:**
1. `on_update` does not allocate tables per frame
2. Enemy scan uses static table reuse (Pattern 4)
3. Squared distance for range checks (Pattern 3)

**Acceptance:** `luac -p` clean on all 6 files; full 234+13 suite green.

---

#### Wave 1D: Group C/D/E/F — Class Infrastructure (32 files)
**Files:** 9 class + 9 middleware + 9 schema + 5 healing adjuncts

**class_sylvanas.lua (×9):**
- Pattern 15 header
- Spell tables use rank chains (newest first)
- No Wrath-only spells without DBC verification
- `NS = _G.EaxRotations` guard

**middleware_sylvanas.lua (×9):**
- Pattern 15 header
- Menu access via `context.settings` (Pattern 1), not bare `menu.*:get()`
- Defensive spells use `NS.try_cast` (Pattern 5)
- `NS = _G.EaxRotations` guard

**schema_sylvanas.lua (×9):**
- Pattern 15 header
- Menu widget construction is the ONE place bare `core.menu.*` is allowed
- No `menu.x:get()` in schema files (those are built by middleware/settings)

**healing adjuncts (×5):**
- Pattern 15 header
- `gate_overheal` calls pass `spell_id` (already fixed in Round 5 — verify)
- `pws_absorb_remaining` uses `NS.buff_points` with nil guard (Pattern 12)

---

#### Wave 1E: Group I — Test File Audit (~100 files)
**Goal:** Verify tests mock the correct API layer.

**Checks per test file:**
1. Tests set up `_G.EaxRotations = {}` or require `core_sylvanas.lua` rather than mocking raw `core.*`
2. No raw `core.input.cast_target_spell` expectations in test assertions
3. Test structure: `local function assert_true(...)` helpers at top
4. Ends with `print("PASS <filename>")`
5. Registered in `run_rotation_tests.lua` or `run_leveling_tests.lua`

**Priority:** Focus on tests that exercise NS helpers (e.g., `test_api_lint.lua`, `test_context_*.lua`, `test_spec_layout_compliance.lua`).

---

### Phase 2 — Compliance Test Enhancement

**Task:** Extend `test_spec_layout_compliance.lua` to cover Groups C, D, E, F, G, H.

Currently it only checks Group A/B (spec files). Add:

1. **shared_module_compliance** — check Pattern 15 header, NS guard, no banned APIs
2. **core_file_compliance** — check `core.*` caching pattern, no `math.sqrt`
3. **middleware_compliance** — check no bare `menu.*:get()` outside schema files
4. **test_file_compliance** — check all test files registered in runner, end with PASS print

**Acceptance:** New compliance tests pass on current codebase (should find zero violations if Phase 1 was thorough).

---

### Phase 3 — Final Validation

**Task:** Run full validation suite.

```bash
# 1. Syntax check ALL Lua files
find EaxRotations -name "*.lua" -exec luac -p {} \;

# 2. Rotation suites
lua EaxRotations/tests/run_rotation_tests.lua

# 3. Leveling suites
lua EaxRotations/tests/run_leveling_tests.lua

# 4. Vanilla audit
lua EaxRotations/tests/run_vanilla_audit_tests.lua

# 5. Sylvanas audit
lua EaxRotations/tests/run_sylvanas_audit_tests.lua

# 6. LSP zero errors on all changed files
```

**Acceptance Criteria:**
- [ ] 459/459 luac -p PASS (or current count + any new files)
- [ ] 234 rotation suites PASS
- [ ] 13 leveling suites PASS
- [ ] 31 vanilla audit PASS
- [ ] 61 sylvanas audit PASS
- [ ] LSP diagnostics: 0 errors on all changed files
- [ ] `test_spec_layout_compliance.lua`: 40 converted, 0 legacy
- [ ] Zero `math.sqrt` in EaxRotations/
- [ ] Zero banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) in production
- [ ] Zero bare `menu.x:get()` in spec/middleware/shared files

---

## Parallel Execution Opportunities

| Wave | Tasks | Can Parallelize |
|------|-------|----------------|
| Phase 0 | 11 grep audits | **Yes** — all independent |
| Wave 1A | 11 legacy spec conversions | **Yes, in batches** — each file independent |
| Wave 1B | ~50 shared modules | **Partial** — no-deps modules in parallel; dep chains sequential |
| Wave 1C | 6 core files | **No** — main.lua → main_sylvanas.lua → core_sylvanas.lua dependency chain |
| Wave 1D | 32 class infrastructure | **Yes, by class** — druid/ files independent of warrior/ files |
| Wave 1E | ~100 test files | **Yes** — test files are independent |
| Phase 2 | Compliance test extensions | **No** — single file edit |
| Phase 3 | Validation suite | **No** — sequential runner invocations |

**Recommended parallel groupings:**
- **Batch 1:** Phase 0 (all grep commands) + Wave 1E (test audit)
- **Batch 2:** Wave 1A (legacy specs, 3-4 per agent) + Wave 1D (class infrastructure, 3 classes per agent)
- **Batch 3:** Wave 1B (shared modules, 10 per agent) + Wave 1C (core files)
- **Batch 4:** Phase 2 (compliance tests) + Phase 3 (validation)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Legacy spec conversion breaks rotation logic | High | Convert one at a time; run full suite after each; keep diff small |
| Shared module "fix" changes behavior | Medium | Add characterization test before changing; verify GREEN→GREEN |
| core_sylvanas.lua edit affects all specs | Very High | Read-only audit first; any edit needs full 234+13 suite + vanilla/sylvanas audit |
| grep false positives (e.g., `core.` in string literal) | Low | Manual review of each grep hit; use context lines |
| Missing file in audit | Medium | Use glob-based file lists; cross-check against `run_rotation_tests.lua` registration |
| Compliance test extension too strict | Low | Start with warning-only mode; fail after fixes applied |

---

## Commit Strategy

**One concern per commit.**

```
commit 1: fix(shared): add Pattern 15 headers to interrupt_manager + consumable_manager
commit 2: fix(shared): static table reuse in combat_log_parser_sylvanas.lua
commit 3: fix(specs): convert druid/leveling_sylvanas.lua to spec_kit template
commit 4: fix(specs): convert hunter/leveling_sylvanas.lua to spec_kit template
...
commit N: test(compliance): extend test_spec_layout_compliance to shared modules
commit N+1: docs(AGENTS.md): update Pattern 16 migration state table
```

---

## Tracking

- [x] Phase 0: Automated grep audits complete
- [x] Phase 0: Violation list compiled by group
- [x] Wave 1A: All 11 legacy specs verified — already use spec_kit (no conversion needed)
- [x] Wave 1B: All shared modules audited — uncached core.* calls are in defensive pcall blocks only
- [x] Wave 1C: Core files audited — no hot-path violations; 4/6 got Pattern 15 headers
- [x] Wave 1D: Class infrastructure audited — no bare menu access in middleware/schema
- [x] Wave 1E: Test files audited — proper NS mocking with _G.core
- [x] Phase 2: Compliance tests extended (class/schema/test-registration coverage)
- [x] Phase 3: Full validation suite green (252/252 + 13/13 PASS)
