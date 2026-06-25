# Cleanup Inventory — EaxRotations Repository Audit

> Generated: 2026-06-25
> Scope: repo root + EaxRotations/
> Rule: DO NOT delete anything without explicit human approval.

---

## 1. Top-Level Dead Items

| Item | Git Status | Why Dead | Recommendation | Risk |
|------|-----------|----------|----------------|------|
| `START_HERE.md` | `D` (deleted from worktree) | Superseded by `AGENTS.md` and `EaxRotations/README.md`; content duplicated in AGENTS.md session-start protocol | **Delete** — fully redundant | Low |
| `class_spell_reference.md` | `D` (deleted from worktree) | Raw wiki scrape from 2026-06-09; not referenced by any build script; spell data now lives in `wowheadScrape/` and DBC | **Delete** — stale reference, not wired into pipeline | Low |
| `humanpending.md` | `D` (deleted from worktree) | One-time decision tracker from 2026-06-10; all decisions resolved | **Delete** — fully resolved | Low |
| `.omo/` | `D` (deleted from worktree) | AI IDE session metadata (OpenCode/omo tool); already in `.gitignore` | **Delete** — should never have been tracked | Low |
| `common` | `M` (modified binary) | Binary blob (7.7 MB), not a folder; zero Lua `require` references in EaxRotations/; not used by any script | **Investigate then delete** — appears to be stale compiled Lua artifact | Medium |
| `core_lua` | `M` (modified binary) | Binary blob (662 KB); zero Lua `require` references; not used by any script | **Investigate then delete** — appears to be stale compiled Lua artifact | Medium |
| `core_universal_kicks` | `M` (modified binary) | Binary blob (176 KB); zero Lua `require` references; not used by any script | **Investigate then delete** — appears to be stale compiled Lua artifact | Medium |

**Note on binary blobs**: `common`, `core_lua`, and `core_universal_kicks` are tracked in git history but show as modified in the worktree. They may be compiled Lua bytecode (`.luac` output) that were committed by accident. They are NOT directories despite their names. A `git show HEAD:common | file -` confirms "data" (binary). Safe to remove if they are not loaded by any external Project Sylvanas runtime.

---

## 2. Unreferenced Lua Files in EaxRotations/

Files that exist on disk but are never `require()`-d by any other `.lua` file in the repo.

### 2a. Dynamic-Load Modules (NOT Dead — expansion-aware loader)

| File | Loader Path | Status |
|------|-------------|--------|
| `classes/*/leveling_vanilla.lua` (×9) | `load_spec("leveling", true)` via `create_expansion_loader` | **Keep** — loaded dynamically when `NS.is_vanilla()` is true |

### 2b. Genuinely Unreferenced Files

| File | Size | Why Unreferenced | Recommendation | Risk |
|------|------|------------------|----------------|------|
| `ui_sylvanas.lua` | ~300 lines | Listed in `EaxRotations/README.md` architecture diagram as "Menu framework", but no `require("ui_sylvanas")` exists anywhere in the codebase. May have been superseded by `common_sylvanas.lua` + `dashboard_sylvanas.lua`. | **Investigate** — if truly superseded, delete or move to `_archive/` | Medium |
| `tests/_paladin_edge_insert.lua` | 435 lines | Edge-case tests using an inline `test()` harness. Never imported by any runner. Appears to be a scratch/insert file (note `_` prefix). | **Keep or register** — contains real edge-case coverage; could be merged into `test_paladin_holy_custom_matches.lua` or registered standalone | Low |
| `tests/_rogue_edge_insert.lua` | 747 lines | Same pattern as above. Edge-case tests for rogue strategies. | **Keep or register** — valuable boundary coverage | Low |
| `tests/_warlock_deep_dive.lua` | 388 lines | Deep-dive OOC/combat gate analysis for warlock. Note `_` prefix. | **Keep or register** — useful reference for combat-gate logic | Low |
| `tests/_warrior_edge_insert.lua` | 769 lines | Edge-case tests for warrior strategies. | **Keep or register** — valuable boundary coverage | Low |

### 2c. Orphaned Test Files (Not in Any Runner)

| File | Runner Missing | Standalone Result | Assessment |
|------|---------------|-------------------|------------|
| `tests/test_leveling_edge_cases.lua` | `run_rotation_tests.lua` + `run_leveling_tests.lua` | **FAIL** (1 failure: mage match mana_pct 0 wand match) | **Intentionally orphaned** — fails on a known edge case; should be fixed and registered, or deleted if abandoned |
| `tests/test_reset_api_health.lua` | `run_rotation_tests.lua` | **FAIL** (`debug.setupvalue` throws) | **Intentionally orphaned** — uses `debug.setupvalue` which fails in this Lua environment; test is fragile |
| `tests/test_reset_api_health_spell_integration.lua` | `run_rotation_tests.lua` | **FAIL** (same `debug.setupvalue` issue) | **Intentionally orphaned** — same fragility as above |
| `tests/test_runner_lib.lua` | `run_rotation_tests.lua` + `run_leveling_tests.lua` | N/A (library file) | **Keep** — it IS referenced by `require("EaxRotations/tests/test_runner_lib")` in both runners |

**Reconciliation**: `test_runner_lib.lua` is not missing — it is required by the runners themselves. The other three are genuinely orphaned.

---

## 3. Duplicate Files

No exact MD5 duplicates found within `EaxRotations/`.

---

## 4. Summary & Recommended Actions

1. **Safe to delete now (low risk)**:
   - `START_HERE.md`
   - `class_spell_reference.md`
   - `humanpending.md`
   - `.omo/` directory

2. **Requires investigation before deletion (medium risk)**:
   - `common`, `core_lua`, `core_universal_kicks` (binary blobs — verify they are not loaded by external Project Sylvanas runtime)
   - `ui_sylvanas.lua` (verify it is truly superseded by dashboard/common modules)

3. **Should be fixed and registered (low risk, high value)**:
   - `test_leveling_edge_cases.lua` — fix the 1 failing assertion, then add to `run_leveling_tests.lua`
   - `test_reset_api_health.lua` + `test_reset_api_health_spell_integration.lua` — replace `debug.setupvalue` with a mock-based approach, then register

4. **Should be kept (underscore-prefixed scratch files)**:
   - `_paladin_edge_insert.lua`, `_rogue_edge_insert.lua`, `_warlock_deep_dive.lua`, `_warrior_edge_insert.lua`
   - Consider renaming without `_` prefix and registering in `run_rotation_tests.lua` once they have a proper `require` path.

---

## 5. Test Orphan Registry Gap

The following test files exist on disk but are **not listed** in either `run_rotation_tests.lua` or `run_leveling_tests.lua`:

- `test_leveling_edge_cases.lua`
- `test_reset_api_health.lua`
- `test_reset_api_health_spell_integration.lua`

**Action**: Fix the failures and register them, OR formally abandon them and add a comment block in this inventory file explaining why.
