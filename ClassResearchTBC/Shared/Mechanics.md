# Shared TBC Mechanics

Sources: `../Sources.md`, especially the Icy Veins class hub, Wowhead class databases, Warcraft Tavern consumables, Warcraft Tavern Paladin seals, Warcraft Tavern Feral powershifting, and Warcraft Wiki Totem Twisting.

## Universal Rotation Concepts

- TBC rotations are usually priority systems, not fixed scripts.
- Mana, threat, global cooldown timing, weapon swing timing, pet behavior, and group buffs can change the correct next action.
- For exact spell IDs and ranks, use Wowhead TBC ability database pages. Local research should list names and behavior, then code should resolve usable spell ranks at runtime.
- PvE and PvP priorities diverge sharply. PvP values instant casts, interrupts, dispels, control, LoS, defensive cooldowns, and burst windows more than pure throughput.

## Swing Timer Mechanics

- Hunter gameplay depends on not clipping Auto Shot with Steady Shot, Multi-Shot, or movement.
- Warrior Arms Slam gameplay depends on casting Slam immediately after a melee swing to minimize swing reset losses.
- Retribution Paladin seal twisting depends on seal change timing around weapon swings.
- Enhancement Shaman weapon sync and Stormstrike/Earth Shock timing are swing-sensitive when optimizing Windfury procs.
- Rogue damage depends on maintaining Slice and Dice uptime while spending combo points efficiently around energy ticks and cooldown windows.

## Class-Specific Advanced Mechanics

- Druid powershifting: Feral DPS can convert mana into energy by leaving and re-entering Cat Form, especially with Furor and Wolfshead Helm. Rotation logic needs mana floor, energy threshold, GCD awareness, and form state.
- Paladin seal twisting: Retribution can gain benefits from two seals on one swing by twisting from Seal of Command or Seal of Righteousness into Seal of Blood or Seal of the Martyr near swing impact. Rotation logic needs faction seal, active seal, swing timer, mana, and target validity.
- Shaman totem twisting: Enhancement can drop Windfury Totem, allow the weapon buff to apply, then swap to Grace of Air or another air totem during the buff window. Rotation logic needs assignment flags, party composition, mana, and timer tracking.
- Shaman weapon imbues: Enhancement normally uses Windfury Weapon on main hand and a damage/control imbue on off hand depending on PvE or PvP. Elemental and Restoration value Flametongue-style spell support less than caster weapon oil when allowed by gear rules.
- Rogue poisons: PvE normally values Instant/Deadly/Wound depending on weapon speed, target lifetime, and debuff rules. PvP requires Crippling, Wound, Mind-numbing, and Shiv logic.
- Warlock Life Tap: DPS rotation must balance mana conversion against incoming damage, healer load, and movement. Affliction has more DoT state; Destruction has more direct-cast state.
- Priest five-second rule: Healing logic should avoid unnecessary casts when regeneration matters, but TBC encounter damage often forces active healing. Shadow uses Vampiric Touch and Shadowfiend as party mana support.
- Mage burn/conserve: Arcane uses mana as a throughput resource; Fire and Frost still need mana, cooldown, and threat controls.
- Warrior rage: Rotation should spend rage without starving high-priority attacks. Tanks must trade threat generation against shield/block survival windows.

## Role Behavior

- DPS single target: prioritize debuff maintenance, high-value cooldowns, core filler, resource dump.
- DPS multi target: use cleave/AoE only when target count, target lifetime, threat, and mana/rage/energy justify it.
- Healing: select spell by damage pattern, target urgency, mana state, and role assignment. Avoid fixed "rotations" for healers.
- Tanking: maintain survival buffs and high-threat abilities, react to taunt needs, and avoid breaking CC with uncontrolled AoE.
- PvP: preserve interrupts, dispels, trinket windows, defensives, snares, mobility, and burst coordination.

## Automation Notes

- Any automation for swing-sensitive mechanics needs a reliable swing timer abstraction.
- Any automation for healing needs triage state, incoming damage awareness, blacklist/line-of-sight checks, and overheal controls.
- Any automation for PvP needs enemy cast tracking, DR awareness where available, and role-specific toggles for offensive versus defensive play.

## S+ Automation Mechanics Addendum

| Mechanic | S+ documentation requirement | Rotation implementation implication |
|---|---|---|
| Swing timer | Document weapon/swing dependency for melee specs | Needed for Slam, seal twisting, totem twisting, Hunter shot weaving, and powershifting timing |
| Resource floor | Every spec needs a low-resource rule | Prevents mana/rage/energy starvation before mandatory abilities |
| Threat lead | Every DPS spec needs a high-threat fallback | Burst, cleave, and AoE should pause when tank lead is weak |
| Debuff slots | DoT/debuff specs must state which debuffs are optional | Avoids wasting globals on low-value debuffs in constrained raids |
| CC safety | Every AoE rule must say whether it can break CC | Prevents Consecration, Hurricane, Chain Lightning, Seed, Cleave, and Blade Flurry failures |
| TBC guardrail | Mark later-expansion mechanics explicitly as invalid | Prevents Beacon, Mind Sear, Cat Swipe, Lava Burst, Titan's Grip, etc. from entering TBC rotations |
