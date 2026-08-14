# Mage Fire (TBC) — Parse Spec / Guide Divergence

Campaign: Phase 2.2h (top-tier parsing) — 2026-08-13.

## Pinned source

- wowsims/tbc `sim/mage/rotations.go` + `sim/mage/evocation.go` (manifest
  `tools/apl_status.lua` entry `tbc/fire`, `go_ref = sim/mage/rotations.go`).
- Manifest pin: `reference_names = { "Scorch", "Fireball" }` — the conformance
  pin covers ONLY Scorch-before-Fireball. Evocation and ManaGem are NOT pinned,
  so their position is free (conformance allows the guide position).

## Priority (live, after 2026-08-13 resolution)

```
ManaPotion > IceBarrier > ManaShield > Healthstone > PresenceOfMind >
Combustion > Pyroblast > Scorch > Evocation > ManaGem > Fireball > FireBlast >
Flamestrike > FlamestrikeRank6 > ArcaneExplosion > Blizzard > BlastWave >
DragonsBreath > Polymorph > RemoveCurse > ManaGemConjure > HitCapPriority
```

Guide chain (single-target): Scorch (5-stack maintenance) → Evocation /
ManaGem (mana sustain) → Fireball (filler) → Fire Blast (instant filler /
moving). The `tbc/fire` conformance pin (`Scorch < Fireball`) is unaffected.

## Thresholds

| Action | Condition | Setting(s) |
|---|---|---|
| Scorch | stacks < 5 or remains <= 4s, not moving | `use_scorch_debuff` (default true) |
| Evocation | in combat, mana <= 20% | `use_evocation` (true), `evocation_mana_pct` (20) |
| ManaGem | in combat, gem ready, mana <= 70% | `use_mana_gem` (true), `mana_gem_mana_pct` (70) |
| Fireball | 5-stack Scorch duty satisfied, not moving | — |
| FireBlast | instant filler (moving or nothing else ready) | — |

Evocation threshold matches wowsims: `manaThreshold = MaxMana * 0.2`
(`sim/mage/evocation.go`).

## Divergence + resolution

- **Divergence (pre-2026-08-13):** Evocation (index 21) and ManaGem (index 20)
  sat BELOW the damage fillers — after Polymorph/RemoveCurse/ManaGemConjure —
  so at low mana the rotation kept hard-casting Fireball/FireBlast instead of
  recovering mana. The guide casts Evocation in combat at mana <= 20% max as a
  combat mana cooldown, i.e. it preempts the fillers.
- **Resolution:** §3.1 decision — conformance allows the move (not pinned) →
  MOVED Evocation + ManaGem above the fillers (indices 9/10, between Scorch and
  Fireball, mirroring arcane's Evocation-then-ManaGem order). No opt-in setting
  was needed. Test pins updated in `tests/test_fire_dsl_priority.lua`
  (Evocation == 9, ManaGem == 10, full `expected_order`).
- **Setting that flips it:** none — the position is unconditional. The LANES
  themselves are gated by `use_evocation` / `use_mana_gem` (default true) and
  their mana thresholds (`evocation_mana_pct`, `mana_gem_mana_pct`); setting
  `use_evocation = false` / `use_mana_gem = false` restores the old
  filler-above-sustain behavior in effect.
- **Known residual nuance (documented, NOT changed):** wowsims also skips
  Evocation during Bloodlust unless mana < ~10% and while blast spamming; the
  fire lane only checks mana <= 20%. Order divergence is resolved; this
  threshold nuance is out of scope for 2.2h.

## Battery status

- TBC behavioral battery: fire never-fires = 1 (`ManaGemConjure` — OOC conjure
  lane, pinned family; unchanged by the move). TBC total never = 16 (unchanged).
