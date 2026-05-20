# Druid Powershifting Timing

Sources: Warcraft Tavern Feral powershifting guide, Wowhead Feral DPS rotation guide, Wowhead TBC powershifting energy update, local Sonah/Flux swing and powershift references.

## Exact TBC Timing Facts

| Fact | Value |
|---|---:|
| Cat energy tick | 20 energy every 2.0s |
| Cat-form ability GCD | 1.0s |
| Shifting into Cat Form GCD | 1.5s |
| Leaving Cat Form | Does not start a GCD |
| Furor energy on Cat entry | 40 energy at 5/5 |
| Wolfshead Helm energy on Cat entry | 20 energy |
| Furor + Wolfshead Cat entry | 60 energy |

## 4-Second Cycle State Machine

1. Start near the end of a Cat cycle with energy low enough that waiting is worse than shifting.
2. Leave Cat Form. This does not start a GCD.
3. Re-enter Cat Form immediately. This starts the 1.5s form GCD and grants 60 energy with Furor + Wolfshead.
4. If the shift was timed roughly 1.0s into the 2.0s energy tick cycle, the next tick occurs during the form GCD and raises energy to about 80.
5. Cast Mangle/Shred/Rake/Rip action as soon as the 1.5s form GCD ends.
6. Wait for the next 2.0s energy tick if needed.
7. Cast the second Cat action after the energy tick.
8. As soon as that 1.0s Cat GCD ends and no mandatory finisher/refresh is pending, powershift again.

## Rotation Conditions

| Condition | Action |
|---|---|
| Mangle missing and target will live | Do not spend shift cycle on low-value filler; refresh Mangle |
| 4-5 combo points and Rip missing/expiring | Save energy/GCD for Rip |
| Energy below next useful action and mana safe | Powershift |
| Energy tick is less than 0.5s away and GCD free | Wait for tick rather than shifting if it enables immediate action |
| Mana below emergency threshold | Stop powershifting; preserve mana for forms/utility |
| Omen of Clarity active | Spend clearcast before shifting if a valid action is available |

## Automation Inputs

- `energy`
- `mana`
- `energy_tick_time_remaining`
- `gcd_remaining`
- `cat_form_active`
- `mangle_remains`
- `rip_remains`
- `combo_points`
- `clearcasting_active`
- `powershift_enabled`
- `wolfshead_equipped_or_configured`

## Guardrails

- Do not add Savage Roar, Berserk, Cat Swipe, or later-expansion energy logic.
- Do not powershift during GCD if the API cannot queue form entry safely.
- Do not powershift if the next global must be emergency Bear, decurse, battle rez, or survival.
