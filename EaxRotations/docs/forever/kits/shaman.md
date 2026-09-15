# Shaman — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches shaman:
- **Dwarf Shaman** is a new combo; Skyborne Horde Shamans exist.
- Merged spell hit/crit (Elemental) + merged melee hit/crit (Enhancement).
- The paladin reveal showed seal-totem-style upkeep modernization — watch for
  totem economy changes (the repo's totem-twist lanes are the most
  maintenance-heavy shaman code).

Watch for in the reveal: totem drop timers/reach, Maelstrom Weapon-style
procs (if any), Shock CD family, Shield categories (the repo's
`shaman_enhancement_intelligent_shield` assumptions), new 16-point talents.

Spec deltas to author post-reveal: `elemental_forever.lua`,
`enhancement_forever.lua`, `restoration_forever.lua`, `leveling_forever.lua`.
