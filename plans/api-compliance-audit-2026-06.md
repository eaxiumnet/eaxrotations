# Plan: API Compliance Audit — EaxRotations vs Sylvanas API

**Objective:** Audit all 29 spec files + shared modules for usage of non-existent, misnamed, or incorrectly parameterized Sylvanas API calls. Fix or flag each issue.

**Source of truth:** `api/` (runtime stubs) and `apidocs/pages/dev/api/` (documentation).

---

## FINDINGS BY SEVERITY

### CRITICAL (nil crash at runtime)

| # | Class | File | Issue | Line(s) |
|---|-------|------|-------|---------|
| C1 | Warlock | `warlock_core_sylvanas.lua` | `FIRE_IMMUNE_MOBS` — table never defined anywhere in project; `FIRE_IMMUNE_MOBS[npc_id]` will nil-index crash | 54 |
| C2 | Druid | middleware:228 | `context.is_stealthed` — never set by build_context; stealthed consumable gate always passes, potions/pots fire during Prowl | 228 |

### HIGH (wrong behavior, no crash)

| # | Class | File | Issue | Line(s) | Impact |
|---|-------|------|-------|---------|--------|
| H1 | Rogue | assassin | `context.dist_to_target < 15` — nil < 15 always true; Sprint always fires | 489 | PvP: Sprint wasted every GCD |
| H2 | Rogue | all 3 specs | `context.threat_pct` — gates Feint/Vanish threat drops, never set | ass:216,548 / combat:206 / sub:159 | Threat strats dead |
| H3 | Rogue | assassin | `context.target_bleed_immune` — gates Rupture, never set | 313 | Rupture wasted on immune |
| H4 | Rogue | assassin | `context.target_dr_stun` — gates Kidney Shot PvP DR, never set | 332 | CC wasted on DR |
| H5 | Rogue | ass:449 / sub:406 | `context.has_sunder` — gates Expose Armor, never set | 449, 406 | Raid debuff contention |
| H6 | Rogue | assassin | `context.aoe_damage_incoming` — gates Feint AoE, never set | 553 | AoE mitigation dead |
| H7 | Rogue | middleware:262 | `context.is_raid_boss` — gates Vanish in raids, never set | 262 | Vanish wasted in raids |
| H8 | Paladin | middleware | `context.is_mounted` — gates OOC buffs, never set | 143,298,352,400,602 | Buff cast while mounted |
| H9 | Priest | holy:202 | bare `core` global — typo/leak referencing undefined global `core.get_map_id()` | 202 | Potential nil crash |
| H10 | Priest | discipline | `context.player_control_locked` never injected in build_state (holy/smite DO inject it) | 546 | StopCast strategy dead |
| H11 | Hunter | all 6 files | `context.pet` — never set by build_context; leveling pet HP always 100%, MendPet never fires from leveling strategies | various | Leveling pet healing broken |
| H12 | Warlock | demonology:117 | `_G.izi.pet()` — bypasses NS boundary, guarded but non-standard | 117-118, 136-137 | Fragile IZI dependency |
| H13 | Shaman | enh:12 | `rawget(_G, "core")` — bypasses NS entirely for totem/visible-object scanning | 12-14 | Core API dependency |
| H14 | Priest | holy:57 | bare `TBC` global — namespace leak, `TBC.ITEMS.healthstones` outside NS | 57 | Fragile global dep |
| H15 | Priest | discipline | `context.player_control_locked` never set — StopCast at 546 reads nil | 546 | Spell lock detection dead |
| H16 | Warlock | middleware:398 | `NS.inventory` doesn't exist on NS — dead code branch | 398-399 | Soul shard check dead |

### MEDIUM (dead code paths)

| # | Class | File | Issue | Line(s) |
|---|-------|------|-------|---------|
| M1 | Hunter | bm, sv | `context.distance_sq` — never set by build_context, melee detection (Raptor Strike, Wing Clip, Conc Shot) never fires | bm:454,469 / sv:284,329,344 |
| M2 | Paladin | ret:214 | `context.time_to_swing` / `context.swing_remains` — never set | 214 |
| M3 | Paladin | ret | `context.mana` — undocumented alias for `mana_pct`; `context.party_members/group_members/allies/friends` — 4-field fallback chain | various |
| M4 | Mage | fire | `context.scorch_stacks` / `context.scorch_remains` / `context.pyroblast_ready` — never set, have `or 0` fallbacks | fire_syl:84-97,211 / fire_v:81-92 |
| M4b | Mage | fire, arcane | `context.cc_target` — PvP polymorph target never set; 2 lines pass nil to NS.try_cast | fire_syl:295 / fire_v:305 |
| M4c | Mage | frost | `context.enemies` (array) — always nil; Cone of Cold enemy count always falls back to 1 | frost_syl:72-75 / frost_v:63-66 |
| M5 | Shaman | ele:155,363 | `context.cc_safe` — never set | 155,363,374 |
| M6 | Shaman | ele:240 | `context.fear_nearby` — never set | 240 |
| M7 | Shaman | ele:258 | `context.group_injured` — never set | 258 |
| M8 | Shaman | ele:385 | `context.has_totems` — never set | 385 |
| M9 | Shaman | restoration | `context._shaman_heal` — side-channel context mutation | 290,539 |
| M10 | Warrior | arms:531 / arms_v:468 | `context.target_in_combat` — never set, Charge OOC guard always passes | 531,468 |
| M11 | Warrior | fury_v:136 | `context.time_to_die(target)` — never set, always falls back to 15 | 136 |
| M12 | Warlock | aff:367-422 | Duplicate CorruptionSpread strategy — 2nd overwrites 1st, likely meant for UA Spread | 367-381,422-436 |
| M13 | Warlock | aff | `context.enemy_caster/healer/shadow_caster` — never set (PvP context fields) | 257,787,837 |
| M14 | Warlock | warlock_core | `core.inventory.get_item_count` — undocumented API, pcall-wrapped | 189,327 |
| M15 | Priest | smite:156 | `context.target_phys_immune` — never set, silently nil | 156 |
| M16 | Priest | smite:148 | `context.lowest_ally_hp` / `context.lowest_group_hp` — never set | 148 |
| M17 | Warrior | all 3 | `context.distance` — fallback alias for `target_distance`, unreachable dead branch | arms:286, fury:276, arms_v:252 |
| M18 | Druid | balance | `ctx.has_feral_druid` — never set; Faerie Fire skip permanently disabled | balance_syl:248 / balance_v:219 |
| M19 | Druid | balance | `ctx.melee_on_you` — never set; PvP Entangling Roots dead | balance_syl:353,365 / balance_v:308,319 |
| M20 | Druid | balance | `ctx.enemy_healer` — never set; Cyclone-on-healer dead | balance_syl:378 |
| M21 | Druid | caster | `NS.unit_mana_pct` — not defined in NS API (used across 25+ files project-wide) | caster_syl:31 / caster_v:29 |
| M22 | Druid | caster | `context.active_playstyle` — never set by build_context | caster_syl:45 / caster_v:39 |

### LOW (cosmetic / redundant)

| # | Class | File | Issue |
|---|-------|------|-------|
| L1 | Druid | cat / cat_v | `context.is_target_player`, `context.cp`, `context.range`, `context.attack_power`, `context.is_behind` — each has working fallback via NS.* or target:method(). Dead optimization paths. |
| L2 | All | various | `_G.BurstLogic`, `_G.CombatForecastGate`, `_G.TTDTracker` etc. — 15 modules writing to `_G`. Intentional pattern, low risk. |
| L3 | Priest | shadow:526 | `context.target_is_casting` — non-standard fallback, works via `target:is_casting()` |
| L4 | Priest | middleware:420 | `context.target_ttd` — falls back to 999, harmless |
| L5 | Mage / Frost | frost:72-75 | `context.enemies` (table) — fallback alias for enemy_count. Never nil. |

---

## Execution Plan

### Phase 1: Fix CRITICAL + HIGH bugs (parallel per bug)
- C1: Add `FIRE_IMMUNE_MOBS` table to warlock_core or fix to use NS lookup
- H9: Fix bare `core` global in holy_sylvanas.lua → `NS.core`
- H14: Fix bare `TBC` global in holy_sylvanas.lua → inline healthstone IDs (follow discipline pattern)
- H16: Fix `NS.inventory` → use `core.inventory` with pcall or add to NS
- H13: Fix `rawget(_G, "core")` in enh → use `NS.core` instead
- H11: Add `context.pet` to build_context() in main_sylvanas.lua or clean up hunter files

### Phase 2: Fix context field bugs (one agent per class)
For each class's non-standard context fields:
- H1-H7 (Rogue): Fix key names or add fields to build_context
- H8 (Paladin): Add is_mounted to context or guard with NS check
- H10 (Priest): Add player_control_locked injection to discipline build_state
- H15 (Priest): Same as H10
- M1 (Hunter): Add distance_sq computation
- M2-M3 (Paladin): Clean up fallback chains
- M4 (Mage): Add scorch/pyroblast/cc_target/enemies fields or remove dead lookups
- M5-M9 (Shaman): Add missing fields or replace with direct NS calls
- M10-M11 (Warrior): Fix target_in_combat and time_to_die references
- M12 (Warlock): Fix duplicate CorruptionSpread strategy
- M13-M14 (Warlock): Add missing context fields or remove fallbacks
- M15-M17: Priest/Warrior — clean up fallback chains

### Phase 3: Verification
- Run `luac -p` on all modified files
- Run `lua EaxRotations/tests/run_rotation_tests.lua`
- Run `lua EaxRotations/tests/run_leveling_tests.lua`