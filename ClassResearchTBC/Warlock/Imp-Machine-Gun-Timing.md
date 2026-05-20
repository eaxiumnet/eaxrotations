# Warlock Imp Machine Gun Timing

Sources: DB2 `SpellMisc`, `SpellCastTimes`, `SpellCooldowns`, `SpellEffect`, Warcraft Wiki Firebolt page, classic/TBC community discussions, local Warlock research.

## DB2 Timing Facts

| Spell | Spell IDs | DB2 timing |
|---|---|---|
| Imp Firebolt | 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 | 2.0s base cast, 1.0s pet GCD, no recovery cooldown |
| Improved Firebolt rank 1 | 18126 | DB2 effect base around -251 ms; practical reduction is about 0.25s |
| Improved Firebolt rank 2 | 18127 | DB2 effect base around -501 ms; practical reduction is about 0.5s |
| Improved Imp ranks | 18694, 18695, 18696 | Increases Imp Firebolt/Fire Shield/Blood Pact effect by 10/20/30%, not cast speed |

## What "Machine Gun Imp" Means In TBC Terms

It is not a hidden 1.0s Firebolt loop from Improved Imp. The DB2-backed model is:

1. Imp Firebolt has a 2.0s cast time.
2. 2/2 Improved Firebolt reduces Firebolt by about 0.5s.
3. The resulting practical Firebolt cast is about 1.5s.
4. The pet GCD is 1.0s, so the Imp is cast-time limited at 1.5s, not GCD-limited.
5. Improved Imp increases effect/damage/Blood Pact style value, not the firing cadence.

## Automation Conditions

| Condition | Action |
|---|---|
| Imp active, target valid, Firebolt autocast enabled | Let Imp chain-cast Firebolt |
| Pet out of range or line of sight | Move/reposition pet or accept downtime |
| Target reflect/immunity/fire resistance issue | Consider pet passive/hold if Firebolt is harmful or useless |
| Threat-sensitive pull | Delay pet attack until tank threat exists |
| Raid needs Blood Pact | Keep Imp alive and in range; do not sacrifice/swap pet casually |

## Implementation Fields

- `pet_active`
- `pet_type_imp`
- `pet_casting_firebolt`
- `pet_firebolt_cast_remaining`
- `pet_gcd_remaining`
- `improved_firebolt_rank`
- `improved_imp_rank`
- `pet_target_valid`
- `pet_los_or_range_ok`

## Guardrails

- Do not import Wrath/Cata Empowered Imp, Demonic Empowerment, or modern pet scaling behavior.
- Do not call the 2/2 Improved Firebolt cadence 1.0s unless a branch-specific runtime test proves DB2 is wrong.
