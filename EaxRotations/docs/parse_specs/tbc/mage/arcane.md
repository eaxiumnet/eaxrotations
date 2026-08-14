# Mage Arcane (TBC) — Parse Spec / Guide Divergence

Campaign: Phase 2.2h (top-tier parsing) — 2026-08-13.

## Pinned source

- wowsims/tbc `sim/mage/rotations.go` (manifest `tools/apl_status.lua` entry
  `tbc/arcane`, `go_ref = sim/mage/rotations.go`).
- Manifest pin: `reference_names = { "ArcaneBlast", "FrostboltConserve",
  "ArcaneMissiles" }` — conformance covers only ArcaneBlast-before-
  FrostboltConserve-before-ArcaneMissiles. Evocation and ManaGem are NOT
  pinned, so their position above the fillers is free.

## Priority (live, unchanged — already conformant)

```
IceBarrier > IceBlock > ColdSnap > Blink > ManaShield > Healthstone >
Polymorph > FrostNova > Slow > PresenceOfMind > ArcanePower > IcyVeins >
ColdSnapIVReset > Evocation > ManaGem > ArcaneBlast > FireBlastExecute >
FireBlast > FrostboltConserve > ArcaneMissiles > FireballLeveling >
FrostboltLeveling
```

Guide chain (burn/conserve state machine): burst CDs → Evocation / ManaGem
(mana sustain) → ArcaneBlast (primary nuke) → FireBlast (instant filler /
execute) → FrostboltConserve (AB3-maintenance filler) → ArcaneMissiles
(Clearcasting consumer only). The `tbc/arcane` conformance pin
(`ArcaneBlast < FrostboltConserve < ArcaneMissiles`) is satisfied.

## Thresholds

| Action | Condition | Setting(s) |
|---|---|---|
| Evocation | in combat, ready, AP+IV inactive, mana <= 20% (or conserve phase <= 30%) | `arcane_evocation_mana` (20) |
| ManaGem | gem ready, mana gap (gem restore + regen < max) or mana <= 55% | `arcane_mana_gem_mana` (55) |
| ArcaneBlast | phase-gated stack limits (burn default 4, conserve 3) | `arcane_burn_max_stacks` (3 UI / 4 code default), `arcane_conserve_max_stacks` |
| FrostboltConserve | conserve phase, AB stacks >= 3, buff remains > cast time | — |
| ArcaneMissiles | Clearcasting proc, or emergency (< 10% mana) | — |

Evocation threshold matches wowsims: `manaThreshold = MaxMana * 0.2`
(`sim/mage/evocation.go`); conserve phase entry/exit 20%/30% matches
`StopRegenRotationPercent` / `StartRegenRotationPercent` family.

## Divergence + resolution

- **Divergence:** NONE. Evocation (index 14) and ManaGem (index 15) already sit
  ABOVE the fillers (ArcaneBlast index 16, FrostboltConserve index 19,
  ArcaneMissiles index 20) — the guide position was implemented before this
  campaign. Verified conformant; no change made.
- **Setting that flips it:** the lanes gate on `use_evocation` /
  `use_mana_gem` (schema General > Mana, default true) and their thresholds;
  disabling either restores filler-above-sustain behavior in effect.

## Battery status

- TBC behavioral battery: arcane never-fires = 0. TBC total never = 16
  (unchanged).
