# Hunter Shot Timing

Sources: Wowhead Hunter DPS rotation guide, TBC hunter rotation theorycraft tools, Hunter PvP guide examples, local Sonah swing timer references.

## Core Timing Rules

| Rule | Timing meaning |
|---|---|
| Auto Shot must not be clipped | Wait until Auto Shot actually fires before beginning Steady Shot |
| Steady Shot weave | Cast Steady Shot in the gap after Auto Shot |
| Kill Command | Off-GCD style reaction after crit/proc; use immediately when available |
| Multi-Shot | Higher-value than Steady in many cases, but can clip Auto or break CC |
| Effective weapon speed | Determines 1:1, 1:2, 1:3, 5:5:1:1/French-style rotations |

## Automation Conditions

- If `auto_shot_about_to_fire`, do not cast Steady/Multi/Aimed.
- If `auto_shot_fired` and `steady_fits_before_next_auto`, cast Steady Shot.
- If `multi_shot_ready` and `cc_safe` and it fits before next Auto, use Multi-Shot.
- If haste pushes effective speed too low, prefer Auto preservation over extra Steady casts.
- Pet Kill Command should not disrupt the shot timer.
