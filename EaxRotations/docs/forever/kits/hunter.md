# Hunter — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches hunters:
- Merged ranged hit/crit: the dead-zone + miss-table assumptions in
  `hunter_core_sylvanas.lua` simplify (merged hit applies to ranged).
- Human Hunter is a new combo; Skyborne can be Hunters (both factions).
- Weapon-skill values lowered on items.
- Pet system: watch for pet-ability rank changes (pet ladders are a
  perennial audit source — pet ladders in Forever must resolve in the DBC).

Watch for in the reveal: aspect economy, trap/shot tuning, pet families,
focus regen, Aimed Shot/Multi-Shot ranks at 60.

Spec deltas to author post-reveal: `beast_mastery_forever.lua`,
`marksmanship_forever.lua`, `survival_forever.lua`, `leveling_forever.lua`.
