# EaxRotations API Boundary

Last reviewed: 2026-04-27

## Contract

EaxRotations is a Project Sylvanas addon. The allowed runtime surface is:

- `api/`: Project Sylvanas runtime mirror.
- `apidocs/`: Project Sylvanas documentation mirror.
- `EaxRotations/core_sylvanas.lua`: project-owned `NS.*` API boundary.

Class and spec modules should consume `NS.*` helpers. If a lower-level Project
Sylvanas call is needed, add or reuse a wrapper in `core_sylvanas.lua` instead
of spreading raw runtime calls through class files.

## Runtime Rules

| Need | EaxRotations path |
| --- | --- |
| Spell creation | `NS.CreateSpell` |
| Spell readiness | `NS.spell_exists`, `NS.spell_ready` |
| Player and target units | `NS.GetPlayer`, `NS.GetTarget` |
| Settings | `context.settings`, `NS.get_setting`, `NS.set_setting` |
| Enemy scans | `context.enemies`, `NS.GetEnemiesInRange`, `NS.GetEnemiesCount` |
| Casting | `NS.try_cast`, `NS.try_cast_fmt`, `NS.try_heal_cast` |
| UI windows | EaxRotations window IDs and Eax-branded labels |
| Time | `NS.time_now` |

## Branding Rules

- Customer-facing window titles, menu headers, logs, exported metadata, and
  plugin metadata use EaxRotations or Eax branding.
- Project Sylvanas can be mentioned only as the runtime/API, not as product
  ownership or user-facing addon brand.
- Unrelated framework names should not appear in EaxRotations docs, comments,
  customer windows, or runtime logs.

## Follow-Up Candidates

These are normal EaxRotations maintenance items:

| Area | Candidate |
| --- | --- |
| Schemas | Expose more fine-grained class settings where it improves UX. |
| Healing specs | Keep rank selection and overheal logic validated against live Project Sylvanas object methods. |
| Warrior swing logic | Preserve the local swing-helper abstractions and test high-risk timing gates. |
