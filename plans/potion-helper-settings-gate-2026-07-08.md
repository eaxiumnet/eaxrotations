# Plan: potion_helper_sylvanas.lua — settings gate + cooldown pre-check

**Date:** 2026-07-08
**Status:** COMPLETE
**Scope:** Audit gap "potion_helper INCOMPLETE (MED/HIGH) — near-stub, not settings-gated, overlaps with consumable_manager."

## Problem
`potion_helper.try_use_potion` had 3 gaps:
1. NOT settings-gated — no `use_auto_potions` check (specs gate at call site, but helper should be self-gating like `consumable_manager`)
2. No cooldown pre-check — blindly called `use_item_by_id` for ALL 10 IDs via pcall, wasting API calls on cooldown'd items
3. No `find_ready_item` generalization (only `find_ready_healthstone` existed)

## Fix
1. Added `use_auto_potions == false` settings gate (defense-in-depth; defaults to enabled when nil = backward compat)
2. Added `is_item_ready` cooldown pre-check inside the loop (fail-open when API unavailable, same pattern as `consumable_manager.item_ready`)
3. Added `item_ready` local helper + `M.find_ready_item(ids)` generalization
4. Updated Pattern 15 header (SAFETY line documents settings gate + cooldown pre-check)
5. Added 7 new test scenarios to `test_potion_helper_module.lua`

## Validation
- `luac -p` passes on both files.
- `test_potion_helper_module.lua`: all 14 scenarios pass (7 original + 7 new).
- `run_rotation_tests.lua`: 244/245 pass (1 pre-existing failure unrelated).
- `run_leveling_tests.lua`: 13/13 pass.
- All ~15 specs consuming `potion_helper` unaffected (backward compat: nil settings → enabled).
