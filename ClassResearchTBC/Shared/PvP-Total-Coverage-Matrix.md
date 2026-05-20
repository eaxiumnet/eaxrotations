# Total PvP Coverage Matrix

Second-pass PvP coverage for arena, battlegrounds, world PvP, class matchups, and spec playstyles. Sources include TBCPVP arena guide hub, Wowhead TBC PvP class guides, Icy Veins PvP hubs, and local Sonah PvP references.

## Brackets and Modes

| Mode | What matters | Rotation consequence |
|---|---|---|
| 2v2 arena | Mana, resets, LoS, dampened kill windows | Defensive/resource logic often outranks damage filler |
| 3v3 arena | Cross-CC, burst setup, healer swaps | Track enemy healer CC/interrupt state before burst |
| 5v5 arena | Fast target calls, burst, interrupts, purge/dispel volume | Prefer quick-response utility and survival thresholds |
| Battlegrounds | Objectives, group fights, flag/base defense | Target objectives and control before PvE-style damage |
| World PvP | Opener advantage, escape tools, consumables, uneven numbers | Defensive and mobility rules need earlier trigger points |

## Enemy Class Response Matrix

| Enemy class | Response rules |
|---|---|
| Druid | Respect Cyclone, roots, HoTs, travel form, and stealth. Purge/dispels pressure Restoration; slows/stuns punish Feral; interrupts hurt Balance casts. |
| Hunter | Control pet and range, remove Viper Sting where possible, avoid trap chains, close gaps carefully after dead-zone removal. |
| Mage | Stop Polymorph chains, force Ice Block, dispel Spellsteal value, avoid Shatter setups, pressure during Counterspell downtime. |
| Paladin | Bait bubble/BoP/Freedom, purge/dispels where possible, watch Hammer of Justice and Cleanse; do not tunnel into immunities. |
| Priest | Protect buffs from dispel, stop Mana Burn, punish fear cooldown, pressure Shadow before DoTs stabilize. |
| Rogue | Deny opener where possible, survive Cheap/Kidney chain, remove poisons, keep DoTs/bleeds to prevent easy resets. |
| Shaman | Kill/deny key totems, fake or bait Grounding, expect Earth Shock interrupts and Purge; Tremor changes fear plans. |
| Warlock | Break Fear chains, dispel/cleanse carefully around UA, control pet, line-of-sight DoTs/drains when possible. |
| Warrior | Control uptime with roots/slows/disarms, watch Intercept/Pummel, do not feed rage with weak damage unless kiting is secured. |

## Spec PvP Playstyle Index

| Class | Spec | PvP role | Primary PvP checks |
|---|---|---|---|
| Druid | Balance | Caster support DPS | Cyclone/roots/forms, off-heal, decurse, mobility |
| Druid | Feral-DPS | Cat melee DPS | Stealth opener, Cyclone/roots/forms, Bear emergency |
| Druid | Bear-Tank | High-armor tank | Flag/body defense, charge/bash, anti-melee control |
| Druid | Restoration | HoT healer | Pre-HoT, Cyclone, roots, travel form, LoS |
| Hunter | Beast-Mastery | Pet burst DPS | Bestial Wrath kill window, traps, Viper Sting, pet pressure |
| Hunter | Marksmanship | Shot and utility DPS | Drain/control games with Viper Sting, traps, Scatter/Silencing style utility |
| Hunter | Survival | Expose Weakness support DPS | Trap/utility, Wyvern-style control where talented, drain support |
| Mage | Arcane | Mana-burn caster | Polymorph, Counterspell, Spellsteal, burst setup |
| Mage | Fire | Crit/ignite caster | Control into burst, Counterspell, Dragon's Breath if talented |
| Mage | Frost | Control caster | Strong control, Ice Block, kiting, Counterspell |
| Paladin | Holy | Single-target healer | Cleanse, bubble, BoP/Freedom/Sacrifice, stun |
| Paladin | Protection | AoE Holy-threat tank | Durable objective tank, dispels, stuns, blessings |
| Paladin | Retribution | Melee support DPS | Burst with stun/wings, Cleanse/Freedom/BoP utility |
| Priest | Discipline | Mitigation/utility healer | Dispel, Mana Burn, Pain Suppression, fear |
| Priest | Holy | Flexible raid/tank healer | Dispel, fear, emergency heals, no Guardian Spirit in TBC |
| Priest | Shadow | Mana-support DoT DPS | DoT pressure, Silence, fear, Mana Burn/dispels |
| Priest | Smite | Holy damage utility | Unexpected burst, dispels, emergency heals |
| Rogue | Assassination | Poison/dagger DPS | Openers, poisons, stuns, blind, resets |
| Rogue | Combat | Primary PvE Rogue | Cooldown burst, Kick, stuns, control |
| Rogue | Subtlety | PvP/control Rogue | Sap/Blind/Kidney/Vanish/Preparation control chains |
| Shaman | Elemental | Caster support DPS | Purge, Grounding, Tremor, Earth Shock interrupt |
| Shaman | Enhancement | Melee support DPS | Purge, shocks, Grounding/Tremor, burst melee |
| Shaman | Restoration | Chain Heal raid healer | Purge, Grounding/Tremor, Earth Shield, LHW triage |
| Warlock | Affliction | DoT/support DPS | Fear/DoT/drain pressure, pet/curse utility |
| Warlock | Demonology | Pet-centric DPS | Soul Link/Felguard control, fear, drains |
| Warlock | Destruction | Direct-damage caster | Burst, Shadowfury if talented, fear/curse pressure |
| Warrior | Arms | Two-hand support DPS | MS pressure, Hamstring, Intercept, Pummel |
| Warrior | Fury | Dual-wield DPS | Uptime pressure, Intercept/Pummel, Berserker Rage |
| Warrior | Protection | Shield tank | Flag/objective tank, interrupts, Disarm, stuns |

## PvP Automation Rules

- Never run pure PvE rotation while the player or healer is under lethal pressure.
- Enemy cast danger, healer CC, burst cooldowns, trinket state, and LoS state are higher-order decisions.
- Track diminishing returns where local API/support code allows it.
- Do not break friendly CC with cleave, DoTs, pet cleave, Consecration, Chain Lightning, Seed, or Blizzard unless kill-confirmed.
- PvP consumable/item usage must obey arena/battleground restrictions.
