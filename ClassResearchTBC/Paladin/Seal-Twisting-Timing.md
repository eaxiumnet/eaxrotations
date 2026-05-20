# Paladin Seal Twisting Timing

Sources: Wowhead/Wowhead comments for Seal of Blood, TBC Paladin theorycraft discussions, local Flux/Sonah seal twist state references, Warcraft Tavern Paladin seal/judgement overview.

## Exact Timing Facts

| Fact | Value |
|---|---:|
| Twist window | Final 0.4s before white swing impact |
| Required twist participant | Seal of Command must be one of the two seals |
| Judgement behavior | Consumes the active seal; coordinate with swing and Crusader Strike |
| Crusader Strike | Does not replace swing-timed twisting; it is its own cooldown action |
| Failure mode | Seal cast too early replaces the old seal; too late misses the swing |

## Basic Twist Sequence

1. Maintain the primary damage seal for the current ruleset, usually Seal of Blood / Seal of the Martyr where available.
2. Track main-hand swing timer to impact.
3. When swing remaining is `<= 0.4s` and `> latency safety floor`, cast the twist seal, commonly Seal of Command if Blood/Martyr is active.
4. Let the white swing land with both seal effects eligible.
5. After swing resolution, restore the primary seal before the next swing cycle if mana and GCD allow.
6. Use Judgement only when it will not consume the needed seal at the wrong point in the swing cycle.

## Automation Conditions

| Condition | Action |
|---|---|
| `swing_remaining > 0.4s` | Do not twist yet |
| `swing_remaining <= latency_floor` | Too late; skip twist to avoid wasting mana/GCD |
| `mana below twist floor` | Drop twisting; run simple seal/Judgement/Crusader Strike |
| `forbearance risk and Avenging Wrath planned` | Confirm no emergency bubble plan is needed |
| `movement or boss mechanic imminent` | Skip twist if swing contact is unlikely |
| `active seal will be judged` | Re-seal plan must be available before next swing |

## Suggested State Fields

- `active_seal_id`
- `primary_seal_id`
- `twist_seal_id`
- `swing_remaining`
- `latency_ms`
- `mana`
- `judgement_cd`
- `crusader_strike_cd`
- `gcd_remaining`
- `target_in_melee`
- `threat_safe`

## Guardrails

- Do not add Divine Storm, Seal of Vengeance assumptions for every faction/ruleset, Holy Power, or modern Hand spell names.
- Treat faction seal availability as data/config, not as a universal constant.
- If swing timer is unavailable, disable twisting and fall back to simple seal priority.
