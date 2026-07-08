# Plan: cooldown_planner_sylvanas.lua — spec-registered CD extensions

**Date:** 2026-07-08
**Status:** COMPLETE
**Scope:** Audit gap "cooldown_planner PARTIAL (MED) — hardcoded CD ID lists, not driven by each spec's spell table."

## Problem
`MAJOR_OFFENSIVE_CD_IDS` (was 10, now 9 after removing stale `12293` Defensive Stance entry)
missed several important spec-specific cooldowns that ARE in the `COOLDOWN_NAMES` keyword table:
Combustion (mage fire, 11129), Rapid Fire (hunter MM, 3045), Adrenaline Rush (rogue combat, 13750),
Blade Flurry (rogue combat, 13877), Blood Fury (20572), Berserking (20554). So `is_major_offensive_cd_active()`
returned false when those fired, meaning `should_fire_offensive()` did NOT stack trinkets/racials with them.

## Fix
1. Added `register_offensive_cd(spec_name, ids)` + `register_defensive_cd(spec_name, ids)` so specs
   augment the planner with their own cooldown buff IDs at load time — no shared-file edits per new CD.
2. Added `get_offensive_cd_ids(spec_name)` + `get_defensive_cd_ids(spec_name)` getters (defaults + extensions).
3. Updated `is_major_offensive_cd_active` / `is_major_defensive_cd_active` to also check spec-registered IDs.
4. Added `get_context_playstyle(context)` resolver that checks ALL production sources
   (`context.active_playstyle`, `context.playstyle`, `context.settings.playstyle`, `NS.get_setting("active_playstyle")`)
   — production exposes playstyle inconsistently, so the extension fires regardless of source.
5. Removed stale `12293` (Defensive Stance, mislabeled "no, skip") from the offensive list (was a 10th entry).
6. Wired fire mage: `planner.register_offensive_cd("fire", { 11129 })` at load (Combustion).

## Validation
- `luac -p` passes on planner + fire_sylvanas.lua.
- `test_cooldown_planner.lua`: extended with 11 new scenarios (registration, getters, robust playstyle
  resolution via `context.settings.playstyle` and `NS.get_setting`). All pass.
- `run_rotation_tests.lua`: 244/245 (1 pre-existing failure unrelated).
- `run_leveling_tests.lua`: 13/13.

## Future (not done — out of scope)
Other specs with uniquely-important missing CDs (combat rogue Adrenaline Rush/Blade Flurry, BM hunter
Rapid Fire, shadow priest racials) can call `register_offensive_cd` at load; the API is now ready.
