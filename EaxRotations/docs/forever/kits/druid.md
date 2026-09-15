# Druid — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches druids:
- **Improved Mark of the Wild baseline** (was a deep Restoration talent) —
  the raid-buff context fields change for every druid spec.
- **Skyborne Druids** with custom druid forms (both factions) — new model
  forms; watch for form-spell ID changes in the DBC (form detection keys
  off spell IDs).
- Merged melee hit/crit (cat/bear) + merged spell hit/crit (caster/balance).
- Bonus healing → ⅓ spell damage also helps resto questing.

Watch for in the reveal: feral combo/energy economy, Bear threat tools (Growl
misses benefit from merged hit), Moonkin/Tree form tuning, Omen-of-Clarity-style
procs, new 16-point milestone talents per tree.

Spec deltas to author post-reveal: `balance_forever.lua`, `cat_forever.lua`,
`bear_forever.lua`, `caster_forever.lua`, `resto_forever.lua`,
`leveling_forever.lua`.
