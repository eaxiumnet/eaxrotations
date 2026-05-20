# Niche Mechanics Timing Deep Dive

This file collects the mechanics that most often break TBC rotation code when they are treated as ordinary priority buttons. The class files linked below contain exact state machines and timing rules.

## Index

| Mechanic | File | Core timing |
|---|---|---|
| Feral powershifting | `../Druid/Powershifting-Timing.md` | Energy ticks every 2.0s; Cat GCD 1.0s; shifting into form uses 1.5s GCD; Furor + Wolfshead = 60 energy on entering Cat |
| Paladin seal twisting | `../Paladin/Seal-Twisting-Timing.md` | Cast twist seal inside the final 0.4s before the white swing lands |
| Shaman totem twisting | `../Shaman/Totem-Twisting-Timing.md` | Windfury weapon buff persists about 10.0s after Windfury Totem is replaced |
| Enhancement weapon sync | `../Shaman/Totem-Twisting-Timing.md` | Avoid off-hand/main-hand collision when Flurry/Windfury timing matters |
| Hunter shot timing | `../Hunter/Shot-Timing.md` | Do not start Steady Shot before Auto Shot fires; rotation depends on effective ranged speed |
| Warrior Slam timing | `../Warrior/Slam-Timing.md` | Slam immediately after white swing; never before the swing lands |
| Rogue energy and poison timing | `../Rogue/Energy-Poison-Timing.md` | Energy ticks in 20 energy / 2.0s chunks; pool before finishers |
| Warlock imp machine gun | `../Warlock/Imp-Machine-Gun-Timing.md` | Imp Firebolt 2.0s base, 1.5s with 2/2 Improved Firebolt, 1.0s pet GCD |
| Healing downrank timing | `Healing-Downrank-Timing.md` | Downrank only when the lower rank lands before the next lethal event |

## Automation Rule

If a mechanic depends on a swing timer, energy tick, aura pulse, pet cast, seal state, totem state, or downrank table, do not implement it as a flat priority action. It needs explicit state and timing checks.
