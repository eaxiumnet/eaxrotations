# Warrior Fury Implementation Checklist

Last updated: 2026-05-20
Target files:
- `C:\newbot\scripts\EaxRotations\classes\warrior\fury_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\middleware_sylvanas.lua`

## Compared Research Requirements

| Requirement from Research.md | Current EaxRotations state | Decision | Evidence |
|---|---|---|---|
| Bloodthirst → Whirlwind → Execute (filler) → Heroic Strike (dump) | Present as BT #1, WW #2, Execute #3 | Present | `fury_sylvanas.lua:STRATEGY_SPECS` order; BT and WW actions verified |
| Rampage buff maintain; recast when stacks < 5 or buff about to fall off within 3s | Partial | Fixed | `rampage_matches`: default `min_stacks` changed from 3 to 5; added `rampage_remains <= 3` expiry check |
| Berserker Stance as primary DPS stance | Present | Present | `stance_matches` checks Berserker as default and for Execute phase |
| Execute phase sub-20% with rage threshold gating | Present | Present | `execute_matches` checks `is_execute_phase(target_hp, 20)` and rage |
| Death Wish and Recklessness as offensive cooldowns | Present | Present | `death_wish_matches`, `recklessness_matches` with heroism delay and HP gates |
| Battle Shout buff maintenance | Present | Present | `battle_shout_matches` with `BATTLE_SHOUT_BUFF` list check |
| Hamstring PvP slow, Intercept gap closer | Present | Present | `hamstring_matches`, `intercept_matches`, PvP-gated |
| Sunder Armor / Demoralizing Shout / Thunder Clap utility | Present | Present | `sunder_matches`, `demo_shout_matches`, `thunder_clap_matches` |
| Heroic Strike and Cleave rage dumps | Present | Present | `heroic_strike_matches` (threshold 30 rage), `cleave_matches` (2+ targets) |
| Victory Rush sustain | Present | Present | `victory_rush_matches` with HP gate |
| Rend bleed filler when high rage and core spells on CD | Present | Present | `rend_matches` with debuff refresh window and low priority |
| Bloodrage rage generation | Present | Present | `bloodrage_matches` with combat/OOC gating |
| Slam (no-cast-swing-timer) filler | Present | Present | `slam_matches` with `not_moving` check and rage gating |
| Pummel interrupt | Present | Present | `pummel_matches` with casting check and Berserker Stance requirement |
| Stance dance to Battle Stance for Overpower / Charge | Present | Present | `battle_stance_matches` detects Overpower proc and pre-pull Charge |
| Sweeping Strikes AoE burst (2+ targets) | Present | Present | `sweeping_strikes_matches` with enemy count and Berserker Stance |
| **Rampage spell IDs correct** | **Incorrect** | **Fixed** | `class_sylvanas.lua` had `{30055, 30058}` (Cleave/Thunder Clap IDs); corrected to `{29801, 30030, 30033}` per DB2 / VETTING_LOG / Research.md |
| DB2-verified spell IDs | Present after fix | Present | All IDs cross-checked against `Warrior/DB2-Spells.md`; Rampage fix applied |
| No forbidden WotLK abilities | N/A | N/A | No Titan's Grip, Heroic Throw, Shockwave, or Death Knight spells found |

## Changes Made

| Change | Files touched | Test/validation |
|---|---|---|
| Corrected Rampage spell IDs in class table | `class_sylvanas.lua` | `luac -p` passed (`class_sylvanas.lua`) |
| Raised Rampage `min_stacks` default from 3 to 5; added expires-<=3s recast | `fury_sylvanas.lua` | `luac -p` passed (`fury_sylvanas.lua`) |
| Verified no other Warrior class spells affected | `class_sylvanas.lua` manual review | IDs checked against DB2-Spells.md |

## Files Verified Syntax-Only

- `fury_sylvanas.lua` → `luac -p` passed
- `class_sylvanas.lua` → `luac -p` passed (after Rampage fix)
- `middleware_sylvanas.lua` → `luac -p` passed (not modified)
- `schema_sylvanas.lua` → `luac -p` passed (not modified)
