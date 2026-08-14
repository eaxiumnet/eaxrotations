# TBC Warrior Protection — Parse Spec (Phase 2.2e)

- **Spec file:** `EaxRotations/classes/warrior/protection_sylvanas.lua`
- **Era:** TBC Classic Anniversary (2.5.5)
- **Last updated:** 2026-08-13 (Phase 2.2e guide-divergence resolution)
- **Campaign rule applied (§3.1):** conformance allows → promote; nothing pinned → promote.

## Pinned source

- **Conformance manifest:** `tools/apl_status.lua` entry `tbc/warrior/protection`
  (lines ~1197-1208), consumed identically by `tests/test_apl_conformance.lua`
  and the scorecard (`tools/spec_scorecard.lua`).
- **Upstream reference:** wowsims/tbc `sim/warrior/protection/rotation.go`
  `doRotation` dispatch order — `ShieldSlam -> Bloodthirst -> MortalStrike ->
  Revenge -> Shout -> ThunderClap -> DemoShout -> Devastate -> SunderArmor`
  (see the manifest comment; provenance policy in `tools/evidence/apl/SOURCES.md`).
  `Bloodthirst`/`MortalStrike` are arms/fury talents absent from the prot
  rotation and `Shout` (Battle Shout buff maintenance) is excluded — all three
  are honestly-documented exclusions, not silent drops.
- **Pin correction history:** the 2026-08-09 pin originally cited
  `sim/warrior_dps_rotation.go` and claimed "Revenge is not modeled by the sim"
  — wrong. Corrected to the dedicated protection dispatch, which DOES model
  Revenge; ThunderClap/DemoShout dispatch order was fixed in the file to match
  (pure order move, 2026-08-09).

## Priority order (strategies table, priority-first)

| # | Strategy | Notes |
|---|----------|-------|
| 1 | HealthPotion | hp <= 35, in combat, use_auto_potions |
| 2 | DamagePotion | should_burst |
| 3 | Healthstone | hp <= 28 |
| 4 | LastStand | hp <= threshold, in combat |
| 5 | ShieldWall | hp <= threshold, long-CD gate |
| 6 | ShieldBash | interrupt (InterruptManager) |
| 7 | Pummel | interrupt fallback |
| 8 | ShieldSlamPurge | PvP dispel |
| 9 | ShieldSlam | **pinned** (must precede Revenge) |
| 10 | **ShieldBlock** | **promoted above Revenge 2026-08-13 (see divergence)** |
| 11 | Revenge | **pinned** (after ShieldSlam, before ThunderClap) |
| 12 | Taunt | elite-only smart taunt |
| 13 | TauntSecondary | MockingBlow tab-cycle when Taunt on CD |
| 14 | MockingBlow | elite-only |
| 15 | ChallengingShout | 3+ enemies, elite-only |
| 16 | ThunderClap | **pinned** (after Revenge, before DemoralizingShout) |
| 17 | DemoralizingShout | **pinned** (after ThunderClap, before Devastate) |
| 18 | Devastate | **pinned** (after DemoralizingShout, before SunderArmor) |
| 19 | SunderArmor | **pinned** (last of the pinned chain) |
| 20 | Execute | sub-20%, no stance dance |
| 21 | BattleShout | buff upkeep |
| 22 | CommandingShout | opt-in (use_commanding_shout) |
| 23 | Cleave | 2+ targets, rage >= 70, swing-timer gate |
| 24 | HeroicStrike | rage >= 70, swing-timer gate |
| 25 | WhirlwindMulti | 2+ targets, Berserker stance only |
| 26 | SpellReflection | PvP, target casting |
| 27 | Disarm | PvP, class-gated, burst trigger |
| 28 | ConcussionBlow | PvP |
| 29 | Hamstring | PvP |
| 30 | Intercept | PvP |
| 31 | Intervene | group, ally hp <= 60, 25yd |
| 32 | BerserkerRage | fear/sap/incapacitate break |
| 33 | Bloodrage | pre-pull or rage-starved |
| 34 | VictoryRush | post-kill free threat |
| 35 | Rend | filler when SS/Revenge not up |
| 36 | IntimidatingShout | hp <= 50, 3+ enemies |
| 37 | RageDumpSafetyNet | rage >= 90 |
| 38 | StanceSwitch | StanceManager |

**Pinned subsequence** (enforced by `test_apl_conformance.lua` via
`apl.check_name_order` — relative order only, names absent from either list
impose no constraint):

```
ShieldSlam < Revenge < ThunderClap < DemoralizingShout < Devastate < SunderArmor
```

Everything else (defensives, potions, taunts, buffs, rage dump, stance switch,
and **ShieldBlock**) is unpinned and may move for guide-driven or behavioral
reasons without breaking conformance.

## Key thresholds

| Constant / setting | Value | Used by |
|---|---|---|
| `SUNDER_WINDOW` / `SUNDER_MAX_STACKS` | 3 s / 5 stacks | Sunder refresh |
| `HEROIC_STRIKE_RAGE_DUMP` | 70 rage | Cleave / HeroicStrike |
| `SHIELD_BLOCK_CD` | 5 s | ShieldBlock |
| `SHIELD_SLAM_CD` / `REVENGE_CD` | 6 s / 5 s | expected cooldowns |
| `DEMO_SHOUT_CD` / `THUNDERCLAP_CD` | 25 s / 4 s | debuff upkeep |
| `SHIELD_WALL_CD` | 1800 s | long-CD gate |
| `FINAL_STAND_CD` | 180 s | matches class table (spell 12975) |
| `prot_shield_block_incoming` | 1500 | ShieldBlock smart gate |
| `defensive_hp_threshold` | 35 solo / 50 group (`warrior_group_aware_defensives`) | LastStand / ShieldWall |
| `warrior_intervene_hp_threshold` | 60 | Intervene |
| `prot_tab_range` / `prot_tab_targeting` | 20 yd / on | threat scan |
| `prot_swing_timer` | on | HS/Cleave queue gating |
| Execute phase | target_hp <= 20 | Execute |

## Divergence + rationale (Phase 2.2e, 2026-08-13)

**Claim:** the guide promotes Shield Block ahead of Revenge; the file had
Revenge first.

**Pin check (as required by §6.2.2e):**
- `tools/apl_status.lua` `tbc/warrior/protection` `reference_names` = ShieldSlam,
  Revenge, ThunderClap, DemoralizingShout, Devastate, SunderArmor — **ShieldBlock
  is NOT in the pin** (wowsims/tbc does not model Shield Block as a GCD).
- `apl.check_name_order` enforces only the RELATIVE order of names present in
  BOTH lists, so inserting ShieldBlock between ShieldSlam and Revenge leaves the
  pinned subsequence intact.
- `test_warrior_protection_dsl_priority.lua` pins only the DSL strategies
  (Healthstone < LastStand < ShieldWall < BattleShout < CommandingShout <
  BerserkerRage) — untouched by this move.
- `test_protection_feature_gaps.lua` is presence-only.
- The behavioral battery (`behavioral_audit.lua`) evaluates every strategy's
  matcher against each scenario independently (no first-match-wins dispatch), so
  a pure order move cannot change the never list (TBC never = 16 contract in
  `run_verify_all.lua` holds).

**Decision (§3.1):** conformance allows, promotion breaks no test → **PROMOTED**
ShieldBlock above Revenge (strategy table + `ACTIONS` metadata kept at 1:1 index
parity for `apply_base_matches`). File:line evidence: strategies table
`ShieldBlock` entry now precedes `Revenge` (was Revenge @ old ~1106, ShieldBlock
@ old ~1112; header WHAT/WHY updated in the same edit).

**Why the smart gate is sound (evidence):** the ShieldBlock matcher skips the
cast while the buff has > 2 s remaining AND `incoming_damage(me, 2.0)` is below
`prot_shield_block_incoming` (default 1500). When Shield Block is on CD or
already up, the matcher returns false and Revenge fires — so the promotion only
changes the GCD when Shield Block is ready AND (buff down OR heavy incoming),
which is exactly the mitigation-over-threat behavior the guide asks for, without
ever delaying threat output for a redundant Shield Block.

**Resulting threat-gen core order:** ShieldSlam -> ShieldBlock -> Revenge ->
Taunt lanes -> ThunderClap -> DemoralizingShout -> Devastate -> SunderArmor.

## Verification

- `luac -p EaxRotations/classes/warrior/protection_sylvanas.lua` — clean.
- `lua EaxRotations/tests/behavioral_audit.lua` — warrior/protection
  `strategies=38 never-fires=0` before AND after the move; TBC total never
  unchanged (16, pinned by `run_verify_all.lua`).
- `lua EaxRotations/tests/run_rotation_tests.lua --quiet` — green (includes
  `test_apl_conformance.lua`, `test_warrior_protection_dsl_priority.lua`,
  `test_protection_feature_gaps.lua`, the protection regression pins).
- `lua EaxRotations/tests/run_leveling_tests.lua --quiet` — green.
- `lua EaxRotations/tests/run_wotlk_tests.lua --quiet` — green (WotLK
  protection pin `wotlk/warrior/protection` untouched).
- `lua EaxRotations/tests/run_verify_all.lua` — exit 0 (17 components,
  incl. sylvanas spell-ID audit — no IDs changed).
