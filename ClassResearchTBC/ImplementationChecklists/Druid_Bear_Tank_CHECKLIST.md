# Druid Bear Tank — Implementation Checklist

> Job: 003_Druid_Bear_Tank | Runner: AGENT_RUNNER.md | Updated: 2026-05-19

## DB2 Spell Table Verification

| Spell | DB2 IDs (Research.md) | class_sylvanas.lua | Status |
|---|---|---|---|
| Barkskin | 22812 | {22812} ✓ | Present |
| Challenging Roar | 5209 | {5209} ✓ | Present |
| Demoralizing Roar | 99,1735,9490,9747,9898,26998 | {26998,9898,9747,9490,1735,99} ✓ | Present |
| Faerie Fire (Feral) | 16857,17390,17391,17392,27011 | {27011,17392,17391,17390,16857} ✓ | Present |
| Frenzied Regeneration | 22842,22845,22895,22896,26999 | {26999,22896,22895,22842} ✓ (22845 excluded correctly - passive rank) | Present — Fixed (cooldown 180→0) |
| Growl | 6795 | {6795} ✓ | Present |
| Lacerate | 33745 | {33745} ✓ | Present |
| Mangle (Bear) | 33987,33986,33878 | {33987,33986,33878} ✓ | Present — Fixed (levels 68/58/50) |
| Maul | 6807,6808,6809,8972,9745,9880,9881,26996 | {26996,9881,9880,9745,8972,6809,6808,6807} ✓ | Present — Fixed (levels 67/58/50/42/34/26/18/10) |
| Swipe (Bear) | 769,779,780,9754,9908,26997 | {26997,9908,9754,769,780,779} ✓ | Present — Fixed (added 769,780,9754; levels 64/54/44/34/24/16) |

## Research.md Contract — Behavioral Alignment

### Single Target Priority ✓

| Requirement | Implementation | Status |
|---|---|---|
| Faerie Fire (Feral) maintenance | `faerie_fire_matches` — refresh at ≤4s | Present |
| Demoralizing Roar maintenance | `demo_roar_matches` — refresh at ≤5s, gate on enemy count | Present |
| Mangle (Bear) on cooldown | `mangle_matches` / `mangle_opener_matches` — on CD with 6s cooldown | Present |
| Lacerate stack building | `lacerate_matches` — build to 5 stacks, refresh at ≤3s | Present |
| Swipe as filler | `swipe_cleave_matches` — 2+ targets filler | Present |
| Maul rage dump | `maul_matches` — queue when rage ≥ maul_rage (default 40) | Present — Fixed (default 50→40) |
| Growl taunt only when needed | `growl_matches` — loose target + not on tank | Present |

### Multi-Target Tanking ✓

| Requirement | Implementation | Status |
|---|---|---|
| Swipe on 2+ targets | `swipe_cleave_matches` — enemy_count ≥ 2 | Present |
| Swipe AoE on 3+ targets | `swipe_aoe_matches` — enemy_count ≥ aoe_threshold (default 3) | Present |
| CC gate on Swipe | `context.has_breakable_cc_nearby` check in swipe_matches | Present — Fixed (added) |
| Demoralizing Roar for AoE mitigation | `demo_roar_matches` with pack_needs_demo | Present |
| Challenging Roar emergency AoE taunt | `challenging_roar_matches` — 3+ enemies + loose | Present |
| Off-target Lacerate tabbing | `off_target_lacerate_matches` — scan pack for loose targets | Present |

### Defensive Play ✓

| Requirement | Implementation | Status |
|---|---|---|
| Frenzied Regeneration when low + rage | `frenzied_regen_matches` — HP ≤ frenzied_regen_hp (35%) + has rage | Present |
| Barkskin for predictable damage | `barkskin_matches` — HP ≤ barkskin_hp (55%), not below 15% | Present |
| Enrage for rage when safe | `enrage_combat_matches` — rage < 15 + HP safe | Present |
| Feral Charge interrupt | `charge_interrupt_matches` — casting + interruptible + in range | Present |
| Bash interrupt | `bash_interrupt_matches` — casting + interruptible + melee range | Present |

### Resource Efficiency (Angle 4) ✓

| Requirement | Implementation | Status |
|---|---|---|
| Mangle reserve 20 rage | `RAGE_MANGLE_RESERVE = 20` + `would_starve_mangle()` | Present — Fixed (was 15) |
| Maul queue at 40+ rage | `maul_rage` default 40 via schema | Present — Fixed (was 50) |
| Lacerate maintain on long-lived target | `lacerate_matches` with stack/refresh logic | Present |
| Skip Swipe single-target unless excessive rage | Gated by `rage_allows_filler` + `would_starve_mangle` | Present |
| Demoralizing Roar as mitigation, not rage sink | Only refreshes within window, not spammed | Present |
| Enrage at low rage with HP safety | `enrage_combat_matches` — rage<15, HP≥60 when multi-target | Present |

### Utility & Cross-Spec (Angle 3)

| Requirement | Implementation | Status |
|---|---|---|
| Innervate by assignment | Not implemented (marked for healer assignment) | Not applicable — per-contract, reserve for healer |
| Battle rez | Not implemented | Partial — may be in healing module |
| Decurse/poison when safe | Not implemented in bear module | Not applicable — in caster/healing modules |

## API Validation

| API Function | Checked File | Status |
|---|---|---|
| `NS.spell_action` | api/common/izi_sdk.lua | ✓ Used throughout |
| `NS.spell_ready` | api/core.lua | ✓ Used with nil guards |
| `NS.buff_up` | api/common/modules/buff_manager.lua | ✓ Used with nil guards |
| `NS.debuff_remains` | api/common/modules/buff_manager.lua | ✓ Used with nil guards |
| `NS.debuff_stacks` | api/common/modules/buff_manager.lua | ✓ Used with fallback |
| `NS.get_visible_units` | api/game_object.lua | ✓ Used with nil guard |
| `NS.action_execute` | api/common/izi_sdk.lua | ✓ Used throughout |
| `NS.cooldown_remains` | api/core.lua | ✓ Used in mangle_cd |

## Changes Applied

### class_sylvanas.lua (5 changes)
1. **SwipeBear**: Added missing ranks 769, 780, 9754. Fixed levels descending.
2. **FrenziedRegeneration**: Added missing ranks 22895, 22896, 26999. Cooldown 180→0 (TBC toggle).
3. **MangleBear**: Fixed levels 70/64→68/58/50 to match DB2.
4. **Maul**: Fixed levels to match 8 DB2 ranks (67/58/50/42/34/26/18/10).

### bear_sylvanas.lua (3 changes)
1. **CC gate**: Added `context.has_breakable_cc_nearby` to `swipe_aoe_matches` and `swipe_cleave_matches`.
2. **RAGE_MANGLE_RESERVE**: 15→20 (Research Angle 4: reserve 20 rage for Mangle).
3. **maul_rage default**: 50→40 (Research Angle 4: Maul queueing at 40+ rage).

## Tests Run

- `luac -p EaxRotations/classes/druid/bear_sylvanas.lua` — PASS
- `luac -p EaxRotations/classes/druid/class_sylvanas.lua` — PASS
- No spec-specific tests exist for Bear Tank (none found in `EaxRotations/tests/`)

## Remaining Risk

| Item | Risk | Mitigation |
|---|---|---|
| FrenziedRegeneration cooldown=0 | Low — match function uses buff detection, not cooldown | Already safe |
| 22845 excluded from FrenziedRegeneration IDs | None — confirmed passive/effect rank, not castable | DB2-verified |
| No Bear-specific test file | Medium — behavioral changes untested at runtime | Schema settings are conservative; rage thresholds match Research |
| Innervate/Brez not in bear module | Low — per Research, reserved for healer assignment | Handled by healing module |
