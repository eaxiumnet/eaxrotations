# Phase 2 Audit: Missing TBC Mechanics in EaxRotations Thin Specs

**Audit Date:** 2025-07-14
**Auditor:** Buffy / Codebuff
**Scope:** 13 spec files identified as "thin" vs. TBC research baseline
**Baseline:** Upgraded specs (frost_sylvanas: 131 lines, demonology_sylvanas: 124 lines, cat_sylvanas: 155 lines)

---

## Executive Summary

| Spec | Lines | Severity | Key Missing Mechanics |
|------|-------|----------|----------------------|
| Rogue Assassination | 36 | 🔴 CRITICAL | Envenom, Cold Blood, poisons, Shiv, energy tick, Find Weakness |
| Rogue Subtlety | 35 | 🔴 CRITICAL | Shadowstep, Premeditation, Ghostly Strike, Hemorrhage debuff tracking, Preparation |
| Hunter Marksmanship | 77 | 🔴 CRITICAL | Aspect management, pet abilities, Feign Death, Readiness, Scatter Shot, Silencing Shot |
| Hunter Survival | 76 | 🔴 CRITICAL | Wyvern Sting, traps (Immolation/Freezing), Counterattack, Deterrence, Aspect management |
| Shaman Restoration | 99 | 🟡 HIGH | Totem management (Healing Stream, Poison Cleansing), Purge, interrupt, LHW vs HW decision |
| Shaman Enhancement | 149 | 🟡 HIGH | Windfury Weapon tracking, shock rotation, Stormstrike debuff consumption, Ghost Wolf OOC |
| Paladin Retribution | 152 | 🟡 HIGH | Blessing of Freedom, Divine Shield/Protection, Cleanse, Repentance, Judgement of Wisdom/Light |
| Priest Shadow | 171 | 🟡 HIGH | Power Word: Shield emergency, Fear/Psychic Scream, Silence, SW:P pandemic, Mind Flay optimization |
| Warlock Affliction | 177 | 🟡 HIGH | Seed of Corruption, Drain Soul shard farming, pet management (Succubus/Felhunter), Soulshatter |
| Rogue Combat | 190 | 🟡 HIGH | Poisons, Thistle Tea, Combat Potency, Relentless Strikes energy, Evasion/Vanish defensives |
| Shaman Elemental | 220 | 🟢 MEDIUM | Fire Nova/Magma Totem, Searing Totem, Clearcasting (Elemental Focus), Frost Shock snare |
| Warlock Destruction | 322 | 🟢 MEDIUM | Pet management, Incinerate vs Shadow Bolt decision, Rain of Fire vs Hellfire logic |
| Warrior Protection | 528 | 🟢 MEDIUM | Shield Slam threat optimization, rage generation optimization, Sunder vs Devastate at low rage |

---

## Detailed Gap Analysis by Spec

### 1. ROGUE ASSASSINATION (36 lines) — 🔴 CRITICAL

**Current:** Basic action rows only — Stealth, Garrote, SliceAndDice, Rupture, Mutilate, Eviscerate.

**Missing TBC Mechanics:**
1. **Envenom** — TBC-trained finisher (32684). Consumes Deadly Poison stacks for burst damage. Core to Assassination identity.
2. **Cold Blood** — Assassination talent (14177). +100% crit on next offensive ability. 3 min CD.
3. **Shiv** — TBC-trained ability (5938). Instant poison application, refreshes Deadly Poison. Critical for maintaining DP stacks between Envenoms.
4. **Deadly Poison stack tracking** — Need to track DP stacks (0-5) on target to gate Envenom usage. Should not Envenom with <4 stacks.
5. **Instant Poison / Wound Poison** — While rotation doesn't auto-apply, it should track which poison is active for Mutilate bonus (+50% vs poisoned).
6. **Find Weakness** — Assassination talent debuff (31234). +10% armor pen for 10s after stealth opener.
7. **Energy tick optimization** — No energy pooling/spending logic like Combat has.
8. **Build_state() pattern** — Missing entirely. No debuff/buff state caching.
9. **Custom matches functions** — No gating beyond basic action_matches.
10. **Evasion / Cloak of Shadows / Vanish** — No defensive middleware.
11. **Expose Armor** — Alternative finisher when Sunder is not present (-2050 armor at 5CP).
12. **Kidney Shot** — Stun finisher for emergency CC or stunlock windows.

**Recommended Priority:** This is the thinnest spec. Upgrade to match Combat's depth (190+ lines).

---

### 2. ROGUE SUBTLETY (35 lines) — 🔴 CRITICAL

**Current:** Stealth, Ambush, Hemorrhage, Rupture, Eviscerate.

**Missing TBC Mechanics:**
1. **Shadowstep** — Subtlety 41pt talent (36554). Teleport behind target +20% damage buff on next ability. 30s CD.
2. **Premeditation** — Subtlety talent (14183). Adds 2 CP from stealth.
3. **Ghostly Strike** — Subtlety talent (14278). 125% wep, +15% dodge 7s. 20s CD. Secondary builder.
4. **Preparation** — Subtlety talent (14185). Resets Evasion, Sprint, Vanish, Cold Blood, Shadowstep. 10 min CD.
5. **Hemorrhage debuff tracking** — +42 phys dmg taken, 10 charges, 15s. Needs charge count to know when to reapply.
6. **Master of Subtlety** — Talent: +10% damage for 6s after leaving stealth.
7. **Slice and Dice** — Not even present! Subtlety PVE maintains SnD.
8. **Cloak of Shadows** — TBC baseline defensive (31224). Remove spells +90% spell resist.
9. **Blind / Gouge / Sap** — CC abilities for PvP.
10. **Build_state() pattern** — Missing entirely.

**Recommended Priority:** Even thinner than Assassination. Must add build_state + Shadowstep + SnD at minimum.

---

### 3. HUNTER MARKSMANSHIP (77 lines) — 🔴 CRITICAL

**Current:** MendPet, HuntersMark, RapidFire, AimedShotPrepull, KillCommand, MultiShot, SteadyShot, ArcaneShot, SerpentSting.

**Missing TBC Mechanics:**
1. **Aspect management** — Hawk (offensive), Cheetah (movement), Viper (mana regen). Core Hunter mechanic.
2. **Steady Shot weaving** — While present, lacks full weaving logic (haste effects, weapon speed consideration).
3. **Feign Death** — Emergency threat drop + trap prep. TBC core utility.
4. **Readiness** — Marksman talent. Resets all shot CDs. 5 min CD.
5. **Scatter Shot** — Marksman talent. 4s disorient. 30s CD.
6. **Silencing Shot** — Marksman talent. 3s silence. 20s CD.
7. **Concussive Shot** — 4s slow. Kiting essential.
8. **Scorpid Sting** — -3% hit debuff. Tank support.
9. **Pet management** — Growl, Bite/Claw, pet heal, pet passive/defensive stance.
10. **Trueshot Aura** — BM talent (but MM sometimes has it). Party buff.
11. **Build_state() pattern** — Missing entirely.
12. **Viper Sting** — Mana drain on target (PvP).

**Recommended Priority:** Hunter is fundamentally about aspects and pet. Both missing.

---

### 4. HUNTER SURVIVAL (76 lines) — 🔴 CRITICAL

**Current:** MendPet, HuntersMark, RapidFire, ExplosiveTrap, KillCommand, MultiShot, SteadyShot, ArcaneShot, SerpentSting.

**Missing TBC Mechanics:**
1. **Wyvern Sting** — Survival talent. 12s sleep, then 12s DoT. 1 min CD. Core Survival identity.
2. **Freezing Trap** — CC trap. 26s freeze. Essential for dungeon/raid utility.
3. **Immolation Trap** — Fire DoT trap. DPS trap alternative.
4. **Counterattack** — Survival talent. After parry, root + damage.
5. **Deterrence** — +25% parry, +25% dodge, 10s. Defensive.
6. **Aspect management** — Same as MM (Hawk/Cheetah/Viper).
7. **Feign Death** — Same as MM.
8. **Explosive Trap** — Present but lacks proper ground placement logic.
9. **Trap Launcher** — Not TBC (Cata). Do not implement.
10. **Melee weaving** — Survival has talents for close-range combat (Mongoose Bite, Raptor Strike).

**Recommended Priority:** Survival's identity is traps + Wyvern. Both largely missing.

---

### 5. SHAMAN RESTORATION (99 lines) — 🟡 HIGH

**Current:** WaterShield, EarthShieldTank, Nature'sSwiftness, ManaTideTotem, Bloodlust, SmartHeal.

**Missing TBC Mechanics:**
1. **Totem management** — Healing Stream Totem, Poison Cleansing Totem, Disease Cleansing Totem, Mana Spring Totem (enhancement usually does this but Resto should have fallback).
2. **Chain Heal bounce optimization** — SmartHeal exists but no explicit bounce targeting (jumps to lowest within 40yd).
3. **Lesser Healing Wave vs Healing Wave** — LHW for fast emergency, HW for big slow heals. No distinction.
4. **Earth Shield stack tracking** — Earth Shield has 6 charges. Needs reapplication before charges expire.
5. **Purge** — Dispel enemy buffs. Critical PvP and some PvE.
6. **Wind Shock / Earth Shock interrupt** — Resto should interrupt when healing not needed.
7. **Ancestral Fortitude** — Talent buff on healed target (+25% armor). Should track.
8. **Nature's Guardian** — Talent: automatic self-heal when HP drops.
9. **Tidal Focus / Tidal Mastery** — Mana efficiency and crit talents should inform heal selection.

**Recommended Priority:** Resto is functional but lacks totem depth and heal variety.

---

### 6. SHAMAN ENHANCEMENT (149 lines) — 🟡 HIGH

**Current:** Totem twisting (Windfury/Grace), StrengthOfEarth, ManaSpring, LightningShield, ShamanisticRage, Bloodlust, Stormstrike, FlameShock, EarthShock.

**Missing TBC Mechanics:**
1. **Windfury Weapon imbue tracking** — Enhancement's core mechanic. Must track WF weapon buff on MH/OH.
2. **Flametongue / Frostbrand weapon imbues** — Alternative weapon buffs.
3. **Shock rotation** — Earth Shock (interrupt), Frost Shock (snare), Flame Shock (DoT). No priority system.
4. **Stormstrike debuff consumption** — Stormstrike applies Nature debuff (+20% nature dmg). Should track and prioritize shocks while debuff active.
5. **Shamanistic Rage optimization** — Reduces mana cost and gives mana on hits. Should sync with high-cost spells.
6. **Ghost Wolf OOC** — Missing. Present in Elemental but not Enhancement.
7. **Lightning Shield refresh** — Present as action but no explicit refresh logic with state.
8. **Fire Nova Totem / Magma Totem** — AoE totems for multi-target.
9. **Searing Totem** — Fire damage totem. DPS totem.
10. **Rockbiter Weapon** — Tank weapon imbue (if off-tanking).

**Recommended Priority:** WF weapon tracking is Enhancement's core identity. Critical gap.

---

### 7. PALADIN RETRIBUTION (152 lines) — 🟡 HIGH

**Current:** SealTwistBlood, SealTwistPrepCommand, SealBloodFallback, SealCommandFallback, AvengingWrath, CrusaderStrike, Judgement, HammerOfWrath, Exorcism, Consecration.

**Missing TBC Mechanics:**
1. **Blessing of Freedom** — Remove snare/root. Critical PvP and some PvE.
2. **Divine Shield** — 12s immunity. 5 min CD. Major defensive.
3. **Divine Protection** — 10s -50% physical damage. 3 min CD.
4. **Cleanse** — Remove poison/disease/magic. Utility.
5. **Repentance** — Retribution talent. 6s incapacitate. 1 min CD. PvP essential.
6. **Judgement of Wisdom / Light** — While not damage seals, JoW gives mana regen to raid, JoL gives healing. Should have toggle.
7. **Sanctity Aura** — +10% holy damage. Should track and maintain.
8. **Turn Evil** — Fear undead/demon. 15s.
9. **Hand of Sacrifice** — Not TBC (WotLK). Do NOT implement.
10. **Build_state() for seal buffs** — Has basic state but could be richer (seal duration, swing timer sync).

**Recommended Priority:** Ret is decent but missing core utility. Blessing of Freedom + Divine Shield are must-haves.

---

### 8. PRIEST SHADOW (171 lines) — 🟡 HIGH

**Current:** Shadowform, Shadowfiend, VampiricTouch, ShadowWordPain, VampiricEmbrace, InnerFocus+MindBlast, MindBlast, ShadowWord:Death, MindFlay.

**Missing TBC Mechanics:**
1. **Power Word: Shield** — Emergency shield on self or target. Critical survivability.
2. **Fear / Psychic Scream** — AoE fear. PvP and dungeon utility.
3. **Silence** — Shadow talent. 5s silence. 45s CD.
4. **Dispel Magic** — Remove enemy buffs or friendly debuffs.
5. **Shadow Word: Pain pandemic** — Has basic refresh=3 but no explicit pandemic window calculation.
6. **Mind Flay stack optimization** — Has basic tick clipping via mf_tick_compute but no explicit 2-tick vs 3-tick decision based on upcoming events.
7. **Shadow Weaving** — Talent debuff (+2% shadow dmg per stack, 5 stacks). Should track and maintain.
8. **Vampiric Touch raid healing** — VT gives mana to group. Should consider group mana when casting.
9. **Pain Suppression** — Discipline talent (if Disc/Shadow hybrid). 40% dmg reduction.
10. **Desperate Prayer** — Emergency self-heal. 10 min CD.

**Recommended Priority:** Shadow is the most complete of the thin specs but missing key utility.

---

### 9. WARLOCK AFFLICTION (177 lines) — 🟡 HIGH

**Current:** DemonArmor, FelArmor, ShadowWard, DeathCoil, NightfallShadowBolt, AmplifyCurse, CurseOfDoom, UnstableAffliction, Corruption, SiphonLife, CurseOfAgony, ShadowEmbrace, Fear, HowlOfTerror, CurseOfWeakness, CurseOfTongues, DrainSoul, DrainLife, ShadowBolt, DarkPact, LifeTap, HealthFunnel, DrainMana, CreateHealthstone, SoulstoneResurrection.

**Missing TBC Mechanics:**
1. **Seed of Corruption** — TBC AoE spell (27243). Explodes after 1044 shadow damage. Core Affliction AoE.
2. **Drain Soul shard farming** — Should optimize shard generation when below threshold.
3. **Pet management** — Succubus seduce, Felhunter devour magic, Felguard DPS. Only has basic summon logic via LOCAL_SPELLS.
4. **Soulshatter** — Threat drop. 30 min CD (TBC). Critical for raiding.
5. **Howl of Terror** — Present but no instant-cast logic (Nightfall makes it instant).
6. **Shadow Embrace stacking** — Tracks remains but not stack count (up to 5 stacks, -5% healing).
7. **Unstable Affliction dispel protection** — UA silences dispeller. PvP consideration.
8. **Fel Concentration** — Talent: reduces pushback on Drain spells. Should inform casting decisions.
9. **Suppression** — Talent: +hit for Affliction spells. Should inform spell hit checks.

**Recommended Priority:** Affliction is fairly complete for DoTs but missing Seed and pet management.

---

### 10. ROGUE COMBAT (190 lines) — 🟡 HIGH

**Current:** Energy tick optimization, BF+AR sync, SND/Rupture cycle, SinisterStrike.

**Missing TBC Mechanics:**
1. **Poisons** — Same as Assassination (Instant/Deadly tracking).
2. **Thistle Tea** — +100 energy instant. 5 min CD. Energy recovery.
3. **Combat Potency** — Talent: 20% chance for 15 energy on OH hit. Informs energy decisions.
4. **Relentless Strikes** — Talent: 20% per CP to restore 25 energy on finisher. Informs finisher timing.
5. **Evasion / Sprint / Vanish** — Defensive/emergency abilities.
6. **Kick** — Interrupt. 10s CD. Very efficient.
7. **Feint** — Threat reduction. 20 energy.
8. **Weapon swap logic** — Combat uses swords/fists, but some fights need daggers for Backstab.
9. **Blade Flurry cleave optimization** — Present but no explicit "skip Rupture during BF, use Eviscerate" logic.
10. **Adrenaline Rush energy cap prevention** — During AR, energy regen is 40/2s. Need to prevent capping.

**Recommended Priority:** Combat is the most complete Rogue spec but still missing defensives and energy talents.

---

### 11. SHAMAN ELEMENTAL (220 lines) — 🟢 MEDIUM

**Current:** LightningShield, WaterShield, GhostWolf, TremorTotem, EarthbindTotem, ManaTideTotem, ElementalMastery, Nature'sSwiftness, Bloodlust, ChainLightning, LightningBolt, FlameShock, EarthShock interrupt, ChainHeal, movement fillers.

**Missing TBC Mechanics:**
1. **Fire Nova Totem / Magma Totem** — AoE fire totems for multi-target.
2. **Searing Totem** — Single-target fire DPS totem.
3. **Frost Shock snare** — Present in movement filler but no explicit kiting logic.
4. **Clearcasting (Elemental Focus)** — Talent: clearcasting after crit. Should track and prioritize Chain Lightning during clearcast.
5. **Lightning Overload** — Talent: 10% chance for free duplicate LB/CL. Not trackable easily but should be mentioned.
6. **Flame Shock clipping optimization** — Has should_refresh_dot but no explicit "clip for Lava Burst" (Lava Burst is WotLK).
7. **Totem of Wrath** — TBC totem (+3% crit, +3% hit for party). 36y range.
8. **Earth Shock threat reduction** — ES reduces threat. Should use when high threat.

**Recommended Priority:** Elemental is quite complete. Missing totem variety and clearcasting.

---

### 12. WARLOCK DESTRUCTION (322 lines) — 🟢 MEDIUM

**Current:** build_state, Backlash/Backdraft, Conflagrate, execute, AoE, utility, FelArmor, DemonArmor, ShadowWard, LifeTap, DarkPact, DrainLife, HealthFunnel, CoD, CoA, Corruption, Immolate, SoulFire, Shadowburn, SearingPain, Incinerate, ShadowBolt, SeedOfCorruption, RainOfFire, Hellfire, DeathCoil, Fear, pet summons.

**Missing TBC Mechanics:**
1. **Pet management** — Has summons but no active pet abilities (Imp Blood Pact, Succubus seduce, Felhunter devour).
2. **Incinerate vs Shadow Bolt decision** — Currently gates Incinerate by Immolate present, but no explicit DPS comparison or haste consideration.
3. **Rain of Fire vs Hellfire decision** — Both present but no explicit "Hellfire when stationary + 4+ enemies, RoF when moving" logic.
4. **Conflagrate consume optimization** — Currently just checks Immolate present. Should consider "consume at low remaining duration for max ticks."
5. **Soul Fire pre-cast** — Long cast time (6s). Should pre-cast before pull.
6. **Shadowfury** — WotLK talent. Do NOT implement.
7. **Curse of Recklessness** — +AP, -armor. Situational curse.
8. **Curse of the Elements** — +shadow/fire dmg taken. Raid utility.

**Recommended Priority:** Destruction is the most complete Warlock spec. Minor gaps in pet abilities and spell decision logic.

---

### 13. WARRIOR PROTECTION (528 lines) — 🟢 MEDIUM

**Current:** Stance management, sunder stacking, devastate, thunderclap, demo shout, shield block, taunts, interrupts, PvP utility, emergency defensives, rage dump, execute.

**Missing TBC Mechanics:**
1. **Shield Slam threat optimization** — Has basic Shield Slam but no explicit threat value consideration (SS is highest threat).
2. **Rage generation optimization** — No explicit "save rage for Shield Block after heroic strike" logic.
3. **Sunder Armor vs Devastate at low rage** — Devastate does weapon damage + sunder application. At low rage, Sunder is cheaper. No explicit decision.
4. **Shield Block value tracking** — SB has 2 charges. Should track remaining charges.
5. **Last Stand optimization** — Present but no explicit "use at X% HP with Y enemies" logic.
6. **Shield Wall macro timing** — 30 min CD in TBC. Should be very conservative.
7. **Heroic Strike vs Cleave decision** — Has both but no explicit "HS for single-target threat, Cleave for 2+" logic beyond basic enemy_count.
8. **Revenge proc optimization** — Revenge is very cheap (5 rage) and high threat. Should prioritize over Devastate when available.
9. **Concussion Blow threat** — CB is high threat. Should use in rotation, not just PvP.
10. **Vigilance** — WotLK. Do NOT implement.

**Recommended Priority:** Protection is very complete. Gaps are optimization nuances, not missing abilities.

---

## Cross-Cutting Gaps (All Specs)

### Missing from ALL thin specs:
1. **Middleware integration** — Defensive triggers, interrupts, racials, trinkets, burst detection
2. **PvP vs PvE mode detection** — Some specs have `is_pvp` checks but no unified detection
3. **TTD (time-to-death) integration** — Only some specs use `context.ttd` for finisher decisions
4. **Settings integration** — Many specs lack menu-toggle integration for optional abilities
5. **Logging / telemetry** — Minimal debug logging beyond `NS.log()` at registration

---

## Upgrade Recommendations (Priority Order)

### Wave 1: Critical (35-77 line specs)
| # | Spec | Target Lines | Key Additions |
|---|------|-------------|---------------|
| 1 | Rogue Assassination | 180+ | Envenom, Cold Blood, Shiv, DP tracking, energy tick, build_state |
| 2 | Rogue Subtlety | 180+ | Shadowstep, Premeditation, Ghostly Strike, SnD, build_state |
| 3 | Hunter Marksmanship | 150+ | Aspect management, Feign Death, Readiness, pet management, build_state |
| 4 | Hunter Survival | 150+ | Wyvern Sting, traps, Counterattack, Aspect management, build_state |

### Wave 2: High (99-190 line specs)
| # | Spec | Target Lines | Key Additions |
|---|------|-------------|---------------|
| 5 | Shaman Restoration | 160+ | Totem management, LHW/HW distinction, Purge, interrupt |
| 6 | Shaman Enhancement | 190+ | Windfury Weapon tracking, shock rotation, Stormstrike debuff |
| 7 | Paladin Retribution | 200+ | Divine Shield, Blessing of Freedom, Cleanse, Repentance |
| 8 | Priest Shadow | 210+ | PW:Shield, Fear, Silence, Shadow Weaving tracking |
| 9 | Warlock Affliction | 220+ | Seed of Corruption, Drain Soul optimization, pet abilities |
| 10 | Rogue Combat | 230+ | Poisons, Thistle Tea, defensives, Combat Potency awareness |

### Wave 3: Medium (220-528 line specs)
| # | Spec | Target Lines | Key Additions |
|---|------|-------------|---------------|
| 11 | Shaman Elemental | 260+ | Clearcasting, totem variety, Frost Shock kiting |
| 12 | Warlock Destruction | 360+ | Pet abilities, Conflagrate consume optimization, pre-pull Soul Fire |
| 13 | Warrior Protection | 580+ | Shield Block charge tracking, Sunder vs Devastate logic, threat optimization |

---

## Estimated Effort

| Wave | Specs | Estimated Hours | Complexity |
|------|-------|-----------------|------------|
| Wave 1 | 4 | 16-20 | High (new build_state, many new mechanics) |
| Wave 2 | 6 | 18-24 | Medium (building on existing structure) |
| Wave 3 | 3 | 6-10 | Low (refinements to already-rich specs) |
| **Total** | **13** | **40-54 hours** | — |

---

## Testing Strategy

For each upgraded spec:
1. Add unit tests for new custom `matches` functions (follow pattern: `test_frost_custom_matches.lua`)
2. Verify `luac -p` passes on all modified files
3. Run full test suite to ensure no regressions
4. Validate TBC spell IDs against `flux/docs/` research

---

*End of Audit*
