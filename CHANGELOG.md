# Changelog

## Unreleased

- **v1.0.24** — Gate [ROTDBG] and [CASTDBG] debug log spam behind `debug_system` setting; add Soul Shard reagent check to SoulFire in destruction rotation.
- **v1.0.23** — Fix Fel Armor ↔ Demon Armor / Water Shield ↔ Lightning Shield mutual exclusion toggle in OOC manager by using combined buff-ID tables so each entry detects the other's buff.
- Added Wago-backed non-runtime audits for TBC spell/item IDs, archive triage, static behavior risks, and Lua/Markdown-only release contents.
- Expanded shared TBC ID data with central racials, common CC, Druid utility, and Hunter utility/spell coverage.
- Moved class-file direct Sylvanas API calls behind shared `NS` helpers for cancel and totem access.
- Replaced the shell leveling test runner with a Lua runner so `EaxRotations` remains `.lua`/`.md` only.
- Rebuilt `EaxRotations` as a single Project Sylvanas package.
- Added shared nil-safe runtime helpers for spell resolution, cast gating, aura checks, healing scans, threat drops, stance/form checks, and protected strategy dispatch.
- Added class modules for all supported classes and playstyles.
- Added rank fallback spell tables so lower-level characters can resolve learned ranks instead of hard-locking to max-rank spells.
- Added defensive middleware for threat-drop abilities that only runs with a nearby group member in combat.
- Added pet-aware hunter support for pet-targeted actions.
- Added healer logic that considers effective health with incoming heals and absorbs where the runtime exposes those values.
- Added regression tests and API lint tests for the rebuilt package.
- Gated 30+ debug-level `core.log()` calls (DIAG buff_up, ROTDBG strategy flow, CASTDBG try_cast trace, DEBUG spell ready) behind `debug_system`/`debug_mode` settings — zero log spam per frame when disabled.
- Fixed Fel Armor recast spam: added 30s throttle + `buff_up` check in affliction strategy, plus nil-safe `buff_remains` guard in OOC manager to skip self-buffs when the buff API is unavailable.
- Fixed mana bypass bug in `has_resource()`: when `get_power(MANA)` returns 0 (broken API), the fallback now also checks `cost_percent` against `mana_pct` before allowing percentage-cost spells through.
- Fixed Summon Imp double-cast: added `me:has_pet()` pcall fallback in OOC manager for builds where `NS.GetPet()` returns nil despite a pet existing.
- Made dashboard `update_dashboard()` crash-safe with pcall wrapper to prevent line 396 threat_situation crashes from flooding console.
- Made GUARD-2/3 (nil player / dead player) one-shot log guards to avoid repeating spam during loading screens.
