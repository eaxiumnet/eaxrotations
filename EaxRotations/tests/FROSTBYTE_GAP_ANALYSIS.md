# FrostByte Gap Analysis — All Specs

Generated from comparing `Frost.txt` feature descriptions against `EaxRotations/classes/` implementation files.

---

## ✅ 1. Holy Priest (445 lines — `holy_sylvanas.lua`)

### Frost.txt Features
- Auto spec detection (Holy vs Discipline)
- Stop-cast engine (mid-cast cancellation at HP checkpoints)
- Pre-heal system (queues GH/FH based on damage patterns)
- Tank-priority target selection with HP bias
- Per-spell HP thresholds (Renew, PoH, GH, BH, FH, CoH)
- Binding Heal self-deprioritization
- Dispel Magic on party members
- Fade — auto aggro drop
- Healthstone auto-use below HP threshold
- Inner Focus — holds for expensive heal
- Power Word: Shield (tank/lowest HP, gated by Weakened Soul)
- Prayer of Mending (kept on cooldown)
- Circle of Healing (Holy only, min targets + HP% config)
- Prayer of Healing (min targets + HP%)
- Greater Heal (pushback-protected)
- Flash Heal (emergency)
- Mounted protection
- Encounter reactions (Netherspite, Maiden, Moroes)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Per-spell HP thresholds | ✅ | Uses `NS.PriestHealing` with rank selection |
| PoM, CoH, PWS, BH | ✅ | Direct spell references |
| Inner Focus | ✅ | `SPELLS.InnerFocus` + `try_cast` |
| Stop-cast engine | ❌ **MISSING** | Not found in holy_sylvanas.lua |
| Pre-heal system | ❌ **MISSING** | Not found |
| Fade auto-use | ❌ **MISSING** | Should fire when aggro'd with backup healer |
| Healthstone auto-use | ❌ **MISSING** | Should fire below HP threshold, off-GCD |
| Mounted protection | ❌ **MISSING** | No mount check found |
| Encounter reactions | ❌ **MISSING** | Not implemented |

### Top Gaps for Testing
1. **Healthstone auto-use** — same pattern as Arms Warrior
2. **Fade aggro drop** — check backup healer, HP gate
3. **Stop-cast engine** — multi-point HP checkpoint mid-cast

---

## ✅ 2. Discipline Priest (329 lines — `discipline_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| PWS, PoM, FH, GH, Renew, BH | ✅ | Match functions exist |
| CoH, PoH | ✅ | Match functions exist |
| Inner Fire, Fear Ward, PWF | ✅ | Match functions exist |
| Dispel Magic, Psychic Scream, Shackle Undead | ✅ | Match functions exist |
| Stop-cast engine | ❌ **MISSING** | Shared gap with Holy |
| Pre-heal system | ❌ **MISSING** | Shared gap with Holy |
| Fade auto-use | ❌ **MISSING** | Not implemented in discipline |
| Healthstone auto-use | ❌ **MISSING** | Not implemented in discipline |
| Idle DPS (SW:P, Smite, Holy Fire) | ✅ | `idle_swp_matches`, `idle_smite_matches` |

### Top Gaps for Testing
1. **Healthstone auto-use** — same as Holy Priest gap
2. **Fade aggro drop**

---

## ✅ 3. Enhancement Shaman (1099 lines — `enhancement_sylvanas.lua`)

### Status: LARGELY COMPLETE
This is the most comprehensive implementation at 1099 lines. Covers:
- ✅ Stormstrike, Flame/Shock, Chain Lightning, Lightning Bolt
- ✅ All 4 totem types + twisting (WF/GoA)
- ✅ MH/OH weapon buffs (Rockbiter, Flametongue, Windfury, Frostbrand)
- ✅ Lightning Shield, Water Shield, Auto shield mode
- ✅ Ghost Wolf, Totemic Call
- ✅ Healing Wave, Lesser Healing Wave, Gift of the Naaru
- ✅ Bloodlust, Shamanistic Rage, Nature's Swiftness
- ✅ Racial cooldowns (Blood Fury, Berserking)
- ✅ Auto-interrupt (Earth Shock for interrupts)
- ✅ Mana Tide Totem
- ✅ Tremor Totem support
- ✅ Fire Nova → Magma twist cycle

### Potential Minor Gaps
- Leveling spell rank auto-detection level ranges
- Some utility toggles might not exactly match Frost.txt config

### Top Gaps for Testing
1. **Weapon buff timer refresh** (25 min auto-recast)
2. **Shield auto-switching** (Lightning → Water at mana threshold)
3. **Totem twisting timing** (WF → GoA sub-second switching)

---

## ✅ 4. Affliction Warlock (682 lines — `affliction_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| UA, Corruption, Siphon Life, CoA, CoD | ✅ | All DoTs implemented |
| Immolate, Seed of Corruption | ✅ | Multi-target support |
| Shadow Bolt filler | ✅ | Primary filler |
| Drain Soul execute | ✅ | <25% HP execute |
| Amplify Curse | ✅ | Auto-use before Agony/Doom |
| Death Coil defensive | ✅ | Survival utility |
| Soulshatter | ✅ | Threat management |
| Create Healthstone | ✅ | Auto-create |
| Life Tap sustain | ❌ **MISSING** | Not found in grepped references |
| Dark Pact sustain | ❌ **MISSING** | Not found |
| Nightfall/Shadow Trance proc | ❌ **MISSING** | Instant Shadow Bolt proc detection |
| Pet automation | ❌ **UNCLEAR** | Auto-summon not seen |
| Fire immune detection | ❌ **MISSING** | Auto-switch to fire spells |
| Wand Mode conservation | ❌ **MISSING** | Auto-wand at mana thresholds |
| Soulstone auto-use | ❌ **MISSING** | Auto-buff with Soulstone |

### Top Gaps for Testing
1. **Life Tap auto-sustain** (mana < threshold, hp > threshold)
2. **Nightfall proc detection** (instant Shadow Bolt)
3. **Fire immune mob detection** (skip shadow DoTs)
4. **Wand Mode mana conservation**

---

## ✅ 5. Fury Warrior (612 lines — `fury_sylvanas.lua`)

### Status: MOSTLY COMPLETE
Very comprehensive implementation with 612 lines. Already has:
- ✅ STRATEGY_SPECS with full rotation
- ✅ Charge/Intercept with auto_charge toggle
- ✅ Bloodrage, Victory Rush, Healthstone
- ✅ Recklessness, Death Wish
- ✅ Rampage stack management
- ✅ Overpower, Bloodthirst, Rend, Sunder
- ✅ Sweeping Strikes, Whirlwind, Execute, Slam
- ✅ Heroic Strike, Cleave rage dump
- ✅ Demo Shout, Thunder Clap
- ✅ Hamstring, Pummel, Berserker Rage
- ✅ Battle/Berserker stance management

### Minor Gaps
| Feature | Status | Notes |
|---------|--------|-------|
| Health potion fallback | ❌ **MISSING** | Frost.txt says "Both" healthstone + potion |
| Sticky Target | ❌ **MISSING** | Not seen |
| Raid Markers priority | ❌ **MISSING** | Not seen |
| On-use trinkets | ❌ **MISSING** | Not seen in Fury (has in Arms pattern) |

### Top Gap for Testing
1. **Health potion as fallback** when healthstone not available
2. **On-use trinket activation** during Recklessness/Death Wish windows

---

## ✅ 6. Elemental Shaman (228 lines — `elemental_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Lightning Bolt, Chain Lightning | ✅ | Core fillers |
| Flame Shock, Earth Shock, Frost Shock | ✅ | Shocks implemented |
| Elemental Mastery, Nature's Swiftness | ✅ | Cooldowns |
| Bloodlust | ✅ | Burst |
| Lightning Shield, Water Shield | ✅ | Shield selection |
| Ghost Wolf | ✅ | OOC movement |
| Tremor Totem, Earthbind Totem | ✅ | Utility totems |
| Mana Tide Totem | ✅ | Mana recovery |
| Chain Heal | ✅ | Emergency healing |
| **Weapon buffs (Flametongue)** | ❌ **MISSING** | Not implemented |
| **Earth/Fire/Water/Air totem management** | ❌ **MISSING** | Only Tremor/Earthbind/Mana Tide present |
| **Mana conserve/dump modes** | ❌ **MISSING** | Frost.txt config for conserve threshold |
| **Totemic Call auto-recall** | ❌ **MISSING** | Recall totems for mana refund |
| **Self-healing (Healing Wave)** | ❌ **MISSING** | Chain Heal exists but not regular HW |

### Top Gaps for Testing
1. **Weapon buffs** (Flametongue auto-apply)
2. **Mana conservation mode** (switch to cheaper spells when low mana)
3. **Totem management** (auto-drop Earth/Fire/Water totems based on selection)

---

## ✅ 7. Protection Warrior (519 lines — `protection_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| build_state + matches functions | ✅ | Defined at line 72 |
| Sunder Armor | ✅ | `sunder_matches_fn` |
| Shield Bash / Pummel interrupts | ✅ | Match functions exist |
| **Shield Block (4 modes)** | ❌ **UNCLEAR** | Need to verify |
| **Shield Wall, Last Stand** | ❌ **UNCLEAR** | Need to verify |
| **Auto taunt (Taunt + Challenging Shout)** | ❌ **UNCLEAR** | Need to verify |
| **Auto-charge opener** | ❌ **UNCLEAR** | Need to verify |
| **Rage management (HS/Cleave/Bloodrage)** | ❌ **UNCLEAR** | Need to verify |
| **On-use trinkets** | ❌ **UNCLEAR** | Not found in limited grep |

### Top Gaps for Testing
(Need more implementation data — current grep limited)

---

## ✅ 8. Destruction Warlock (319 lines — `destruction_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Immolate, Conflagrate | ✅ | Core spells implemented |
| Shadow Bolt, Incinerate | ✅ | Fillers |
| Soul Fire, Searing Pain | ✅ | Fire build spells |
| Rain of Fire, Hellfire, Seed of Corruption | ✅ | AoE spells |
| Demon Armor, Shadow Ward, Drain Life, Health Funnel | ✅ | Utility/defensive |
| Dark Pact, Create Healthstone | ✅ | Sustain |
| All pets + Fel Domination | ✅ | Pet management |
| Fel Armor buff | ✅ | `SPELLS.FelArmor` |
| **Dual build auto-detect (Fire vs Shadow)** | ❌ **MISSING** | Build selection not seen |
| **Mana Gem usage** | ❌ **MISSING** | Auto-use Mana Gem at threshold |
| **Shadowburn execute** | ❌ **MISSING** | <5s TTD execute |
| **Soulshatter threat management** | ❌ **MISSING** | High threat/aggro modes |
| **Conflagrate movement check** | ❌ **MISSING** | Allow Conflagrate while moving |
| **Cast cancellation** | ❌ **MISSING** | Cancel long casts if target <3s TTD |
| **Fire immune mob detection** | ❌ **MISSING** | Skip fire spells on immune |
| **Death Coil defensive threshold** | ❌ **MISSING** | HP-gated auto-use |

### Top Gaps for Testing
1. **Mana Gem auto-use** at configurable mana threshold
2. **Shadowburn execute** on low TTD targets
3. **Conflagrate movement** (cast while moving if target has Immolate)
4. **Soulshatter threat management** (high threat/aggro only modes)

---

## ✅ 9. Balance Druid (380 lines — `balance_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Starfire, Wrath | ✅ | Primary nuke + filler |
| Moonfire | ✅ | Tracked + applied |
| Insect Swarm | ✅ | Tracked via `NS.debuff_remains` |
| Faerie Fire | ❌ **MISSING** | Not found in grep — should auto-apply |
| Hurricane (3+ enemies) | ✅ | Configurable threshold |
| Barkskin during Hurricane | ✅ | `balance_barkskin_hp` setting |
| Moonkin Form auto | ✅ | `balance_moonkin_auto` setting |
| Force of Nature (treants) | ✅ | `use_cooldowns` setting gate |
| Mana conservation floor | ✅ | Mana potions with min_mana thresholds |
| Innervate | ✅ | Self-cast |
| Rebirth | ✅ | Combat res |
| Thorns | ✅ | Self-buff |
| Cyclone, Entangling Roots, Nature's Grasp | ✅ | CC spells |
| **War Stomp (4+ melee enemies)** | ❌ **MISSING** | Not found — should stun on AoE |
| **Mark of the Wild** | ❌ **MISSING** | Party/raid buff not seen |

### Top Gaps for Testing
1. **Faerie Fire auto-application** on target (armor reduction)
2. **War Stomp** when 4+ enemies in melee range
3. **Mark of the Wild / Thorns auto-buff** maintenance

---

## ✅ 10. Survival Hunter (292 lines — `survival_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Kill Command | ✅ | Off-GCD BM core |
| Hunter's Mark | ✅ | Applied on target |
| Rapid Fire | ✅ | Cooldown |
| Readiness | ✅ | Burst window (RF → Readiness → RF) |
| Multi-Shot | ✅ | AoE conditional |
| Steady Shot | ✅ | Primary filler (62+) |
| Arcane Shot | ✅ | Instant filler |
| Serpent Sting | ✅ | DoT application |
| Viper Sting | ✅ | Mana drain |
| Aspect Hawk, Aspect Viper | ✅ | Dynamic switching |
| Mend Pet, Call Pet, Revive Pet | ✅ | Pet management |
| Feign Death | ✅ | Auto FD on high threat |
| Explosive Trap | ✅ | AoE trap |
| Freezing Trap | ✅ | CC trap |
| **Concussive Shot** | ❌ **MISSING** | Kiting slow not implemented |
| **Raptor Strike melee weaving** | ❌ **MISSING** | Melee range auto-attack |
| **Wing Clip** | ❌ **MISSING** | Slow when kiting |
| **Misdirection** | ❌ **MISSING** | Threat redirection (Pet/Focus) |
| **Volley AoE** | ❌ **MISSING** | Ranged AoE not implemented |
| **Scorpid Sting** | ❌ **MISSING** | Only Serpent + Viper present |
| **Auto-shot timer** | ❌ **MISSING** | Frost.txt mentions latency compensation, dead zone circles |
| **Dead Zone circles display** | ❌ **MISSING** | Visual range indicators |

### Top Gaps for Testing
1. **Concussive Shot kiting** (8y+ range gate, toggle)
2. **Misdirection** (Pet/Focus target)
3. **Volley AoE** (3+ enemy threshold)
4. **Scorpid Sting** (debuff mode selection)

---

## ✅ 11. Restoration Shaman (358 lines — `restoration_sylvanas.lua`)

### Implementation Status
| Feature | Status | Notes |
|---------|--------|-------|
| Water Shield | ✅ | Self-buff maintenance |
| Earth Shield | ✅ | Tank-target maintenance |
| Chain Heal | ✅ | Raid healing |
| Healing Wave, Lesser Healing Wave | ✅ | Single target heals |
| Nature's Swiftness | ✅ | Emergency combo |
| Totem framework | ✅ | Duration tracking present |
| **Intelligent rank selection** | ❌ **MISSING** | Downranking HW/LHW/CH not found |
| **Solo/Raid mode detection** | ❌ **MISSING** | Auto-detect group size not found |
| **Healing Way stacking** | ❌ **MISSING** | R1 HW to stack buff before big heals |
| **Pushback awareness** | ❌ **MISSING** | Detect pushback/damage during cast |
| **Chain Heal simulation** | ❌ **MISSING** | Predict how many it will hit |
| **Prehealing system** | ❌ **MISSING** | Queue heals before damage lands |
| **Cancel-casting** | ❌ **MISSING** | Stop cast if target recovers above threshold |
| **Overheal protection** | ❌ **MISSING** | Skip heal if target near full HP |

### Top Gaps for Testing
1. **Healing Way stacking** (R1 HW before big heals)
2. **Rank selection** (downrank based on damage required)
3. **Solo/Raid mode auto-detection**

---

## Top Priority Gaps for Testing (All Specs)

| Priority | Spec | Gap | Rationale |
|----------|------|-----|-----------|
| 🔴 HIGH | Balance Druid | Faerie Fire auto-application | Core debuff, Frost.txt specified |
| 🔴 HIGH | Survival Hunter | Concussive Shot kiting | Core utility for kiting |
| 🔴 HIGH | Survival Hunter | Misdirection | Threat management for dungeons/raids |
| 🔴 HIGH | Destruction Warlock | Mana Gem auto-use | Core mana sustain |
| 🟡 MEDIUM | Balance Druid | War Stomp AoE stun | CC for AoE pulls |
| 🟡 MEDIUM | Destruction Warlock | Shadowburn execute | Execute mechanic |
| 🟡 MEDIUM | Elemental Shaman | Weapon buffs | Core DPS mechanic |
| 🟡 MEDIUM | Holy/Discipline Priest | Healthstone auto-use | Off-GCD survival |
| 🟡 MEDIUM | Restoration Shaman | Healing Way stacking | Healing throughput |
| 🟢 LOW | Fury Warrior | Health potion fallback | Nice-to-have |
| 🟢 LOW | Affliction Warlock | Life Tap sustain | Mana management |
| 🟢 LOW | Survival Hunter | Volley AoE | AoE throughput |

---
*Analysis generated from Frost.txt vs EaxRotations/classes/ implementations on 2026-05-18*
