# EaxRotations TBC Spec Depth Audit

## Date: 2026-05-14
## Methodology: Line count, custom matches functions, state builders, proc handling, DoT logic, healing triage, movement, AoE, cooldown planning

---

## DEEP Specs (Already Advanced - 10 specs)

| # | Class | Spec | File | Lines | Key Features |
|---|-------|------|------|-------|--------------|
| 1 | Warrior | Arms | arms_sylvanas.lua | 165 | Slam weaving, stance dancing (Tactical Mastery), PvP rotation (Intercept/Disarm/Spell Reflect), Battle Shout refresh, Victory Rush |
| 2 | Warrior | Kebab | kebab_sylvanas.lua | 486 | Full hybrid rotation, Arms/Fury blend, stance dancing, execute weaving, rage management |
| 3 | Mage | Arcane | arcane_sylvanas.lua | 204 | AB stack management (3-stack), evocation planning, mana gem optimization, Presence of Mind burst, Ice Barrier defensive, Arcane Missiles filler |
| 4 | Rogue | Combat | combat_sylvanas.lua | 190 | Energy tick optimization (pool/spend), Blade Flurry + Adrenaline Rush sync, Slice and Dice/Rupture cycle, Killing Spree burst |
| 5 | Priest | Holy | holy_sylvanas.lua | 408 | Full healing triage (Flash Heal > Greater Heal > Renew), Prayer of Mending, Circle of Healing AoE, Power Word: Shield (Weakened Soul gate), tank vs lowest targeting |
| 6 | Priest | Shadow | shadow_sylvanas.lua | 171 | Mind Flay tick clipping (3s channel, 1s ticks), VT/SW:P DoT management, Mind Blast/SW:D cooldowns, Shadowform check |
| 7 | Priest | Smite | smite_sylvanas.lua | 292 | Surge of Light proc handling, Holy Fire weave, Shadow Word: Pain maintenance, Inner Focus burst, Divine Fury talent cast time reduction |
| 8 | Paladin | Retribution | retribution_sylvanas.lua | 152 | Seal twisting (Command/Blood), swing timer tracking, Crusader Strike priority, Judgement optimization, Demon/Undead detection |
| 9 | Shaman | Enhancement | enhancement_sylvanas.lua | 149 | Totem twisting (Windfury/Grace of Air), swing timer tracking, Stormstrike debuff maintenance, totem refresh management |
| 10 | Hunter | All 3 | cliptracker_sylvanas.lua | 50 | Shot clip tracker, Steady Shot timing, Auto Shot buffer, Kill Command, Multi-Shot/Aimed Shot weaving |

---

## MEDIUM Specs (Partial - 7 specs)

| # | Class | Spec | File | Lines | Has | Missing |
|---|-------|------|------|-------|-----|---------|
| 11 | Warrior | Fury | fury_sylvanas.lua | 74 | Custom execute_matches, burst_cooldown_matches, can_cast_slam (rage pool for BT/WW) | Slam weaving, flurry uptime tracking, dual-wield spec logic, heroic strike rage dump optimization |
| 12 | Mage | Fire | fire_sylvanas.lua | 51 | Custom combustion_matches, Scorch debuff tracking (5-stack) | Ignite munching prevention, Living Bomb (TBC-era only), Combustion timing optimization, Fireball vs Scorch decision at low crit |
| 13 | Druid | Balance | balance_sylvanas.lua | 110 | Custom DoT refresh gates (Insect Swarm, Moonfire, Faerie Fire), Innervate at <30% mana, Hurricane AoE | Eclipse proc tracking (requires Wrath of the Lich King), Starfire spam optimization with haste breakpoints |
| 14 | Druid | Bear | bear_sylvanas.lua | 108 | Custom Lacerate stack tracking (build to 5), Maul rage dump, Swipe AoE, Demoralizing Roar maintenance | Mangle debuff uptime, Feral Faerie Fire, Bash interrupt timing |
| 15 | Warlock | Destruction | destruction_sylvanas.lua | 110 | Custom immolate_matches (pandemic 3.5s), shadowburn_matches (execute), Backlash proc handling, Backdraft haste stacks | Soul Fire opener, Shadowfury stun, Conflagrate consume timing |
| 16 | Warlock | Affliction | affliction_sylvanas.lua | 140 | Custom corruption_matches, curse_of_agony_matches, unstable_affliction_matches, siphon_life_matches, Nightfall proc handling, Life Tap optimization | Drain Soul execute (soul shard generation), Seed of Corruption AoE |
| 17 | Shaman | Elemental | elemental_sylvanas.lua | 99 | Custom flame_shock_matches, chain_lightning_aoe, totem management, Earth Shock interrupt | Lightning Bolt spam optimization, clearcasting proc tracking, haste breakpoint awareness |

---

## THIN Specs (Needs Enhancement - 13 specs)

| # | Class | Spec | File | Lines | Current State | Missing (Top-Parse Gaps) |
|---|-------|------|------|-------|---------------|--------------------------|
| 18 | Mage | Frost | frost_sylvanas.lua | 36 | Basic ACTIONS table, no custom logic | Water elemental management, Frostbolt vs Ice Lance decision, Shatter combo (Frostbolt+Ice Lance on frozen), Cold Snap reset planning, Brain Freeze proc (TBC-era: Frostbite root), Winter's Chill stacking |
| 19 | Rogue | Assassination | assassination_sylvanas.lua | 36 | Basic ACTIONS table | Mutilate energy optimization, Envenom vs Eviscerate decision, Deadly Poison stack tracking, Seal Fate combo point generation, Find Weakness uptime, Vanish+Garrote opener |
| 20 | Rogue | Subtlety | subtlety_sylvanas.lua | 35 | Basic ACTIONS table | Hemorrhage spam optimization, Shadowstep positioning, Premeditation opener, Find Weakness uptime, energy tick tracking (copy from Combat), Shiv poison application |
| 21 | Warlock | Demonology | demonology_sylvanas.lua | 38 | Basic ACTIONS table | Demon pet management (Felguard rotation), Soul Link defensive, Demonic Empowerment (TBC-era), Shadow Bolt filler, Metamorphosis timing (TBC-era), DoT maintenance during demon phase |
| 22 | Druid | Cat (Feral) | cat_sylvanas.lua | 58 | Custom rip_matches, rake_matches (DoT refresh) | Powershift energy optimization, Mangle debuff maintenance, Feral Faerie Fire, Omen of Clarity proc handling, Tiger's Fury burst, Ferocious Bite energy dump optimization, rake vs shred energy efficiency |
| 23 | Druid | Resto | resto_sylvanas.lua | 81 | Basic healing state, Swiftmend, Nature's Swiftness | Lifebloom triple-stack (pre-Wrath but used in TBC), Tree of Life form check, Rejuvenation rolling, Regrowth vs Healing Touch efficiency, Innervate target optimization, Abolish Poison/Disease cleansing |
| 24 | Hunter | BM | beast_mastery_sylvanas.lua | 76 | Shot clipping integration, Bestial Wrath burst | Beast Cleave (TBC-era: Multi-Shot during BW), pet management (Growl, Cower, Dash), Kill Command spam, intimidation stun, pet food happiness |
| 25 | Hunter | MM | marksmanship_sylvanas.lua | 77 | Shot clipping, Aimed Shot prepull, Rapid Fire | Silencing Shot interrupt, readiness reset, scatter shot CC, Trueshot Aura maintenance, Chimera Shot (TBC-era) |
| 26 | Hunter | Survival | survival_sylvanas.lua | 76 | Shot clipping, Explosive Trap AoE, Wyvern Sting CC | Serpent Sting DoT maintenance, Immolation Trap, counterattack parry, survival instincts, trap weaving |
| 27 | Paladin | Holy | holy_sylvanas.lua | 68 | Basic healing state, Holy Shock emergency | Beacon of Light (WotLK - skip), Sacred Shield (WotLK - skip), Holy Light vs Flash of Light efficiency, Divine Illumination mana optimization, Cleanse utility, Blessing management |
| 28 | Paladin | Prot | protection_sylvanas.lua | 135 | Custom threat logic, Holy Shield, Consecration, Avenger's Shield | Sacred Duty defensive, Ardent Defender (TBC-era), Righteous Defense taunt, Blessing of Sanctuary, Judgement of Wisdom/Light maintenance |
| 29 | Shaman | Resto | restoration_sylvanas.lua | 99 | Basic healing state, Chain Heal, Earth Shield | Riptide (WotLK - skip), Tidal Waves (WotLK - skip), Chain Heal bounce optimization, Earth Shield stack refresh, Water Shield mana return, totem management (Healing Stream, Mana Spring) |
| 30 | Warrior | Prot | protection_sylvanas.lua | 122 | Custom Sunder stack tracking, Shield Slam priority, rage dump, Revenge proc | Shield Block defensive, last stand/defensive stance emergency, Mocking Blow taunt, Spell Reflection, Concussion Blow stun, Thunder Clap debuff |

---

## Enhancement Priority Queue

### Phase 1: THIN Specs (13 specs)
1. Mage Frost - Water elemental, Shatter combo, Brain Freeze
2. Rogue Assassination - Mutilate optimization, Envenom, Deadly Poison
3. Rogue Subtlety - Hemorrhage spam, Shadowstep, Premeditation
4. Warlock Demonology - Demon pet rotation, Soul Link, Metamorphosis
5. Druid Cat - Powershift, Omen of Clarity, Tiger's Fury
6. Druid Resto - Lifebloom stacking, Rejuvenation rolling
7. Hunter BM - Pet management, Beast Cleave
8. Hunter MM - Silencing Shot, Readiness
9. Hunter Survival - Serpent Sting, Trap weaving
10. Paladin Holy - Divine Illumination, Blessing management
11. Paladin Prot - Sacred Duty, Righteous Defense
12. Shaman Resto - Chain Heal bounce, Earth Shield stacks
13. Warrior Prot - Shield Block, Last Stand, Spell Reflection

### Phase 2: MEDIUM Specs (7 specs)
14. Warrior Fury - Slam weaving, Flurry tracking, Heroic Strike dump
15. Mage Fire - Ignite munching prevention, Combustion timing
16. Druid Balance - Starfire spam, haste breakpoints
17. Druid Bear - Mangle uptime, Feral Faerie Fire
18. Warlock Destro - Soul Fire opener, Shadowfury
19. Warlock Affliction - Drain Soul execute, Seed of Corruption
20. Shaman Elemental - Clearcasting, LB spam optimization

### Phase 3: Verification
21. All 29 specs pass luac -p
22. All 43+ tests pass
23. Manual spot-check of top 5 highest-impact enhancements

---

*Generated by Sisyphus Agent | TBC Classic 2.4.3 | Project Sylvanas*