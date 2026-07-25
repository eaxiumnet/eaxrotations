# EaxRotations v2.16.0 Release Notes

**Release Date**: 2026-07-25
**Game**: The Burning Crusade Classic (2.5.5.x)
**Test Suite**: 390 rotation + 31 leveling (421 total) — all green

## Menu Collapsibility Fix

The Project Sylvanas menu rework broke section-level `tree_node:render()` at depth-2 — sibling section trees merged so all class settings widgets dumped into the last one rendered ("Auto Consumables has everything").

**Fix**: Section trees now render at depth-1 (directly inside `main_tree`) with a "Class Settings" header label for visual grouping. Each category (Rotation, Bear Tank, Cat DPS, Balance, Restoration, Auto Consumables, Leveling) is now its own individually collapsible fold-out with working arrows.

## Bug Fixes

### Feral Cat Rip Now Fires (Combo Points Fix)

**Affected**: Druid Cat + Druid Leveling (all feral playstyles)

Combo points were always reading `0`, so Rip never cast and Claw spammed endlessly (6+ Claws in a row on the same target without hitting the CP cap).

Three chained bugs:
1. **Dispatcher** (`main_sylvanas.lua`): `combo_points(me)` returned `0` on failure — indistinguishable from genuine zero CP.
2. **`get_combo_points` helpers** (cat + leveling): `if type(context.combo_points) == "number"` early-return treated `0` as valid, blocking the fallback chain.
3. **Non-existent method**: Fallback called `me.get_combo_points()` which doesn't exist in the API.

**Fix**: Dispatcher returns `nil` on failure (activates fallback chains). Helpers use `me:combo_points_current()` (IZI SDK) + `me:get_power(4)` (native, power type 4) as fallback. Rip now fires at 4+ CP (leveling) / 5 CP (cat).

### Auto Prowl Toggle Now Works

**Affected**: Druid Leveling rotation

The leveling rotation's `prowl_opener_matches` never checked the `cat_auto_prowl` setting — it cast Prowl whenever ready and OOC near a target. Disabling "Auto Prowl OOC" in the menu did nothing.

**Fix**: Added `spec_kit.setting_bool(context, "cat_auto_prowl", true)` gate to `prowl_opener_matches`.

## New Features

### Auto Taunt Toggle (Bear Druid + Protection Paladin)

Added `auto_taunt` checkbox (default on) to druid and paladin schemas:
- **Bear Druid**: Gates Growl and Challenging Roar
- **Protection Paladin**: Gates Righteous Defense

Disable to save taunt abilities for manual use.

### Auto Prowl Toggle (Druid)

Added `cat_auto_prowl` checkbox (default on) to druid schema. Controls the ProwlOpener strategy in both cat and leveling rotations.

### Additional CC Awareness (IZI SDK)

`is_cc()` checks added to prevent wasting CC on already-controlled targets:
- **Druid Balance**: Entangling Roots, Cyclone
- **Priest Shadow**: Psychic Scream (AoE fear)
- **Warlock Demonology + Destruction**: Fear
- **Rogue Assassination**: Blind
- **Paladin Retribution**: Repentance, Hammer of Justice

## Documentation

- **AGENTS.md**: Updated `apidocs/` references with rebuilt documentation mirror table (✓/✗ indicators)
- **Plan**: Created `plans/migrate-to-declarative-menu-2026-07-25.md` — plan for future migration to declarative `_G.menu` API for proper nested collapsibility

## Technical

- `luac -p` clean on all modified files
- 390/390 rotation + 31/31 leveling test suites pass (421 total)
- 34 files modified
- All changes backward-compatible: new settings default to previous behavior
- Clean `eaxrotations.zip` (lua + md only)

## Upgrade Instructions

1. Delete your existing `EaxRotations` folder
2. Extract the new `eaxrotations.zip` contents
3. All settings carry over automatically — no reset needed
4. Reload UI
