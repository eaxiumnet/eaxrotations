# Mage — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches mages:
- **Merged spell hit/crit**: spell hit cap math changes everywhere in
  `hit_cap_tracker_sylvanas.lua`/`combat_stats_sylvanas.lua` for casters.
- Orc Mage and Alliance Skyborne Mage are new combos.
- Bonus-healing→⅓-spell-damage does not affect mages directly, but caster
  WEAPONS now carry spell damage — level-up weapon upgrades become real
  (gear-score/stat assumptions shift).
- CC stays central in Forever dungeons (Polymorph named explicitly).

Watch for in the reveal: mana-gem/evocation economy, Clearcast procs,
Scorch/Fireball rank tuning at 60, new 16-point milestone talents, ward changes.

Spec deltas to author post-reveal: `arcane_forever.lua`, `fire_forever.lua`,
`frost_forever.lua`, `leveling_forever.lua`.
