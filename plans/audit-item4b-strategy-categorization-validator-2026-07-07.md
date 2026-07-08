# Plan: Audit Item #4b — Strategy Categorization Validator
**Date:** 2026-07-07
**Status:** COMPLETE
**Scope:** Audit item #4b — strategy categorization validator (static analysis test) + keyword-table fixes.

## Problem
Strategy categorization (`strategy_category()` in 3 locations: `core/strategy_gating.lua`,
`main_sylvanas.lua:1095`, `core_sylvanas.lua:5204`) uses **keyword substring matching** on the
strategy `.name` field. Strategies that don't match any keyword silently default to `"damage"`.

Risk: a defensive/cooldown strategy with a non-keyword name (e.g., "Stoneform", "PowerInfusion",
"Trinket") is miscategorized as `"damage"` — so toggling `use_cooldowns=false` or `damage_enabled=false`
won't suppress it correctly, OR it won't be suppressed when the player disables damage.

## Approach
A static-analysis test (like `test_schema_compliance.lua`) that:
1. Reads all spec + middleware files via file I/O.
2. Extracts `{ name = "X", ... }` strategy declarations.
3. Replicates `strategy_category()` logic locally.
4. Reports strategies that fall to the implicit `"damage"` default, flagging them for
   explicit `category = "..."` annotation.

This is a *baseline snapshot* test: it captures the current state and fails only when a NEW
unrecognized strategy is added (regression gate), not when existing ones are merely flagged.

## Validation
- `luac -p` on the test file.
- `run_rotation_tests.lua` (244/244 after registration).
- Baseline: capture current uncategorized count, then lock it as the ceiling.

**Date:** 2026-07-07
**Status:** IN PROGRESS
**Scope:** Static-analysis test that catches strategies miscategorized by the keyword-based `strategy_category()` system.

## Problem
`strategy_category()` (3 copies: `core/strategy_gating.lua`, `main_sylvanas.lua`, `core_sylvanas.lua`) classifies
strategies by **substring matching** on strategy names. Strategies whose name matches no keyword table fall to the
implicit `"damage"` default. This is dangerous: a defensive ability (e.g., "Healthstone", "Deterrence") that doesn't
match any keyword is categorized as "damage", so `use_defensives=false` / `utility_enabled=false` won't suppress it.
Conversely, a cooldown whose name matches a UTILITY keyword gets gated by the wrong toggle.

The audit said: "misspelled strategy names silently miscategorize defensive/CD sections."

## Fix
A pure static-analysis test (`test_strategy_categorization_validator.lua`) that:
1. Scans all `classes/*/*_sylvanas.lua` + `classes/*/middleware_sylvanas.lua` files.
2. Extracts strategy names via regex (`name = "X"`).
3. Applies the keyword categorization logic (mirrored from strategy_gating.lua).
4. Flags names that fall to implicit "damage" but contain known non-damage semantic indicators.
5. Flags names that are explicitly tagged `is_defensive=true` / `is_burst=true` / `category=` to verify the tag is recognized.
6. Maintains an explicit allowlist for intentional keyword-miss strategies (documented, not silent).

## Validation
- `luac -p` on the test file.
- `lua tests/test_strategy_categorization_validator.lua` standalone.
- `run_rotation_tests.lua` (243+1=244).
