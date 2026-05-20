# Shaman Totem Twisting, Imbues, and Weapon Timing

Sources: Wowhead Enhancement rotation guide, Icy Veins Enhancement guide, Warcraft Tavern Shaman totems and Enhancement guides, CurseForge TotemTwistTimer description, local Sonah/Flux totem references.

## Exact Totem-Twist Timing Facts

| Fact | Value |
|---|---:|
| Windfury Totem weapon buff persistence | About 10.0s after Windfury Totem is replaced |
| Totem cast cadence | One totem per GCD |
| Standard twist pair | Windfury Totem -> Grace of Air Totem |
| Safe refresh habit | Re-drop Windfury before 10.0s expires, commonly around 8.0-9.0s |
| Cost | High mana and attention cost |

## Basic Twist Sequence

1. Drop Windfury Totem to apply the temporary weapon buff to the melee party.
2. Immediately after the GCD allows, drop Grace of Air Totem or the assigned second Air totem.
3. Track the Windfury weapon-buff timer on party members, not just the active totem object.
4. Before the Windfury buff expires, re-drop Windfury Totem.
5. Again replace with Grace of Air after the Windfury buff is applied.
6. Stop twisting if mana, movement, interrupts, grounding/tremor duty, or survival makes twisting lower value.

## Twist State Machine

| State | Condition | Action |
|---|---|---|
| `no_wf_buff` | melee group lacks Windfury buff | Drop Windfury Totem |
| `wf_buff_applied` | Windfury buff active and GCD free | Drop Grace of Air or assigned Air totem |
| `wf_buff_refresh_soon` | Windfury buff <= 2.0s remaining | Drop Windfury Totem |
| `mana_low` | mana below configured floor | Stop twisting; keep most important single totem |
| `utility_air_needed` | Grounding/Tremor-style emergency equivalent by element/assignment | Utility totem overrides twist |

## Enhancement Weapon Timing

- Keep weapon imbues active; do not overwrite them with stones/oils unless explicitly configured.
- Watch main-hand/off-hand swing timers. Weapon sync or stagger decisions affect Windfury and Flurry behavior.
- Warcraft Tavern notes the importance of swing display and avoiding badly timed simultaneous swings when Flurry/internal timing matters.
- Stormstrike and shocks should not starve the mana needed for totem twisting if twisting is assigned.

## Automation Inputs

- `active_air_totem`
- `party_windfury_buff_remains`
- `gcd_remaining`
- `mana`
- `twist_enabled`
- `melee_group_has_warrior_or_rogue`
- `grace_of_air_assignment`
- `grounding_or_utility_override`
- `mainhand_swing_remaining`
- `offhand_swing_remaining`

## Guardrails

- Do not add Wind Shear, Lava Burst, Riptide, Hex, Feral Spirit, Maelstrom Weapon, Lava Lash, or modern Fire Nova.
- Wrath of Air does not twist like Windfury/Grace; do not assume every totem aura persists after replacement.
