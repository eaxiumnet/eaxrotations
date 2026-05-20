# Warrior Protection Implementation Checklist

Last updated: 2026-05-20
Target files:
- `C:\newbot\scripts\EaxRotations\classes\warrior\protection_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua`
- `C:\newbot\scripts\EaxRotations\classes\warrior\middleware_sylvanas.lua`

## Compared Research Requirements

| Requirement from Research.md | Current EaxRotations state | Decision | Evidence |
|---|---|---|---|
| Single-target priority: Shield Slam on CD → Revenge → Devastate/Sunder filler → HS dump | Present | Present | `protection_sylvanas.lua` strategies: Shield Slam (#1 threat), Revenge (#2), Sunder (#4), Devastate (#4), Execute (#5), HS (#9 rage dump) |
| **Shield Block uptime — survival critical** | **Present but late** | **Fixed** | Was in section 7 (after debuffs/AoE). Moved to right after Revenge with proactive `sb_remains < 2` refresh check to prevent crush vulnerability windows. |
| Shield Slam priority — core snap threat, must not be delayed | Present | Present | Strategy order confirms Shield Slam is #1 threat gen after interrupts and defensives. Matches research priority. |
| Sunder stack maintenance (5-stack armor debuff) | Present | Present | `sunder_matches_fn`: triggers when `sunder_stacks < 5` OR `sunder_remains <= 3`, gated behind SS/Revenge not being up. |
| Thunder Clap and Demoralizing Shout maintenance | Present | Present | `thunderclap_matches_fn` (2+ targets), `demo_shout_matches_fn` (remains <= 5). |
| Last Stand / Shield Wall defensive thresholds | Present | Present | Emergency `hp <= 35%` gate; `last_stand_matches_fn`, `shield_wall_matches_fn`. |
| Taunt / Mocking Blow / Challenging Shout threat recovery | Present | Present | `taunt_matches_fn` (2+ enemies), `mocking_blow_matches_fn` (2+ enemies), `challenging_shout_matches_fn` (3+ enemies). |
| Spell Reflection PvP | Present | Present | `spell_reflect_matches_fn` with PvP + target casting gates. |
| Disarm, Concussion Blow PvP | Present | Present | PvP-gated in strategies. |
| Intercept, Hamstring PvP mobility | Present | Present | PvP-gated in strategies. |
| Berserker Rage fear break | Present | Present | Strategy entry with Berserker Stance requirement. |
| Commanding Shout [469] — valid TBC spell; maintain if assigned | Partial | Fixed | Added `setting(context, "use_commanding_shout", false)` guard to `commanding_shout_matches_fn`; aligns with Arms class pattern (also uses this setting) |
| Bloodrage pre-pull / rage-starved | Present | Present | `bloodrage_matches_fn`: OOC for pre-pull, or in-combat if rage < 10. |
| Victory Rush sustain | Present | Present | `victory_rush_matches_fn` with HP gate. |
| Rend bleed filler when SS/Revenge on CD | Present | Present | `rend_matches_fn` with low priority and debuff refresh window. |
| Intimidating Shout emergency (3+ enemies, HP < 50%) | Present | Present | Low-priority defensive. |
| Execute phase sub-20% | Present | Present | `execute_matches_fn` gated on `is_execute_phase`. |
| Defensive Stance enforcement for tanking | Present | Present | `is_defensive_stance` checks in SS, Revenge, Sunder, Devastate, Shield Block; `try_cast_aware` enforces stance swap with rage check. |
| DB2-verified spell IDs | Present | Present | All IDs cross-checked against `Warrior/DB2-Spells.md`. |
| No forbidden WotLK abilities | N/A | N/A | No Shockwave, Heroic Throw, Sword and Board proc, or Death Knight spells found. |

## Changes Made

| Change | Files touched | Test/validation |
|---|---|---|
| Reordered Shield Block priority — moved from section 7 (after debuffs) to section 4 (right after Revenge) | `protection_sylvanas.lua` | `luac -p` passed |
| Added proactive `sb_remains < 2` refresh check to Shield Block `matches` to prevent crush vulnerability windows | `protection_sylvanas.lua` | `luac -p` passed; logic matches Research.md failure-case table |
| Removed duplicate ShieldBlock entry from old section 7 | `protection_sylvanas.lua` | Verified `grep "name = \"ShieldBlock\""` returns exactly 1 match |
| Added `use_commanding_shout` setting-gate to Commanding Shout cast | `protection_sylvanas.lua` | `luac -p` passed; matches Arms class pattern |
| Added `COMMANDING_SHOUT_BUFF` tracking; mutual exclusion between Battle Shout and Commanding Shout | `protection_sylvanas.lua` | `luac -p` passed |

## Files Verified Syntax-Only

- `protection_sylvanas.lua` → `luac -p` passed (after Shield Block reorder)
- `class_sylvanas.lua` → `luac -p` passed (not modified for this job)
- `middleware_sylvanas.lua` → `luac -p` passed (not modified for this job)
- `schema_sylvanas.lua` → `luac -p` passed (not modified for this job)
