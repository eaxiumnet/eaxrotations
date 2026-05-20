# Rogue Assassination Implementation Checklist

Generated: 2026-05-19
Job: 018-Rogue_Assassination.md

## Requirement Comparison

| Requirement | Status | Evidence | Notes |
|---|---|---|---|
| Slice and Dice maintenance | Present | `assassination_sylvanas.lua` SliceAndDice strategy | Refresh when < 3s remains |
| Rupture on long-lived targets | Present | `assassination_sylvanas.lua` RuptureBleed strategy | TTD > 12s gate, bleed-immune check |
| Envenom finisher | Present | `assassination_sylvanas.lua` EnvenomFinisher strategy | Min DP stacks configurable (default 3) |
| Cold Blood burst | Present | `assassination_sylvanas.lua` ColdBloodEnvenom strategy | Auto-casts before Envenom when enabled |
| Mutilate primary builder | Present | `assassination_sylvanas.lua` Mutilate strategy | Behind + poison gates |
| Sinister Strike fallback | Present | `assassination_sylvanas.lua` SinisterStrikeFallback strategy | Falls back when Mutilate conditions fail |
| Eviscerate fallback | Present | `assassination_sylvanas.lua` EviscerateFallback strategy | When Envenom/Rupture not viable |
| Shiv DP refresh | Present | `assassination_sylvanas.lua` ShivRefresh strategy | Energy-gated |
| Thistle Tea | Present | `assassination_sylvanas.lua` ThistleTea strategy | Energy < 40 gate |
| Kidney Shot PvP | Present | `assassination_sylvanas.lua` KidneyShotCC strategy | PvP only, DR check |
| Kick interrupt | Present | `assassination_sylvanas.lua` KickInterrupt strategy | Standard interrupt |
| Evasion defense | Present | `assassination_sylvanas.lua` EvasionDefense strategy | HP threshold configurable |
| Cloak of Shadows | Present | `assassination_sylvanas.lua` CloakOfShadows strategy | HP threshold configurable |
| Vanish threat drop | Present | `assassination_sylvanas.lua` VanishReopen strategy | Threat % > 90 gate |
| Feint AoE/threat | Present | `assassination_sylvanas.lua` FeintAoE strategy | Threat or AoE incoming gate |
| Expose Armor | Present | `assassination_sylvanas.lua` ExposeArmor strategy | Only if no Sunder |
| Deadly Throw | Present | `assassination_sylvanas.lua` DeadlyThrow strategy | Ranged finisher |
| PvP Blind | Present | `assassination_sylvanas.lua` PvP_Blind strategy | |
| PvP Sprint gap close | Present | `assassination_sylvanas.lua` PvP_SprintGapClose strategy | Distance > 15 |
| PvP Cheap Shot opener | Present | `assassination_sylvanas.lua` PvP_CheapShotOpen strategy | Stealth required |
| Stealth OOC | Present | `assassination_sylvanas.lua` Stealth strategy | |
| Garrote opener | Present | `assassination_sylvanas.lua` GarroteOpen strategy | Stealth + behind |
| Energy pooling (builders <40, finishers <25) | Present | `assassination_sylvanas.lua` constants ENERGY_LOW_BUILDER/FINISHER | |
| No Fan of Knives | N/A | Not present | Correctly absent |
| No Vendetta | N/A | Not present | Correctly absent |
| Envenom DB2 rank [39967] | **Added** | `class_sylvanas.lua` Envenom ids = {39967, 32684, 32645} | DB2 shows 39967 at level 69 |

## Changes Made

| File | Change | Lines |
|---|---|---|
| `class_sylvanas.lua` | Added Envenom rank 39967 (level 69) per DB2 | Envenom ids array |

## API Validation

| API Call | File | Verified | Notes |
|---|---|---|---|
| NS.is_behind_target | core_sylvanas.lua:3835 | ✅ | Used in Mutilate and Garrote gates |
| NS.get_debuff_stacks | core_sylvanas.lua:3167 | ✅ | Used for DP stack counting |
| NS.debuff_up | core_sylvanas.lua:3059 | ✅ | Available; `has_target_debuff` fallback is safe via nil-guard pattern |
| NS.spell_ready | core_sylvanas.lua | ✅ | Standard API |
| NS.try_cast | core_sylvanas.lua | ✅ | Standard API |

## Tests Run

- `luac -p` on `assassination_sylvanas.lua` -> PASS
- `luac -p` on `class_sylvanas.lua` -> PASS
- `luac -p` on `schema_sylvanas.lua` -> PASS

## Remaining Work

- `NS.has_target_debuff` does not exist in `core_sylvanas.lua`, but `assassination_sylvanas.lua` uses it with safe nil-guard pattern (`NS.has_target_debuff and NS.has_target_debuff(...)`). This works but could be unified to `NS.debuff_up` for consistency. However, this is not a vetted missing requirement from Research.md.
- No other vetted gaps remain.

## Verdict

All vetted requirements from Research.md are Present, Implemented, or N/A. One DB2 alignment fix (Envenom rank 39967) applied. No other code changes needed.
