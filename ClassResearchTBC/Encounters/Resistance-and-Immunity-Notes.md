# Resistance and Immunity Notes

## Rotation Impact

| Resistance/immunity case | Required documentation behavior |
|---|---|
| School-resistant boss | Mark affected class/spec and list fallback school or physical action |
| Demon/undead target | List Paladin/Priest/Warlock utility that becomes available |
| Bleed immune target | Rogue/Feral/Warrior bleed finishers become lower priority |
| Poison immune target | Rogue poison/Mutilate/Envenom logic needs fallback |
| Fire immune/resistant target | Fire Mage/Destruction Warlock/Elemental fire shock/totem rules need fallback |
| Frost immune/resistant target | Frost Mage control/damage rules need fallback |
| Nature resistant target | Balance/Shaman nature spell value changes |
| Shadow resistant target | Shadow Priest/Warlock priority and curse assignments change |

## S+ Implementation Checks

- Every spec should have a `target_resists_primary_school` or equivalent note before hard-coded spell priority.
- Every bleed/poison spec should state fallback finisher/builder logic.
- Encounter docs should record known resistance fights as they are researched.
- Do not infer immunity from creature type alone unless a source or local DB confirms it.
