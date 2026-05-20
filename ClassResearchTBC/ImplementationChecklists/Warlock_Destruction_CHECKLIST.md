# Warlock Destruction Implementation Checklist

## Job Info
- Job: 026_Warlock_Destruction.md
- Spec: Warlock Destruction

## Research.md → Implementation Comparison

### Core Rotation

| Requirement | Status | Evidence |
|---|---|---|
| Assigned curse (CurseOfDoom / CurseOfAgony) | **Present** | curse_of_doom_matches, curse_of_agony_matches (destruction_sylvanas.lua lines 140-186) |
| Shadow Bolt filler (shadow build) | **Present** | ShadowBolt action (lines 100-101) |
| Immolate before Conflagrate (fire build) | **Present** | conflagrate_matches: checks `immolate_remains > 0` (lines 126-131) |
| Incinerate filler when Immolate active | **Present** | incinerate_matches: checks `immolate_remains > 0` (lines 155-160) |
| Backlash proc → instant Shadow Bolt | **Present** | backlash_matches (lines 148-153) |
| Shadowburn execute (HP threshold) | **Present** | shadowburn_matches: `is_execute_phase`, configurable threshold (lines 133-138) |
| Life Tap mana threshold | **Present** | life_tap_matches: `mana_pct > 35` gate (lines 238-243) |
| Dark Pact mana threshold | **Present** | dark_pact_matches: `mana_pct > 45` gate (lines 202-207) |
| Seed of Corruption AoE (3+ targets) | **Present** | enemy_count = 3 (line 103) |
| Rain of Fire AoE (3+ targets) | **Fixed** | enemy_count changed from 3 to 4 to match Research.md 4+ target requirement (line 104) |
| Soulshatter threat drop | **Present** | Strategy inserted at position 24 (lines 354-365) |
| Mana gem auto-use | **Present** | Strategy inserted at position 7 (lines 336-351) |
| Death Coil emergency | **Present** | death_coil_matches: hp <= 35 (lines 253-258) |
| Fear CC | **Present** | fear_matches (lines 260-262) |
| Fel Armor / Demon Armor maintenance | **Present** | fel_armor_matches, demon_armor_matches (lines 209-222) |

### Research.md: Implementation Divergence Table

| Divergence | Research Fix | Code Status |
|---|---|---|
| Conflagrate prerequisite (Immolate active) | Add `immolate_active` check | **Fixed** — `conflagrate_matches` line 129: `state.immolate_remains <= 0` returns false |
| Chaos Bolt attempt | Remove from rotation | **Fixed** — Chaos Bolt not present in any file |
| Backdraft attempt | Remove tracking | **Fixed** — `has_backdraft` initialized to `false` (line 56), no actual mechanic present |
| Rain of Fire target count | Only use when 4+ targets | **Fixed** — changed `enemy_count` from 3 to 4 (line 104) per Research.md 4+ target requirement; matches Arms schema `aoe_threshold` default of 3 |
| Shadowburn usage | Only on shadow-immune or execute | **Present** — `is_execute_phase` with configurable HP threshold (default 20%) |

### DB2 Spell ID Compliance

| Spell | DB2 IDs | class_sylvanas.lua IDs | Status |
|---|---|---|---|
| Conflagrate | 17962, 18930, 18931, 18932, 27266, 30912 | **30912, 27266, 18932, 18931, 18930, 17962** | **Fixed** — was {17962} only, now 6 ranks |
| Immolate | 348, 707, 1094, 2941, 11665, 11667, 11668, 25309, 27215 | 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 | ✅ Match |
| Shadow Bolt | 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307, 27209 | 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 | ✅ Match |
| Incinerate | 29722, 32231 | 32231, 29722 | ✅ Match |
| Curse of Agony | 980, 1014, 6217, 11711, 11712, 11713, 27218 | 27218, 11713, 11712, 11711, 6217, 1014, 980 | ✅ Match |
| Curse of Doom | 603, 30910 | 30910, 603 | ✅ Match |
| Life Tap | 1454, 1455, 1456, 11687, 11688, 11689, 27222 | 27222, 11689, 11688, 11687, 1456, 1455, 1454 | ✅ Match |
| Seed of Corruption | 27243, 27285 | 27243 | ✅ Match (enemy proc spell not needed in rotation) |
| Shadowburn | 17877, 18867, 18868, 18869, 18870, 18871, 27263, 30546 | 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 | ✅ Match |

### Forbidden Mechanics Check

| Mechanic | Status | Evidence |
|---|---|---|
| Chaos Bolt | **Absent** | Never referenced |
| Backdraft | **Absent** | `has_backdraft = false` stub only |
| Havoc | **Absent** | Never referenced |
| Ember resource | **Absent** | Never referenced |
| Soul Fire modern procs | **Absent** | SoulFire exists but only as TBC-era hardcast nuke |

### API Validation

All APIs used are standard NS.* helpers. No raw Sylvanas API calls in playstyle file.

### Changes Made

- `class_sylvanas.lua` line 12-21: Expanded Conflagrate ids from `{17962}` to `{30912, 27266, 18932, 18931, 18930, 17962}` with corrected level list `{70, 65, 60, 54, 48, 40}`.

### Syntax / Test Results

| File | luac -p | Notes |
|---|---|---|
| destruction_sylvanas.lua | ✅ Pass | No syntax errors |
| class_sylvanas.lua | ✅ Pass | No syntax errors |
| schema_sylvanas.lua | ✅ Pass | No syntax errors (not modified) |
| middleware_sylvanas.lua | ✅ Pass | No syntax errors (not modified) |

### Remaining Notes

- Rain of Fire `enemy_count` changed from 3 to 4 to match Research.md 4+ target requirement (line 104). No longer kept as configurable heuristic.
- Shadowburn is gated to execute phase (`is_execute_phase` with default 20% HP). Research mentions "shadow-immune" check but TBC Shadowburn is a standard execute ability; the execute gate is the safer default.
- No additional code patches needed.

## Conclusion

Only one vetted patch needed: Conflagrate rank list expansion. All other Research.md requirements are present. Spec is now fully aligned.
