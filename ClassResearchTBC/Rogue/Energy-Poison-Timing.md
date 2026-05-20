# Rogue Energy, Finishers, and Poison Timing

Sources: Icy Veins Rogue DPS rotation guide, Warcraft Tavern Rogue rotation guides, local Rogue energy tick references.

## Core Timing

| Fact | Value |
|---|---:|
| Energy tick | 20 energy every 2.0s |
| Energy cap | 100 |
| Practical pooling warning | Avoid sitting near cap before an incoming tick |
| Combo point cap | 5 |

## Finisher State Machine

1. Keep Slice and Dice active unless the target dies before it pays off.
2. Use Rupture when the target can bleed and will live long enough.
3. Use Eviscerate when Rupture will not tick enough or target is bleed immune.
4. Use Expose Armor only if assigned and raid value beats personal finisher loss.
5. Pool energy before Kidney Shot, rupture refresh, or cooldown windows.

## Poison Rules

- Do not overwrite Rogue poisons with sharpening stones/oils.
- Poison immune targets require fallback builder/finisher logic, especially for Mutilate/Envenom style decisions.
- PvP poisons are matchup tools: Wound, Crippling, Mind-numbing, and Deadly/Instant choices must be configurable.
