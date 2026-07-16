# Implementation Plan: Verify All Spells/IDs and Leveling Coverage (Vanilla 1-60 / TBC 1-70 / WotLK 1-80)

**Date:** 2026-07-16  
**Scope:** All spell/item IDs and leveling rotations across Vanilla Classic Anniversary, TBC Anniversary, and WotLK.  
**Notepad:** `C:\Users\Support\AppData\Local\Temp\opencode\ulw-20260716-124445.md`

---

## Executive Summary

This plan hardens EaxRotations so that **every numeric spell/item ID is verified against an authoritative source** and **every leveling rotation has a matching ladder test proving it can fire at least one sensible action at every level band** (Vanilla 1-60, TBC 1-70, WotLK 1-80).

We reuse the existing TBC DBC pipeline and audit runner, extend the Vanilla contamination audit into a true existence check, and build a lightweight WotLK spell-ID verifier against lexxer.org. For leveling, we generalize the existing low-level test pattern into expansion-aware ladder harnesses and add per-class low-level regression tests.

**Scope:** 157 class/rotation files, 28 leveling files, 7 shared bridge files, 265 registered test suites.  
**Success gates:** `luac -p` clean on every changed file; `run_rotation_tests.lua` + `run_leveling_tests.lua` pass; all new audit runners report zero invalid IDs; every class has a ladder test for each expansion.

---

## Task Dependency Graph (Waves)

```text
Wave 1 — Foundation & Tooling
├── 1.1 Extend class_loader for WotLK _wotlk preference
├── 1.2 Build WotLK spell-ID audit runner (lexxer.org)
├── 1.3 Add Vanilla existence audit runner (bridge spell_index_vanilla)
└── 1.4 Add shared leveling ladder harness (expansion-aware)

Wave 2 — Data & Bridge Hardening
├── 2.1 Generate WotLK stub spell index from lexxer.org
├── 2.2 Add item-ID audit pass to existing sylvanas audit
└── 2.3 Document per-expansion authoritative sources

Wave 3 — Leveling Coverage (TDD: test first, then fix)
├── 3.1 TBC 1-70 ladder tests (9 classes)
├── 3.2 Vanilla 1-60 ladder tests (existing + gap fill)
├── 3.3 WotLK 1-80 ladder tests (10 classes incl. DK)
└── 3.4 Fix dead strategies discovered by ladders

Wave 4 — Rotation Spell-ID Sweep
├── 4.1 TBC _sylvanas spell-ID re-audit
├── 4.2 Vanilla _vanilla existence re-audit
├── 4.3 WotLK _wotlk spell-ID audit
└── 4.4 Fix invalid IDs found by audits

Wave 5 — Integration & Lock-in
├── 5.1 Wire audit runners into CI/local pre-commit
├── 5.2 Add combined verification script
└── 5.3 Update AGENTS.md / README test counts
```

---

## Per-Task Details

### Wave 1 — Foundation & Tooling

#### Task 1.1: Extend `class_loader_sylvanas.lua` for WotLK `_wotlk` preference
- **WHAT:** Update `create_expansion_loader` so when `NS.is_wotlk()` is true it loads `<spec>_wotlk.lua` first, then falls back to `<spec>_sylvanas.lua`.
- **WHY:** WotLK specs already exist but the loader currently only prefers `_vanilla` vs `_sylvanas`; without this, WotLK clients load TBC rotations.
- **ACCEPTANCE:**
  - `NS.is_wotlk()` truthy → loader resolves `_wotlk.lua`.
  - `NS.is_vanilla()` truthy → loader resolves `_vanilla.lua`.
  - Otherwise → `_sylvanas.lua`.
  - Existing TBC/Vanilla load tests still pass.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/shared/class_loader_sylvanas.lua
  lua EaxRotations/tests/run_rotation_tests.lua
  lua EaxRotations/tests/run_leveling_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/shared/class_loader_sylvanas.lua`

#### Task 1.2: Build WotLK spell-ID audit runner
- **WHAT:** Create `EaxRotations/tests/run_wotlk_audit_tests.lua` that scans all `_wotlk.lua` files for numeric IDs and verifies them against a cached lexxer.org WotLK index (or live API with cache).
- **WHY:** No WotLK DBC pipeline exists; this gives us a static existence check before runtime.
- **ACCEPTANCE:**
  - Scans all `*_wotlk.lua` files under `EaxRotations/classes/`.
  - Reports `INVALID` for IDs not found in WotLK data.
  - Caches lexxer responses to `.cache/lexxer_wotlk.json` to avoid repeated API calls.
  - Does not modify source files.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/run_wotlk_audit_tests.lua
  lua EaxRotations/tests/run_wotlk_audit_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/run_wotlk_audit_tests.lua`, `.cache/lexxer_wotlk.json` (generated)

#### Task 1.3: Add Vanilla existence audit runner
- **WHAT:** Create `EaxRotations/tests/run_vanilla_existence_audit.lua` that verifies every numeric ID in `*_vanilla.lua` files exists in `wowhead_data_bridge_spell_index_vanilla_sylvanas.lua` (and item index where applicable).
- **WHY:** The existing `run_vanilla_audit_tests.lua` only detects TBC contamination; it does not catch invalid Vanilla IDs.
- **ACCEPTANCE:**
  - Scans all `*_vanilla.lua` files.
  - Reports IDs not in Vanilla spell/item index.
  - Distinguishes spell vs item mismatches.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/run_vanilla_existence_audit.lua
  lua EaxRotations/tests/run_vanilla_existence_audit.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/run_vanilla_existence_audit.lua`

#### Task 1.4: Add shared leveling ladder harness
- **WHAT:** Create `EaxRotations/tests/leveling_ladder_helper.lua` with:
  - `make_learned_spell_mock(expansion, level)` — returns `spell_ready`/`spell_exists`/`is_spell_learned` that respects a LEARN table.
  - `run_ladder(spec_file, expansion, level_bands)` — loads a spec at each level band and asserts at least one strategy matches.
- **WHY:** Generalizes the existing low-level test pattern for all three expansions.
- **ACCEPTANCE:**
  - Supports `vanilla`, `tbc`, `wotlk`.
  - Mocks `NS.spell_ready` to return `false` for spells above the tested level.
  - Returns clear pass/fail per level band.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/leveling_ladder_helper.lua
  lua EaxRotations/tests/run_leveling_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/leveling_ladder_helper.lua`

---

### Wave 2 — Data & Bridge Hardening

#### Task 2.1: Generate WotLK stub spell index from lexxer.org
- **WHAT:** Run a small script against `?game=wotlk` to produce `wowhead_data/spell_index_wotlk.json`, then convert it to `EaxRotations/shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua`.
- **WHY:** Gives the WotLK audit runner and any future rank resolver a local authoritative table.
- **ACCEPTANCE:**
  - File contains at least 10,000 WotLK spells.
  - Format matches existing TBC/Vanilla spell index (positional array).
- **VERIFICATION:**
  ```bash
  python build_tools/fetch_lexxer_wotlk.py
  luac -p EaxRotations/shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua
  ```
- **FILES TO TOUCH:** `build_tools/fetch_lexxer_wotlk.py`, `EaxRotations/shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua`

#### Task 2.2: Add item-ID audit pass to existing sylvanas audit
- **WHAT:** Extend `run_sylvanas_audit_tests.lua` to also flag item IDs used where a spell is expected (currently it only reports `ITEM_AS_SPELL` but does not fail).
- **WHY:** Prevents item IDs being silently treated as spells.
- **ACCEPTANCE:**
  - `ITEM_AS_SPELL` hits cause audit failure by default.
  - Add an allowlist for intentional item-as-spell usages (if any).
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/run_sylvanas_audit_tests.lua
  lua EaxRotations/tests/run_sylvanas_audit_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/run_sylvanas_audit_tests.lua`

#### Task 2.3: Document per-expansion authoritative sources
- **WHAT:** Add a small `docs/SPELL_ID_SOURCES.md` mapping:
  - TBC: `wowheadScrape/dbc_extract/wowsims.db`
  - Vanilla: `wowhead_data_bridge_spell_index_vanilla_sylvanas.lua`
  - WotLK: lexxer.org + generated bridge
- **WHY:** Removes ambiguity about which source is authoritative.
- **ACCEPTANCE:** Document exists and is referenced from AGENTS.md.
- **FILES TO TOUCH:** `docs/SPELL_ID_SOURCES.md`

---

### Wave 3 — Leveling Coverage (TDD)

#### Task 3.1: TBC 1-70 ladder tests (9 classes)
- **WHAT:** For each TBC class, add a test that loads `leveling_sylvanas.lua` at levels 10, 20, 30, 40, 50, 60, 70 and asserts at least one strategy matches with realistic learned-spell mocks.
- **WHY:** Proves no dead rotation at any TBC level.
- **ACCEPTANCE:**
  - One test file per class or one combined `test_tbc_leveling_ladders.lua`.
  - Each level band has ≥1 matching strategy.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/test_tbc_leveling_ladders.lua
  lua EaxRotations/tests/run_leveling_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/test_tbc_leveling_ladders.lua`

#### Task 3.2: Vanilla 1-60 ladder tests (gap fill)
- **WHAT:** Extend existing low-level Vanilla tests to cover all 9 classes at bands 10/20/30/40/50/60.
- **WHY:** Currently only some classes are covered.
- **ACCEPTANCE:** All 9 Vanilla classes have ladder coverage.
- **VERIFICATION:**
  ```bash
  lua EaxRotations/tests/run_leveling_tests.lua
  ```
- **FILES TO TOUCH:** Existing Vanilla low-level test files

#### Task 3.3: WotLK 1-80 ladder tests (10 classes incl. DK)
- **WHAT:** Add `test_wotlk_leveling_ladders.lua` covering all 10 WotLK classes (including Death Knight) at levels 10, 30, 50, 60, 70, 80.
- **WHY:** WotLK leveling currently has only a load test.
- **ACCEPTANCE:** Every WotLK leveling file matches at least one strategy at every band.
- **VERIFICATION:**
  ```bash
  luac -p EaxRotations/tests/test_wotlk_leveling_ladders.lua
  lua EaxRotations/tests/run_leveling_tests.lua
  ```
- **FILES TO TOUCH:** `EaxRotations/tests/test_wotlk_leveling_ladders.lua`

#### Task 3.4: Fix dead strategies discovered by ladders
- **WHAT:** As ladder tests fail, relax over-strict gates (e.g., Mangle debuff below 50, Scorch 5-stack when unlearned, Execute rage thresholds at low level).
- **WHY:** Ladder tests are the contract; fixes make them pass.
- **ACCEPTANCE:** All ladder tests green.
- **VERIFICATION:**
  ```bash
  lua EaxRotations/tests/run_leveling_tests.lua
  lua EaxRotations/tests/run_rotation_tests.lua
  ```
- **FILES TO TOUCH:** Per-class `leveling_*.lua` and combat spec files as needed.

---

### Wave 4 — Rotation Spell-ID Sweep

#### Task 4.1: TBC `_sylvanas` spell-ID re-audit
- **WHAT:** Run `run_sylvanas_audit_tests.lua` after all Wave 3 changes.
- **WHY:** Catches any new invalid IDs introduced by fixes.
- **ACCEPTANCE:** Zero invalid IDs.
- **VERIFICATION:**
  ```bash
  lua EaxRotations/tests/run_sylvanas_audit_tests.lua
  ```

#### Task 4.2: Vanilla `_vanilla` existence re-audit
- **WHAT:** Run new `run_vanilla_existence_audit.lua`.
- **WHY:** Ensures all Vanilla IDs exist in Vanilla bridge.
- **ACCEPTANCE:** Zero invalid IDs.

#### Task 4.3: WotLK `_wotlk` spell-ID audit
- **WHAT:** Run new `run_wotlk_audit_tests.lua`.
- **WHY:** First comprehensive WotLK ID check.
- **ACCEPTANCE:** Zero invalid IDs (or documented exceptions).

#### Task 4.4: Fix invalid IDs found by audits
- **WHAT:** Replace invalid IDs with correct ones from authoritative sources.
- **WHY:** Closes the verification loop.
- **ACCEPTANCE:** All three audit runners green.
- **FILES TO TOUCH:** Per-class spec files as needed.

---

### Wave 5 — Integration & Lock-in

#### Task 5.1: Wire audit runners into CI/local pre-commit
- **WHAT:** Add a `verify.ps1` script at repo root that runs all audit + test runners.
- **WHY:** Makes verification one command.
- **FILES TO TOUCH:** `verify.ps1`

#### Task 5.2: Add combined verification script
- **WHAT:** Create `EaxRotations/tests/run_all_verification.lua` that runs all audit + test runners and reports a single pass/fail.
- **WHY:** Simplifies ultrawork execution.
- **FILES TO TOUCH:** `EaxRotations/tests/run_all_verification.lua`

#### Task 5.3: Update AGENTS.md / README test counts
- **WHAT:** Update test counts and add references to new audit runners.
- **WHY:** Keeps documentation in sync.
- **FILES TO TOUCH:** `AGENTS.md`, `EaxRotations/README.md`

---

## Scenario Contract

### Happy Path
- A developer changes a spell ID in a `_wotlk.lua` file.
- `run_wotlk_audit_tests.lua` passes because the ID exists in WotLK data.
- Ladder tests for that class still pass at all level bands.
- Full `run_rotation_tests.lua` + `run_leveling_tests.lua` pass.

### Edge Path
- A low-level TBC Druid at level 42 has no Mangle Cat.
- Ladder test asserts Shred still matches; if it fails, the gate is relaxed.
- No runtime crash because `spell_ready` returns `false` for unlearned spells.

### Regression Path
- Existing TBC/Vanilla specs must not change behavior.
- Existing audit runners must still pass.
- `class_loader_sylvanas.lua` changes must not break TBC/Vanilla loading.

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| lexxer.org rate limits or downtime | High | Cache all API responses; allow `--offline` mode using cached index. |
| WotLK data incomplete on lexxer | High | Cross-check against Wowhead scrape; document any manual IDs. |
| Ladder tests too strict (false failures) | Medium | Start with permissive mocks; only assert ≥1 strategy matches, not specific spell. |
| Shared module changes break TBC/Vanilla | High | Run full regression suite after every shared module edit; one concern per commit. |
| Large number of invalid WotLK IDs found | Medium | Fix in small class batches; do not big-bang. |
| Item-as-spell false positives | Low | Maintain an explicit allowlist in the audit runner. |

---

## Atomic Commit Strategy

1. **One concern per commit.** Never bundle audit tooling with spec fixes.
2. **Commit order:**
   - Loader extension (Task 1.1)
   - New audit runners (Tasks 1.2, 1.3)
   - Ladder harness (Task 1.4)
   - WotLK data bridge (Task 2.1)
   - TBC/Vanilla/WotLK ladder tests (Tasks 3.1–3.3)
   - Dead-strategy fixes (Task 3.4) — one class per commit
   - Spell-ID fixes (Task 4.4) — one class per commit
   - Integration scripts + docs (Tasks 5.1–5.3)
3. **Pre-commit validation for every commit:**
   ```bash
   luac -p <changed_file>
   lua EaxRotations/tests/run_rotation_tests.lua
   lua EaxRotations/tests/run_leveling_tests.lua
   ```
4. **Commit message format:** `feat(audit): <what> — <scope>` or `fix(leveling): <class> low-level gate`.

---

## TDD-Oriented Planning

For each class/expansion pair, the workflow is:

1. **Red:** Write ladder test asserting ≥1 strategy matches at each level band.
2. **Run:** Observe failure (dead strategy or invalid ID).
3. **Green:** Fix the spec/leveling file minimally.
4. **Refactor:** Move repeated level-gate logic into `leveling_helpers_sylvanas.lua`.
5. **Lock:** Add the test to `run_leveling_tests.lua`.

---

## Verification Command Summary

```bash
# Syntax check all changed files
luac -p <file>.lua

# Core test suites
lua EaxRotations/tests/run_rotation_tests.lua
lua EaxRotations/tests/run_leveling_tests.lua
lua EaxRotations/tests/run_wotlk_tests.lua

# Audit runners
lua EaxRotations/tests/run_sylvanas_audit_tests.lua
lua EaxRotations/tests/run_vanilla_audit_tests.lua
lua EaxRotations/tests/run_vanilla_existence_audit.lua
lua EaxRotations/tests/run_wotlk_audit_tests.lua

# Combined (after Task 5.2)
lua EaxRotations/tests/run_all_verification.lua
```
