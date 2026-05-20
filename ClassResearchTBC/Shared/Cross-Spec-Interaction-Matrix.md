# Cross-Spec Interaction Matrix

Generated from the Research Expansion Pass across all 29 specs.

## Full 40-Debuff Slot Priority Ranking

| Rank | Debuff | Provider | Spell ID | Mandatory? | Notes |
|---|---|---|---|---|---|
| 1 | Sunder Armor | Warrior Prot/Arms | 25225 | Yes | Major armor reduction |
| 2 | Curse of Recklessness | Warlock | 27226 | Yes | +AP, -armor |
| 3 | Faerie Fire (Feral) | Druid Feral/Bear | 27011 | Yes | Armor + hit reduction |
| 4 | Thunder Clap | Warrior Prot | 25264 | Yes | -AP, slow |
| 5 | Demoralizing Shout | Warrior Fury/Prot | 25203 | Yes | -AP |
| 6 | Curse of Elements | Warlock | 27228 | Yes | +10% spell damage |
| 7 | Improved Scorch | Mage Fire | 27074 | Yes | +15% fire damage |
| 8 | Winter's Chill | Mage Frost | 28595 | No | +10% frost crit |
| 9 | Shadow Weaving | Priest Shadow | 15258 | No | +10% shadow damage |
| 10 | Expose Weakness | Hunter Survival | 34500 | No | +AP |
| 11 | Hunter's Mark | Hunter MM/BM | 14325 | No | +RAP |
| 12 | Judgement of Light | Paladin | 27163 | No | Heal proc |
| 13 | Judgement of Wisdom | Paladin | 27164 | No | Mana return |
| 14 | Vampiric Touch | Priest Shadow | 34914 | Yes | Mana return |
| 15 | Mangle (Cat/Bear) | Druid Feral/Bear | 33917 | Yes | +bleed damage |
| 16 | Blood Frenzy | Warrior Arms | 29859 | No | +physical damage |
| 17 | Curse of Agony | Warlock Affliction | 27218 | No | DoT |
| 18 | Corruption | Warlock Affliction | 27216 | No | DoT |
| 19 | Immolate | Warlock Destro | 27215 | No | DoT + Conflagrate setup |
| 20 | Shadow Word: Pain | Priest Shadow | 25368 | No | DoT |
| 21 | Serpent Sting | Hunter | 27016 | No | DoT |
| 22 | Deadly Poison | Rogue | 27282 | No | DoT poison |
| 23 | Wound Poison | Rogue | 22055 | No | -healing |
| 24 | Unstable Affliction | Warlock Affliction | 30405 | No | DoT + dispel protection |
| 25 | Flame Shock | Shaman Elemental | 25457 | No | DoT |
| 26 | Moonfire | Druid Balance | 26988 | No | DoT |
| 27 | Insect Swarm | Druid Balance | 27013 | No | DoT |
| 28 | Rupture | Rogue | 26867 | No | Bleed |
| 29 | Ignite | Mage Fire | 12654 | No | Fire crit DoT |
| 30 | Deep Wounds | Warrior Arms | 12868 | No | Bleed |
| 31 | Lacerate | Druid Bear | 33745 | No | Bleed |
| 32 | Hemorrhage | Rogue Subtlety | 26864 | No | Physical damage debuff |
| 33 | Expose Armor | Rogue | 26866 | No | -armor (if no Sunder) |
| 34 | Gift of Arthas | Alchemy | 11374 | No | +disease damage |
| 35 | Annihilator | Blacksmithing | 16928 | No | -armor proc |
| 36 | Curse of Tongues | Warlock | 1714 | No | +cast time |
| 37 | Curse of Weakness | Warlock | 27226 | No | -AP |
| 38 | Curse of Shadow | Warlock | 27229 | No | -shadow resist |
| 39 | Curse of Doom | Warlock | 27228 | No | Big DoT |
| 40 | Curse of Recklessness | Warlock | 27226 | Yes | +AP, -armor |

## Bloodlust Timing Matrix

| Spec | Bloodlust changes what? | Optimal timing | Condition |
|---|---|---|---|
| Druid Balance | Starfire cast time < 2.0s = possible clipping | Use with trinkets | `trinket_ready` |
| Druid Feral DPS | Energy tick rate unchanged; haste affects white damage only | Do not use Berserk [50334]; DB2 absent for this TBC target | N/A |
| Druid Bear Tank | Threat generation increase | Use at pull | `combat_start` |
| Hunter Beast Mastery | Pet attack speed + steady shot weaving | Use with BW [19574] | `bw_active` |
| Hunter Marksmanship | Aimed Shot cast time reduction | Use with RF [3045] | `rf_active` |
| Hunter Survival | Trap arm speed unaffected; focus on steady shot | Use with Readiness [23989] | `readiness_cd == 0` |
| Mage Arcane | Arcane Blast stack building faster | Use at 3-stack | `ab_stacks == 3` |
| Mage Fire | Ignite stacking faster; scorch maintenance easier | Use with Combustion [11129] | `combustion_charges > 10` |
| Mage Frost | Frostbolt spam; no significant breakpoint | Use on pull | `combat_start` |
| Paladin Holy | Flash of Light spam faster | Use during heavy damage | `incoming_damage > threshold` |
| Paladin Protection | Threat generation increase | Use at pull | `combat_start` |
| Paladin Retribution | Seal procs more frequent | Use with AW [31884] | `aw_active` |
| Priest Discipline | Shield spam faster | Use during burst damage | `burst_damage_active` |
| Priest Holy | Flash Heal spam faster | Use during heavy damage | `incoming_damage > threshold` |
| Priest Shadow | Mind Blast / Mind Flay faster | Use at VT refresh window | `vt_remains > 10` |
| Priest Smite | Smite cast time reduction | Use on pull | `combat_start` |
| Rogue Assassination | Energy tick unchanged; white damage increase | Use with Adrenaline Rush [13750] | `ar_active` |
| Rogue Combat | Sinister Strike faster; Blade Flurry value | Use with AR [13750] | `ar_active` |
| Rogue Subtlety | Hemorrhage faster; no major breakpoint | Use on pull | `combat_start` |
| Shaman Elemental | Lightning Bolt spam; no breakpoint change | Use on pull | `combat_start` |
| Shaman Enhancement | Windfury procs more frequent | Use with Shamanistic Rage [30823] | `rage_active` |
| Shaman Restoration | Chain Heal faster | Use during heavy AoE | `aoe_damage_active` |
| Warlock Affliction | DoT ticks unaffected; casting faster | Use on pull | `combat_start` |
| Warlock Demonology | Shadow Bolt spam faster | Use on pull | `combat_start` |
| Warlock Destruction | Incinerate/Shadow Bolt spam | Use with Conflagrate [17962] | `conflagrate_ready` |
| Warrior Arms | Slam timing tighter; execute phase value | Use during Execute [25236] phase | `target_hp <= 20` |
| Warrior Fury | Bloodthirst / Whirlwind faster | Use with Death Wish [12292] | `death_wish_active` |
| Warrior Protection | Shield Slam / Revenge faster | Use at pull | `combat_start` |

## Judgement Assignment Table

| Group Composition | Light Judge | Wisdom Judge | Condition |
|---|---|---|---|
| 1 Paladin | Holy/Prot | Retribution | Solo Paladin judges both |
| 2 Paladins | Holy | Retribution | Split by role |
| 3+ Paladins | Holy | Retribution + Prot | Prot backup |
| No Paladin | N/A | N/A | Use mana potions |
| With Shadow Priest | Light | Wisdom | VT covers mana |
| With Resto Shaman | Light | Wisdom | Mana Tide covers mana |

## Totem Range Impact Map

| Melee Spec | Windfury Priority | Grace of Air | Strength of Earth | Notes |
|---|---|---|---|---|
| Warrior Arms | Critical | Low | High | WW radius = 8y |
| Warrior Fury | Critical | Low | High | Whirlwind radius = 8y |
| Warrior Protection | Critical | Low | High | Threat generation |
| Rogue Assassination | High | Medium | Medium | SnD uptime |
| Rogue Combat | High | Medium | Medium | Blade Flurry value |
| Rogue Subtlety | High | Medium | Medium | Hemorrhage spam |
| Paladin Retribution | High | Low | High | Seal procs |
| Shaman Enhancement | N/A (self) | N/A | N/A | Totem twisting |
| Druid Feral DPS | Low | High | Medium | Powershift timing |
| Druid Bear Tank | Low | High | Medium | Threat generation |
| Hunter BM/MM/Survival | Low | Low | Low | Ranged |

## VT Mana Return Chain

| Spec | VT Mana Impact | Life Tap Frequency Change | Threshold |
|---|---|---|---|
| Warlock Affliction | High | -30% Life Taps | VT uptime > 80% |
| Warlock Demonology | High | -30% Life Taps | VT uptime > 80% |
| Warlock Destruction | High | -30% Life Taps | VT uptime > 80% |
| Mage Arcane | Medium | -20% Mana potions | VT uptime > 80% |
| Mage Fire | Medium | -20% Mana potions | VT uptime > 80% |
| Mage Frost | Medium | -20% Mana potions | VT uptime > 80% |
| Priest Shadow | N/A | N/A | Provider |
| Shaman Elemental | Medium | -20% Mana potions | VT uptime > 80% |
| Druid Balance | Low | -10% Innervate use | VT uptime > 80% |

## Group Composition Decision Tables

### Physical Melee Group

| Slot 1 | Slot 2 | Slot 3 | Slot 4 | Slot 5 | Optimal? |
|---|---|---|---|---|---|
| Warrior | Rogue | Rogue | Shaman Enh | Paladin Ret | Yes |
| Warrior | Rogue | Feral Druid | Shaman Enh | Paladin Ret | Yes |
| Warrior | Warrior | Rogue | Shaman Enh | Paladin Ret | Yes |
| Warrior | Hunter | Rogue | Shaman Enh | Paladin Ret | Suboptimal |
| Warrior | Rogue | Rogue | Shaman Resto | Paladin Ret | No (no WF) |

### Caster Group

| Slot 1 | Slot 2 | Slot 3 | Slot 4 | Slot 5 | Optimal? |
|---|---|---|---|---|---|
| Mage | Mage | Warlock | Shaman Ele | Priest Shadow | Yes |
| Mage | Mage | Mage | Shaman Ele | Priest Shadow | Yes |
| Mage | Warlock | Warlock | Shaman Ele | Priest Shadow | Yes |
| Mage | Mage | Druid Balance | Shaman Ele | Priest Shadow | Suboptimal |
| Mage | Mage | Warlock | Shaman Resto | Priest Shadow | No (no ToW) |

### Healer Group

| Slot 1 | Slot 2 | Slot 3 | Slot 4 | Slot 5 | Optimal? |
|---|---|---|---|---|---|
| Priest Holy | Priest Disc | Paladin Holy | Shaman Resto | Druid Resto | Yes |
| Priest Holy | Paladin Holy | Shaman Resto | Druid Resto | Empty | Yes |
| Priest Holy | Priest Disc | Paladin Holy | Shaman Resto | Empty | Suboptimal |
| Priest Holy | Paladin Holy | Druid Resto | Empty | Empty | No |

## TBC GUARDRAIL CHECK

| Ability | Earliest Expansion | Status | Action Required |
|---|---|---|---|
| Beacon of Light | WotLK | Not referenced | OK |
| Holy Power | Cata | Not referenced | OK |
| Sacred Shield | WotLK | Not referenced | OK |
| Divine Plea [54428] | WotLK / DB2 absent | Guardrail only | Remove |
| Lava Burst | WotLK | Not referenced | OK |
| Riptide | WotLK | Flagged in Shaman Restoration | Remove |
| Hex | WotLK | Not referenced | OK |
| Wind Shear [57994] | WotLK | Flagged in Shaman Restoration | Remove |
| Feral Spirit | WotLK | Not referenced | OK |
| Maelstrom Weapon | WotLK | Not referenced | OK |
| Mind Sear | WotLK | Not referenced | OK |
| Cat Swipe (Feral AoE) | WotLK | Not referenced | OK |
| Savage Roar | WotLK | Not referenced | OK |
| Berserk [50334] | WotLK / DB2 absent | Flagged in Druid Feral DPS | Remove |
| Titan's Grip | WotLK | Not referenced | OK |
| Shockwave | WotLK | Not referenced | OK |
| Bladestorm | WotLK | Not referenced | OK |
| Sword and Board proc | WotLK | Not referenced | OK |
| Heroic Throw | WotLK | Not referenced | OK |
| Death Knight abilities | WotLK | Not referenced | OK |
| Guardian Spirit [47788] | WotLK / DB2 absent | Flagged in Priest Holy | Remove |
| Lightwell [724] | Valid TBC | Corrected from false WotLK flag | Keep |
| Circle of Healing [34861] | Valid TBC | Corrected from false WotLK flag | Keep |
| Penance [47540] | WotLK / DB2 absent | Flagged in Priest Disc/Smite | Remove |
| Rapture [47535] | WotLK / DB2 absent | Flagged in Priest Disc | Remove |
| Dispersion [47585] | WotLK / DB2 absent | Flagged in Priest Shadow | Remove |
| Focus Magic [54646] | WotLK / DB2 absent | Flagged in Mage Arcane | Remove |
| Brain Freeze [44549] | WotLK / DB2 absent | Flagged in Mage Frost | Remove |
| Living Bomb [44457] | SpellName only; no Mage class skillline | Flagged in Mage Fire | Remove from Mage rotations |
| Demonic Empowerment [47193] | WotLK / DB2 absent | Flagged in Warlock Demonology | Remove |
| Metamorphosis [47241] | WotLK / DB2 absent | Flagged in Warlock Demonology | Remove |
| Demon Soul [77801] | WotLK / DB2 absent | Flagged in Warlock Demonology | Remove |
| Chaos Bolt [50796] | WotLK / DB2 absent | Flagged in Warlock Destruction | Remove |
| Backdraft [54274] | WotLK / DB2 absent | Flagged in Warlock Destruction | Remove |
| Black Arrow / Aimed Shot ID collision | [19434] is Aimed Shot; Black Arrow [3674/14296] is Marksmanship, not Survival | Flagged in Hunter Survival | Do not implement as Survival Black Arrow |
| Explosive Shot [53209] | WotLK / DB2 absent | Flagged in Hunter Survival | Remove |
| Commanding Shout [469] | Valid TBC | Warrior ability available in TBC | Keep |
| Nourish [50464] | WotLK / DB2 absent | Flagged in Druid Restoration | Remove |
