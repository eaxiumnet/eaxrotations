# Shaman Elemental (TBC) — Parse Spec / Guide Divergence

Campaign: Phase 2.2a (top-tier parsing) — 2026-08-13.

## Pinned source

- wowsims/tbc elemental: the conformance manifest (`tools/apl_status.lua`
  entry `tbc/elemental`) pins the APL reference order; the TBC sim models
  Lightning Bolt / Chain Lightning / Flame Shock / totem lines only.
- Manifest pin is a reference-order pin — adding strategies is pin-safe
  (verified 2026-08-13); reordering the pinned chain is not.
- Order pins: `tests/test_elemental_dsl_priority.lua` (76 tests).

## Priority (live, 2026-08-13 — abridged around the divergence lanes)

```
... > ChainLightning (index 15) > ChainLightningSingleTarget (16, OPT-IN) >
FlameShock (17) > FlameShockMaintain (18, OPT-IN) > LightningBolt > ...
```

Both divergence lanes sit immediately after their base lane and before
LightningBolt — so when enabled they preempt the Lightning Bolt filler chain,
never the AoE Chain Lightning lane (the ST lane explicitly refuses when
`aoe_target_meets` passes, keeping multi-target owned by ChainLightning).

## Thresholds

| Action | Condition | Setting(s) |
|---|---|---|
| ChainLightning (base) | 3+ targets, not moving, mana tiers, cc/threat-safe | existing CL gates |
| ChainLightningSingleTarget | **setting ON**, in combat, 1 target only (`aoe_target_meets` false), ready, mana tiers | `elemental_cl_single_target` (default **false**) |
| FlameShock (base) | refresh at <= 1s (clip window), mana tiers | existing FS gates |
| FlameShockMaintain | **setting ON**, in combat, remains in the (1,3)s window, SP-gated (Phase 2.1 `player_spell_damage` aware — inert at 0) | `elemental_fs_maintain` (default **false**) |

## Divergence + resolution

- **Divergence:** the pinned wowsims TBC conventions are CL at 3+ targets and
  no Flame Shock maintenance on single target. The guide divergences (ST Chain
  Lightning for parse, Flame Shock maintain for shock uptime on ST) are
  deliberate deviations from the sim conventions.
- **Era note:** the brief's "Lava Burst guaranteed-crit synergy" rationale is
  **WotLK terminology — TBC 2.5.5 has no Lava Burst** (the APL manifest already
  records wowsims TBC elemental as LB/CL-only). The TBC value of
  `elemental_fs_maintain` is DoT uptime + shock management on single target;
  the Lava Burst synergy rationale applies only to a future WotLK mirror.
- **Resolution:** both divergences implemented as **opt-in settings, default
  OFF**. When off, each matcher's first statement returns false — byte
  equivalent to the pre-campaign behavior. `test_elemental_dsl_priority.lua`
  explicitly asserts OFF no-match for both lanes (:302, :323) plus the ST
  lane's AoE-gate exclusion (:311-312).
- **Setting that flips it:** `elemental_cl_single_target` (checkbox, default
  false) and `elemental_fs_maintain` (checkbox, default false) — schema
  `classes/shaman/schema_sylvanas.lua:193-194` (Elemental → Rotation & Mana).

## Battery status

- TBC behavioral battery: elemental never-fires = 0 (31 strategies). Scenarios
  `elem_cl_st` (setting flipped + single-target fight) and `elem_fs_maintain`
  (setting flipped + debuff in the (1,3)s window) keep both lanes
  battery-observable (opt-in pattern (a)). TBC total never = 16 (unchanged;
  identical 16-lane list).
