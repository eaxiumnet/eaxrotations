# Dungeon and Heroic Modifiers

## Universal Dungeon Rules

| Situation | Rule | Affected roles |
|---|---|---|
| Unstable pull | Tank establishes position before DPS AoE | All DPS, tanks |
| CC-marked pack | No cleave/AoE that can break sheep, trap, sap, fear, banish, or repentance | All |
| Caster pack | Line-of-sight pull, interrupt healers/nukers, purge/dispels where useful | Tanks, melee, ranged |
| Runner mob | Snare/stun before low health; avoid pulling extra packs | Melee, hunters, mages, tanks |
| Healer mob | Interrupt or crowd-control; kill priority rises above normal skull if healing lands | All |
| Cleave/frontal mob | Tank faces away; melee avoid front; pets reposition | Tanks, melee, pet classes |
| Poison/disease/curse/magic pressure | Cleanse/remove by danger, not by first seen | Healers, hybrid utility |
| Heroic burst damage | Use mitigation before pull/spike; healer pre-casts | Tanks, healers |

## Dungeon Family Notes

| Dungeon family | Common modifier | Rotation impact |
|---|---|---|
| Hellfire Citadel | Fel orc melee pressure, caster packs, chain-pull risk | Tanks use mitigation early; DPS interrupts and avoids early cleave |
| Coilfang Reservoir | Naga/caster packs, poison/nature themes | Cleanses and interrupts rise; nature resistance may matter by encounter |
| Auchindoun | Undead/demon/caster control, fear/charm-style pressure | Shackle/turn/exorcism-style tools can matter; Tremor/Fear Ward value rises |
| Tempest Keep dungeons | Mana users, arcane/mechanic-heavy pulls, dangerous casters | Purge/interrupt/Spellsteal and LoS pulls are high value |
| Caverns of Time | Add waves and objective protection | Target swap and snap threat matter more than perfect boss rotation |

## S+ Automation Checks

- Add a `cc_safe` check before every cleave/AoE rule.
- Add `priority_add` handling for healers, runners, dangerous casters, and objective attackers.
- Add `interrupt_now` handling by cast danger rather than interrupting the first cast seen.
- Add `tank_has_pack_control` before Consecration, Hurricane, Blizzard, Seed, Volley, Magma Totem, Cleave, Blade Flurry, and Chain Lightning.
