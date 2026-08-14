# Warlock Affliction (TBC) — Parse Spec / Guide Divergence

Campaign: Phase 2.2g (top-tier parsing) — 2026-08-13.

## Pinned source

- APL manifest (`tools/apl_status.lua` entry `tbc/affliction`):
  `reference_names = { "UnstableAffliction", "CorruptionDoT", "SiphonLife",
  "ImmolateDoT", "ShadowBoltFiller" }` — a relative-order pin. Adding
  strategies is pin-safe (verified 2026-08-13); reordering the pinned chain is
  not.
- Order pins: `tests/test_affliction_dsl_priority.lua` (Pet* < DeathCoil <
  Healthstone < NightfallProc chain pinned).

## Priority (live, 2026-08-13 — around the divergence lane)

```
... > NightfallProc > CurseFirst (OPT-IN) > UnstableAffliction > Corruption >
SiphonLife > ImmolateDoT > ... > (regular curse lanes below the DoTs) > ...
```

`CurseFirst` sits above ALL DoT setup lanes (UA/Corruption/Siphon/Immolate)
and above the regular curse lanes — when enabled, the opener applies the curse
before the DoT setup; when disabled the matcher's first statement returns
false and the lane is inert.

## Semantics

- **Opener ownership:** the lane owns the *curse fully absent* branch
  (combat-start opener + full falloff, e.g. after a dispel). Refresh windows
  stay with the regular curse lanes below the DoTs. No hidden `combat_time`
  timer — deterministic and battery-testable.
- **Curse selection unchanged:** `select_curse` respects `warlock_curse_mode` /
  `warlock_assigned_curse` / auto-TTD (returns nil for mode "none" and the
  PvP tongues/exhaustion picks). CoE goes first when configured as the raid
  curse; auto PvE stays agony/doom. Per-curse `min_ttd` sanity gates mirror
  the regular curse lanes verbatim (agony 8s, doom 62s) — the opt-in changes
  only ORDER, never selection.

## Thresholds

| Action | Condition | Setting(s) |
|---|---|---|
| CurseFirst | **setting ON**, in combat, valid enemy, curse fully absent (remains 0), no other curse active, per-curse min_ttd, spell ready | `aff_curse_first` (default **false**) |
| Regular curse lanes | refresh windows | `warlock_curse_mode` / `warlock_assigned_curse` |

## Divergence + resolution

- **Divergence:** the guide applies the curse (Curse of the Elements / Curse
  of Affliction) BEFORE the DoT setup on combat start — curse-first openers
  for parse, since the curse amplifies all shadow/fire damage from the first
  DoT tick.
- **Resolution:** implemented as an opt-in setting, default OFF, byte
  equivalent when off (first-statement gate; no pre-existing lane reordered).
  Rationale recorded: (a) delivers "curse before DoT setup" exactly at combat
  start (curse absent); (b) deterministic and battery-testable; (c) mid-fight
  full falloff re-applies the curse first, consistent with the amplification
  rationale; (d) per-curse TTD gates mirrored verbatim so only ORDER changes.
- **Setting that flips it:** `aff_curse_first` (checkbox, default false) —
  schema `classes/warlock/schema_sylvanas.lua:124` (Affliction → Damage, next
  to `aff_use_amplify_curse`).

## Battery status

- TBC behavioral battery: affliction never-fires = 0 (49 strategies). Scenario
  `aff_curse_first` (behavioral_audit.lua:2520 — setting flipped, auto curse
  mode at ttd 120 resolving to Doom) keeps the lane battery-observable
  (opt-in pattern (a)); curse mode deliberately left auto to protect the
  regular-curse `fires-in(1)` exclusivity pins in
  `tests/test_warlock_opt_in_regression.lua`. TBC total never = 16 (unchanged).
