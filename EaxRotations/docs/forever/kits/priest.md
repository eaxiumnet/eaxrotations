# Priest — WoW Forever kit (awaiting reveal)

> SAFETY: no IDs until the Forever DBC lands (docs/forever/dbc_runbook.md).

Status: **kit not yet revealed** (post-2026-09-13 per-class reveals pending).

What we know era-wide that touches priests:
- **Divine Spirit baseline** (was a 31-pt Discipline talent) — the healing
  context gains free Spirit; Spirit-scaling lanes (healer mana math,
  `fsr_manager_sylvanas.lua`) inherit it.
- Merged spell hit/crit for Shadow.
- **Bonus healing grants ⅓ as spell damage** — Holy/Disc hybrid play gets
  real offensive output from healing gear.
- Gnome Priest is a new combo; watch racial interactions (Escape Artist-type
  actives vs Fear/Sleep kit).

Watch for in the reveal: Power Word: Shield mechanics (the repo's Pattern 12
absorb tracking), Prayer of Healing/FoL economy, Shadow Mana-return tuning,
new 16-point milestone talents.

Spec deltas to author post-reveal: `discipline_forever.lua`,
`holy_forever.lua`, `shadow_forever.lua`, `smite_forever.lua` (if smite priest
stays a distinct playstyle), `leveling_forever.lua`.
