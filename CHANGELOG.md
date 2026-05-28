# Changelog

## Unreleased

- **v1.1.1** — Add runtime file-version stamping and load-time logging for
  `EaxRotations` Lua files so in-game logs can confirm the active code after
  reboot. Includes `NS.dump_file_versions()` and documents the cooldown tracker
  fallback fix that prevents tick-level retry spam when cooldown APIs report `0`.
- **Private-Server API Health Guards** — Add
  `NS.broken_api_throttled(spell_id, seconds)` helper to `core_sylvanas.lua`
  that detects unhealthy aura APIs (common on private servers) and throttles
  repeated aura checks to prevent crash loops. Applied to **all 31 spec files**
  across all 9 classes with 3.0s throttle for self-buffs/seals/forms/shields
  and 2.0s for debuffs/dots. Also fixed `main_sylvanas.lua` bug where
  `target_range` was computed before `in_melee_range` was set. Restored missing
  Balance Druid strategies that caused 3 test failures. Fixed
  `test_balance_custom_matches.lua` mock so `action_execute` correctly calls
  `try_cast`. All 104 rotation suites + 11 leveling suites pass.
- **v1.0.30** — Add SP-aware DoT gating to all caster specs: Elemental Shaman Flame Shock (400 SP default, `elemental_flame_shock_min_sp` slider), Destruction Warlock Immolate (400 SP default, `destro_immolate_min_sp` slider), Balance Druid Insect Swarm + Moonfire (800 SP default, dual `balance_insect_swarm_min_sp` / `balance_moonfire_min_sp` sliders). All use `NS.get_spell_damage()` → `context.spell_damage` → 0 fallback pattern matching Shadow Priest/Affliction. Schemas updated with per-spec sliders (0–2000 range). Includes test fix for balance_custom_matches mock states and captures the earlier 5 PvP Tier 2 test additions (106→111 suites). Completes the deferred SP breakpoint research from `SP_Breakpoints_Druid_Balance.md`.
- **v1.0.29** — Add [IMBUEDIAG] debug instrumentation to shaman leveling rotation: log enchant detection (item_has_enchant, enchant_id, expiration, charges), weapon_imbue_matches flow (rejection reasons, spell ready state), try_cast results, and off-hand weapon enchant state. Fix nil crash in spell_ids log. Remove dead OFF_HAND_SLOT constant.
- **v1.0.28** — Bump all remaining per-cycle `[ROTDBG]` traces in `main_sylvanas.lua` from 500-1000ms to 2000ms: per-strategy `:blocked`, `:match`, `:exec` (was 700-1000ms), plus `target:pick`, `context:summary`, `gate:ooc`, `playstyle:active` (was 500ms). Debug output now ~10-15 lines/2s instead of 50+/frame.
- **v1.0.27** — Rate-limit `[EaxRotations:main] CALLING on_rotation_update` in `main.lua` to 1 per 2 seconds (was: every frame).
- **v1.0.26** — Convert 46 per-frame `[DEBUG] blocked:` NS.log messages in `action_matches()` to rate-limited `core_trace()` (2s throttle). Debug log is now readable when enabled.
- **v1.0.25** — Add Soul Shard reagent check (`has_item(6265)`) to Shadowburn and CreateHealthstone in destruction rotation.
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
