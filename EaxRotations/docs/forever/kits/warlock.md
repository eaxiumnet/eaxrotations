# Warlock — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches warlocks:
- Merged spell hit/crit: curse/shadow spell hit math simplifies.
- Troll Warlock is a new combo (watch Berzerking-style racial actives).
- CC central in Forever dungeons (Banish named explicitly) —
  `has_breakable_cc_nearby` banish lanes stay relevant.
- Pet system: felhunter/succubus/voidwalker tuning watch (pet ladders must
  resolve in the Forever DBC).

Watch for in the reveal: shard economy (shard-gated spells), Life Tap tuning
(the repo's life_tap lanes), DoT refresh windows, curse slot policy (the
`warlock_curse_helper` single-curse rule), new 16-point milestone talents.

Spec deltas to author post-reveal: `affliction_forever.lua`,
`demonology_forever.lua`, `destruction_forever.lua`, `leveling_forever.lua`.
