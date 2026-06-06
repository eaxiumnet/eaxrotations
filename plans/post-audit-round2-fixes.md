# Plan: Round 2 Post-Audit Fixes — Middleware + Rotation Correctness

## STRICKEN: All WotLK spell ID findings were FALSE POSITIVES

**TBC Classic Anniversary 2.5.1-2.5.5 runs on the Wrath client (3.3.5 engine).** Spells from WotLK and beyond that exist in the Wrath client are available, including Victory Rush, Survival Instincts, Pain Suppression, Silencing Shot, Spellsteal, Molten Armor, Slow, Fireball R14, Arcane Missiles R11, Gouge R6, and Seal of the Martyr.

The spell audit used `wowhead_data/spells/tbc/` which only covers original TBC 2.4.3 — NOT the extended 2.5.x spell set. The class_sylvanas.lua files are CORRECT as-is. No changes needed.

| # | Source | File | Issue | Fix |
|---|--------|------|-------|-----|
| P0-1 | Warrior cross-ref | prot | No threat tab targeting for multi-target tanking | Add nameplate scan + target cycling |
| P0-2 | Warrior cross-ref | fury_vanilla | No stance management at all; can't use OP or WW correctly | Add Berserker/Battle stance dancing |
| P0-3 | Warrior cross-ref | fury_sylvanas | Overpower in Fury rotation loses 3% Berserker crit; OP is Arms-only in TBC | Remove OP from Fury or nerf priority |

## Priority 1: HIGH (bugs, must fix)

| # | Source | File | Issue | Fix |
|---|--------|------|-------|-----|
| H-1 | Middleware audit | druid:393, rogue:166 | ThreatDrop lacks `in_combat` guard, fires OOC | Add combat check |
| H-2 | Middleware audit | shaman:163,205 | `NS.try_cast(cure_id, nil, ...)` passes nil target | Pass `context.me` instead |
| H-3 | Middleware audit | warlock:398-401 | Bare global `core` without local declaration | Use `NS.core` |
| H-4 | Warrior cross-ref | prot | Taunt logic too simple: no CC/TTD/classification check | Add smart taunt guards |
| H-5 | Warrior cross-ref | fury_sylvanas | Overpower in Fury rotation | Remove or make Arms-only |
| H-6 | Warrior cross-ref | arms_sylvanas | No Sweeping Strikes rage pooling | Reserve 60 rage before SS |
| H-7 | Warrior cross-ref | arms_sylvanas | No smart Overpower rage protection | Gate OP: skip if MS/WW/Execute would starve |
| H-8 | Warrior cross-ref | fury_sylvanas | No swing desync for dual-wield | Add SwingDesync strategy |
| H-9 | Vanilla arms/fury | leveling + spec | No creature type filtering for Rend on bleed-immune | Add creature type check |

## Priority 2: MEDIUM (dead code, duplication)

| # | Source | File | Issue |
|---|--------|------|-------|
| M-1 | Middleware audit | All 9 middleware | AutoConsumable entry duplicated 9x — consolidate |
| M-2 | Middleware audit | 4 middleware | PvP CC Gate pattern duplicated 4x — consolidate |
| M-3 | Middleware audit | 5 middleware | CC Break pattern duplicated 5x — consolidate |
| M-4 | Middleware audit | warrior:115-117 | Second Battle Shout buff check is unreachable |
| M-5 | Middleware audit | paladin:237,257,278 | Uses `me.debuff_remains` instead of `NS.debuff_remains` |
| M-6 | Middleware audit | shared | `pvp_trinket_tracker_sylvanas.lua` never `require()`'d |
| M-7 | Middleware audit | shaman:84-123 | Purge double-scans enemies per tick (no cache) |
| M-8 | Middleware audit | druid:319-342 | Curse/poison IDs declared in both matches and execute |
| M-9 | Middleware audit | druid:168-169 | `"bear"` string passed where numeric stance ID expected |
| M-10 | Overall | EaxRotations/ | `pvp_trinket_tracker_sylvanas.lua` never loaded |

## Priority 2b: Missing Spec-Defining Abilities (Hunter/Mage/Warlock cross-ref)

| # | Spec | Missing Ability | Source |
|---|------|---------------|--------|
| X-1 | MM Hunter | **Aimed Shot** (41-pt MM talent) | Standard MM talent — widely used |
| X-2 | SV Hunter | **Wyvern Sting** (41-pt SV talent) | Standard SV talent — widely used |
| X-3 | SV Hunter | **Explosive Trap / Immolation Trap** | Standard SV trap rotation |
| X-4 | SV Hunter | **Mongoose Bite** (melee) | Melee gap — competitors handle better |
| X-5 | Frost Mage | **Summon Water Elemental** (41-pt Frost talent) | Standard Frost cooldown |
| X-6 | Arcane Mage | **Icy Veins** (DPS cooldown) | Standard Arcane burn cooldown |
| X-7 | Arcane Mage | **Cold Snap** (resets IV) | Standard Arcane cooldown reset |
| X-8 | Destro Warlock | **Shadowburn** (execute) | Standard Destro execute

## Priority 3: Schema Gaps (settings used but no UI widget)

| # | Source | Setting | File | Default |
|---|--------|---------|------|---------|
| S-1 | Settings audit | `pvp_mode` | warrior/fury + arms | nil (no UI) |
| S-2 | Settings audit | `combat_blind_hp`, `combat_cloak_hp`, `combat_evasion_hp` | rogue/combat | 40, 20, 30 hidden |
| S-3 | Settings audit | `holy_crit_pct` | paladin/heal_helper | nil (no UI) |
| S-4 | Settings audit | `leveling_use_shadowform` | priest/leveling | true (no UI) |
| S-5 | Settings audit | `cat_shred_positional` | druid/cat | true (no UI) |

## Priority 4: Magic Numbers Needing Settings

| # | Source | File | Issue |
|---|--------|------|-------|
| N-1 | Settings audit | paladin/holy:84-93 | LOW_MANA_PCT=35, BOSS_HP_FLOOR=20, TANK_HEAL_TARGET_HP=92 all hardcoded |
| N-2 | Settings audit | warrior/arms | enemy_count thresholds inconsistent (2 vs 3) between cleave/WW/SS |
| N-3 | Settings audit | warrior/arms + fury | Multiple stance HP thresholds hardcoded (45, 50, 70, 25, 35) |
| N-4 | Settings audit | paladin/ret | 7+ mana thresholds hardcoded (12, 18, 25, 30, 35, 40, 75) |
| N-5 | Settings audit | druid/bear | Emergency HP floors: 28, 25, 15 hardcoded |

## Priority 5: Test Coverage Gaps

| # | Spec | File | Status |
|---|------|------|--------|
| T-1 | Hunter Beast Mastery | `bm_sylvanas.lua` | No dedicated test file |
| T-2 | Hunter Marksmanship | `mm_sylvanas.lua` | No dedicated test file |
| T-3 | Paladin Retribution | `ret_sylvanas.lua` | No dedicated test file |
| T-4 | Rogue Assassination | `ass_sylvanas.lua` | No dedicated test file |
| T-5 | Rogue Subtlety | `sub_sylvanas.lua` | No dedicated test file |
| T-6 | Shaman Enhancement | `enh_sylvanas.lua` | No dedicated test file |
| T-7 | Shaman Restoration | `resto_sylvanas.lua` | No dedicated test file |
| T-8 | Warlock Demonology | `demo_sylvanas.lua` | No dedicated test file |
| T-9 | Druid Restoration | `resto_sylvanas.lua` | No dedicated test file |
| T-10 | Hunter Survival | `sv_sylvanas.lua` | Only 1 test (minimal) |

## Priority 6: Core_sylvanas Infrastructure Issues

| # | Source | Issue | Severity | Fix |
|---|--------|-------|----------|-----|
| C-1 | core_sylvanas:5620 | `NS.get_spell_damage()` returns hardcoded 0 (called by 11 files) | HIGH | Remove or replace with `core.spell_book.get_spell_damage()` |
| C-2 | core_sylvanas:140 | `require("common/modules/settings_manager")` depends on host path config | HIGH | Add explicit `package.path` setup in main_sylvanas |
| C-3 | core_sylvanas:1115 | `NS.get_setting_cached()` is a no-op alias with no caching | MEDIUM | Remove or implement actual TTL cache |
| C-4 | core_sylvanas:3735+ | 6 exported NS functions never called by any spec (dead code) | MEDIUM | Remove from NS export |
| C-5 | core_sylvanas:3645 | `NS.GetEnemiesInRange()` no frame-level caching (called 18 files, scans every call) | MEDIUM | Add frame-scoped result cache |
| C-6 | core_sylvanas:2200 | Broken-API throttle buffer 0.15s on first cast creates 1.65s window for any spell | MEDIUM | Initialize `_max_throttle_` for each new spell ID |
| C-7 | core_sylvanas:202 | `_last_spell_cast` table grows indefinitely (memory leak) | LOW | Add periodic cleanup or LRU eviction |
| C-8 | core_sylvanas:1266 | `NS.spell_in_range()` is actually `NS.recent_spell_cast()` — misleading name | MEDIUM | Rename to match behavior or fix implementation |

## Verification
- `luac -p` on all modified files
- `lua EaxRotations/tests/run_rotation_tests.lua` — 110/110
- `lua EaxRotations/tests/run_leveling_tests.lua` — 11/11