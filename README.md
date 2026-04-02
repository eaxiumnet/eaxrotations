# EAX TBC Classic Rotations

Internal documentation for the EAX 27-spec rotation pack for WoW TBC 2.4.3 on Project Sylvanas.

**Repository:** https://github.com/eaxiumnet/eax-tbc-classic-rotations  
**Local Path:** `C:\newbot\scripts`  
**Last Updated:** 2026-04-02

---

## Quick Reference

| Need | Location |
|------|----------|
| Edit rotation logic | `EAX<Class><Spec>/main.lua` |
| Edit spell tables | `EAX<Class><Spec>/libraries/spells.lua` |
| Edit utilities | `EAX<Class><Spec>/libraries/utils.lua` |
| Edit menu toggles | `EAX<Class><Spec>/libraries/menu.lua` |
| Shared runtime | `libraries/` |
| Build/package | `tools/export_eax_plugins.py` |
| Validate specs | `lua tools/rotation_validation.lua` |
| Check API compliance | `lua tools/api_hard_gate.lua` |

---

## Spec Overview Matrix

| Class | Spec | Role | Races | Solo | Dungeon | Raid | PvP |
|-------|------|:----:|:-----:|:----:|:-------:|:----:|:---:|
| **Druid** | | | | | | | |
| | Balance | DPS | Night Elf, Tauren | 78% | 76% | 72% | 60% |
| | Feral | Tank/DPS | Night Elf, Tauren | 84% | 80% | 76% | 65% |
| | Restoration | Healer | Night Elf, Tauren | 70% | 92% | 88% | 55% |
| **Hunter** | | | | | | | |
| | Beast Mastery | DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 88% | 84% | 82% | 70% |
| | Marksmanship | DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 82% | 78% | 76% | 68% |
| | Survival | DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 78% | 74% | 72% | 72% |
| **Mage** | | | | | | | |
| | Arcane | DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 76% | 80% | 84% | 75% |
| | Fire | DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 76% | 80% | 82% | 72% |
| | Frost | DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 82% | 86% | 88% | 80% |
| **Paladin** | | | | | | | |
| | Holy | Healer | Human, Dwarf, Blood Elf | 52% | 96% | 94% | 45% |
| | Protection | Tank | Human, Dwarf, Blood Elf | 72% | 94% | 92% | 60% |
| | Retribution | DPS | Human, Dwarf, Blood Elf | 90% | 90% | 88% | 70% |
| **Priest** | | | | | | | |
| | Discipline | Healer | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 55% | 82% | 76% | 75% |
| | Holy | Healer | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 50% | 86% | 82% | 50% |
| | Shadow | DPS | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 84% | 80% | 76% | 70% |
| **Rogue** | | | | | | | |
| | Assassination | DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 88% | 86% | 86% | 80% |
| | Combat | DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 84% | 88% | 84% | 75% |
| | Subtlety | DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 78% | 74% | 70% | 85% |
| **Shaman** | | | | | | | |
| | Elemental | DPS | Orc, Tauren, Troll, Draenei | 76% | 76% | 72% | 65% |
| | Enhancement | DPS | Orc, Tauren, Troll, Draenei | 84% | 84% | 80% | 70% |
| | Restoration | Healer | Orc, Tauren, Troll, Draenei | 70% | 92% | 88% | 55% |
| **Warlock** | | | | | | | |
| | Affliction | DPS | Human, Gnome, Orc, Undead, Blood Elf | 88% | 84% | 84% | 70% |
| | Demonology | DPS | Human, Gnome, Orc, Undead, Blood Elf | 78% | 78% | 74% | 65% |
| | Destruction | DPS | Human, Gnome, Orc, Undead, Blood Elf | 84% | 84% | 84% | 72% |
| **Warrior** | | | | | | | |
| | Arms | DPS | All Races | 84% | 80% | 80% | 75% |
| | Fury | DPS | All Races | 86% | 82% | 78% | 70% |
| | Protection | Tank | All Races | 60% | 92% | 88% | 65% |

**Role Legend:** DPS = Damage Dealer, Tank = Damage Mitigation/Threat, Healer = Health Restoration

**Score Guide:** 90-100 = Strong fit, 75-89 = Very usable, 60-74 = Workable with caveats, <60 = Partial implementation

---

## Detailed Spec Rotations

### DRUID

#### Balance (Moonkin DPS)

**Core Concept:** Maintain two DoTs while casting the appropriate nuke based on fight duration and mana. Eclipseless TBC design.

**Priority Order:**
1. **Faerie Fire** - Keep on target for armor reduction (3% hit for raid). Cast immediately if missing.
2. **Moonfire** - Maintain DoT. Refresh at <3 seconds remaining (no clipping).
3. **Insect Swarm** - Maintain DoT. Refresh at <3 seconds remaining.
4. **Starfire** - Primary nuke. Use when no DoTs need refreshing and mana allows.
5. **Wrath** - Fast cast filler. Use when moving or for quick damage.
6. **Hurricane** - AoE only. Cast when 3+ targets stacked.

**When to Use What:**
- **Fight start:** Faerie Fire -> Moonfire -> Insect Swarm -> Starfire spam
- **DoT management:** Never clip existing DoTs. Wait for them to fall before refreshing.
- **Mana conservation:** Drop to Wrath only if mana <20%. Otherwise maintain Starfire.
- **Movement:** Use Wrath while moving (1.5s cast vs 3.5s Starfire).
- **Execute (<20% HP):** Continue Starfire. Balance has no execute mechanic.

**Cooldowns:**
- **Force of Nature** (Treants): Use on cooldown for single target. Manual placement preferred.
- **Innervate:** Self-use when mana <30%, or cast on healer if they request.

**Why This Works:**
TBC Balance is a simple priority system. Two DoTs provide sustained damage, Starfire provides burst. No Eclipse means no proc chasing. The rotation is consistent regardless of fight phase.

---

#### Feral (Cat DPS / Bear Tank)

**Dual Role System:** Automatically detects form and switches priority. No manual mode selection needed.

**Cat DPS Priority:**
1. **Mangle** - Maintain debuff (increases bleed/shred damage by 30%).
2. **Rake** - Maintain DoT. High DPET (damage per execute time).
3. **Rip** - Primary finisher at 5 combo points. Never clip existing Rips.
4. **Ferocious Bite** - Only if target will die before next Rip tick.
5. **Shred** - Combo point builder. Primary spam ability.

**Bear Tank Priority:**
1. **Mangle** - Threat + debuff. Use on cooldown.
2. **Lacerate** - Stack to 5, maintain. Primary threat generator.
3. **Swipe** - AoE threat. Use when 2+ targets.
4. **Demoralizing Roar** - Maintain attack power reduction on all targets.
5. **Frenzied Regeneration** - Defensive cooldown when HP <40%.

**When to Use What:**
- **Cat opener:** Prowl -> Ravage (if stealthed) -> Mangle -> Rake -> Shred to 5cp -> Rip
- **Cat maintenance:** Keep Mangle and Rake up. Build to 5cp, Rip. Never FB unless target dying.
- **Bear opener:** Charge -> Mangle -> Demo Roar -> Lacerate x5
- **Bear AoE:** Swipe spam with Mangle on CD. Keep Demo Roar up.
- **Tank swap:** Build threat on secondary target with Lacerate while primary tank holds boss.

**Why This Works:**
Feral combines DoT maintenance (Rake, Rip) with debuff management (Mangle) and combo point cycling. Bear uses stack-based threat (Lacerate) rather than combo points. Form detection is automatic based on current shapeshift.

---

#### Restoration (Tree Healer)

**Core Concept:** HoT-based healing with Swiftmend burst and reactive cooldowns.

**Priority Order:**
1. **Lifebloom** - Stack to 3 on tank, maintain. Bloom for mana return if safe.
2. **Rejuvenation** - Primary raid heal. Spread across multiple targets.
3. **Regrowth** - Burst heal on low HP targets. Slow cast, high throughput.
4. **Swiftmend** - Consume Rejuv/Regrowth for instant burst. Use on critical damage.
5. **Healing Touch** - Slow, big heal. Only if no HoTs available and target stable.
6. **Tranquility** - Raid cooldown. Channel for massive AoE healing.

**When to Use What:**
- **Tank healing:** Lifebloom x3 (rolling), Rejuv maintained, Regrowth after big hits.
- **Raid healing:** Rejuv on 3-5 targets, Swiftmend anyone who takes spike damage.
- **Predictive:** Pre-HoT targets before expected damage (boss abilities).
- **Mana management:** Allow Lifebloom to bloom for mana return during low damage phases.
- **Emergency:** Nature's Swiftness + Healing Touch for instant big heal.

**Cooldowns:**
- **Nature's Swiftness:** Instant Healing Touch or Regrowth. Use for tank saves.
- **Innervate:** Self at 30% mana, or give to priest/paladin healer.
- **Tranquility:** Use when raid-wide damage incoming (boss abilities, etc).

**Why This Works:**
Resto Druid is proactive healing. HoTs prevent death rather than react to it. Lifebloom rolling on tank provides constant mitigation. The spec rewards anticipating damage rather than reacting to it.

---

### HUNTER

All three Hunter specs share the same base priority with variations for pet focus (BM) and shot weaving (MM/Survival).

**Base Shot Priority (All Specs):**
1. **Kill Command** - On cooldown when pet engaged.
2. **Aimed Shot** - Cast time allowing (not during Auto Shot windup).
3. **Arcane Shot** - Instant filler when steady would clip.
4. **Multi-Shot** - Cleave/AoE only. 3+ targets.
5. **Steady Shot** - Default filler. Casts during Auto Shot cooldown.

**When to Steady vs Arcane:**
- **Steady Shot:** When Auto Shot cooldown >1.5s remaining.
- **Arcane Shot:** When Auto Shot cooldown <1.5s (avoid clipping).
- **General rule:** Steady spam with Aimed on cooldown, Arcane to prevent clipping.

**Aspect Management:**
- **Hawk:** Default DPS aspect.
- **Viper:** Mana <20% and no mana potion available.
- **Monkey:** PvP or when taking physical damage.

---

#### Beast Mastery

**Core Concept:** Pet-centric DPS. 40% of damage comes from pet. Prioritize pet uptime and Kill Command timing.

**Priority Order:**
1. **Kill Command** - Immediately when pet engaged. Check `pet.is_engaged` before cast.
2. **Bestial Wrath** - On cooldown. Sync with pet health >50%.
3. **Intimidation** - Pet stun. Use on dangerous casts or PvP.
4. **Mend Pet** - Keep pet alive. Priority if pet HP <50%.
5. **Standard shot rotation** (Aimed -> Arcane/Steady weave).

**Pet Management:**
- **Engagement check:** Never Kill Command without `pet.is_engaged == true`.
- **Pet positioning:** Pet auto-attacks target. Manual control for dangerous mechanics.
- **Pet autocast:** Mend Pet and Growl managed via `core.input.enable_pet_autocast()`.

**When to Use What:**
- **Opener:** Send pet -> Aimed -> Kill Command -> Steady weave.
- **Bestial Wrath window:** Use immediately on CD. All shots during BW.
- **Pet danger:** Mend Pet > DPS if pet will die.
- **Target switching:** Pet follows target automatically. Kill Command checks engagement.

**Why This Works:**
BM is pet-dependent. The rotation is simple because the complexity is in pet management. Kill Command provides burst windows. Bestial Wrath is a major DPS cooldown.

---

#### Marksmanship

**Core Concept:** Weapon damage scaling via Aimed Shot and Steady Shot weaving. No pet dependency.

**Priority Order:**
1. **Aimed Shot** - Primary damage. Cast when Auto Shot not winding up.
2. **Serpent Sting** - Maintain DoT. Refresh at <3s remaining.
3. **Arcane Shot** - Instant filler.
4. **Multi-Shot** - AoE only.
5. **Steady Shot** - Default filler during Auto Shot cooldown.

**Shot Weaving Logic:**
- **Auto Shot windup:** 0.5s cast time. Never start Aimed during this window.
- **Steady Shot cast:** 1.5s. Must complete before next Auto Shot.
- **Clip detection:** If Auto Shot ready in <1.5s, use Arcane instead of Steady.

**When to Use What:**
- **Opener:** Serpent Sting -> Aimed -> Steady weave.
- **DoT refresh:** Refresh Serpent only when it falls off (no clipping).
- **Movement:** Arcane Shot only while moving.
- **Execute:** No execute mechanic. Continue normal rotation.

**Why This Works:**
MM is about weapon damage scaling. Aimed Shot hits hard but has cast time. The weaving prevents Auto Shot clipping. Serpent Sting provides sustained damage between Aimed casts.

---

#### Survival

**Core Concept:** Trapper/utility hybrid. Lower personal DPS, higher raid utility via Expose Weakness.

**Priority Order:**
1. **Hunter's Mark** - Maintain on target. +110 AP for all attackers.
2. **Serpent Sting** - Primary DoT.
3. **Aimed Shot** - Big hits.
4. **Mongoose Bite** - Counterattack when dodged (melee range).
5. **Standard shot rotation** (Arcane/Steady weave).

**Expose Weakness (Talent):**
- Procs on crits. +AP for all melee.
- Not rotation-managed; passive benefit.

**Trap Usage:**
- **Explosive Trap:** AoE pulls. Place before pull.
- **Freezing Trap:** CC. Manual placement.
- **Frost Trap:** Kiting. AoE slow.

**When to Use What:**
- **Opener:** Hunter's Mark -> Serpent -> Aimed -> weave.
- **Melee range:** Mongoose Bite when dodged (not primary rotation).
- **Raid utility:** Hunter's Mark > personal DPS. Maintain it.

**Why This Works:**
Survival trades personal DPS for raid buffs. Hunter's Mark and Expose Weakness boost melee DPS significantly. The rotation is simpler because the value is in buffs, not personal output.

---

### MAGE

All three Mage specs use mana tier system: Full -> Conserve -> Emergency.

**Mana Tiers:**
- **Full (>70%):** Normal rotation.
- **Conserve (30-70%):** Skip expensive spells, use wands.
- **Emergency (<30%):** Wand only, Evocation if safe.

**Common Spells:**
- **Counterspell:** Interrupt on cooldown for dangerous casts.
- **Ice Block:** Defensive. Use when HP <30% and healer not available.
- **Evocation:** Mana restore. Channel for 8s. Use during low damage phases.

---

#### Arcane

**Core Concept:** Mana-burn burst phases alternating with conserve phases. Arcane Blast stacking.

**Priority Order:**
1. **Arcane Blast** - Stack to 3, maintain. Primary nuke.
2. **Arcane Missiles** - Clear AB stack when mana low (channeled, efficient).
3. **Fire Blast** - Instant while moving.
4. **Wand** - Conserve phase filler.

**Arcane Blast Stacking:**
- **0 stacks:** 2.5s cast, normal damage.
- **1 stack:** 2.2s cast, +15% damage.
- **2 stacks:** 1.9s cast, +30% damage.
- **3 stacks:** 1.6s cast, +45% damage. Maximum DPS.

**Burn vs Conserve:**
- **Burn Phase:** AB to 3 stacks, maintain. High mana cost.
- **Conserve Phase:** Clear stacks with AM, use wand. Mana recovery.
- **Transition:** Burn until 30% mana, conserve to 70%, repeat.

**When to Use What:**
- **Opener:** AB -> AB -> AB (build to 3 stacks).
- **Maintenance:** Maintain 3-stack AB for max DPS.
- **Mana low:** Arcane Missiles to clear stacks (channeled = mana efficient).
- **Movement:** Fire Blast (instant).

**Cooldowns:**
- **Arcane Power:** Burn phase only. +30% damage, +30% mana cost.
- **Presence of Mind:** Instant AB. Use for movement or emergencies.

**Why This Works:**
Arcane is about managing the AB stack. High DPS at 3 stacks, but unsustainable. Burn/conserve cycling maximizes total damage over fight duration.

---

#### Fire

**Core Concept:** Crit-based ignite rolling. Maintain Scorch debuff for raid.

**Priority Order:**
1. **Scorch** - Maintain Improved Scorch debuff (5 stacks, +15% fire crit).
2. **Fireball** - Primary nuke.
3. **Pyroblast** - Hard cast only if long movement incoming.
4. **Combustion** - Use with trinkets for guaranteed ignite.
5. **Fire Blast** - Instant while moving.

**Ignite Mechanics:**
- Crits cause 40% of damage as DoT over 4s.
- Rolling: New crits refresh and add to ignite pool.
- **Goal:** Chain crits to roll ignite for massive damage.

**Scorch Duty:**
- **0-4 stacks:** Scorch to build.
- **5 stacks:** Refresh at <3s remaining (no clipping).
- **Raid:** One mage assigned to Scorch duty. Others pure Fireball.

**When to Use What:**
- **Opener:** Scorch x5 -> Fireball spam.
- **Ignite rolling:** Combustion -> Fireball spam during trinkets.
- **Movement:** Fire Blast.
- **Execute:** Continue Fireball. Pyroblast if stationary.

**Cooldowns:**
- **Combustion:** +10% crit per cast, stacks to 10. Use for guaranteed ignite rolling.
- **Fire Ward:** Pre-cast before fire damage abilities.

**Why This Works:**
Fire is about ignite rolling. The crit-based DoT is the majority of damage. Scorch duty is mandatory for raid fire mages. Personal DPS vs raid buff tradeoff.

---

#### Frost

**Core Concept:** Control + sustain. Water Elemental for burst. No clearcasting proc chasing.

**Priority Order:**
1. **Winter's Chill** - Maintain debuff (5 stacks, +10% crit for all frost).
2. **Frostbolt** - Primary nuke. Slow + damage.
3. **Ice Lance** - Instant when Fingers of Frost (not TBC - use when moving).
4. **Cone of Cold** - AoE slow.
5. **Arcane Explosion** - AoE damage.

**Water Elemental:**
- **Summon:** On cooldown for single target.
- **Freeze:** AoE root. Use for CC or to set up shatter.
- **Control:** Pet attacks current target automatically.

**Control Abilities:**
- **Frost Nova:** Root melee. Instant cast.
- **Cone of Cold:** Slow AoE.
- **Ice Block:** Immunity. Use for dangerous mechanics.
- **Cold Snap:** Reset all frost CDs. Emergency button.

**When to Use What:**
- **Opener:** Winter's Chill x5 -> Frostbolt spam with Water Ele.
- **Melee on you:** Frost Nova -> blink -> resume casting.
- **AoE:** Cone of Cold -> Arcane Explosion spam.
- **Execute:** Continue Frostbolt. No execute mechanic.

**Cooldowns:**
- **Icy Veins:** +20% haste. Use on cooldown.
- **Cold Snap:** Emergency reset. Save for wipes.
- **Ice Barrier:** Absorb shield. Pre-cast before pull.

**Why This Works:**
Frost is control + sustain. Less burst than Fire, more consistent. Water Ele provides significant DPS. The spec is forgiving due to high survivability.

---

### PALADIN

All three specs use Seal/Judgement system. Seals are self-buffs, Judgements apply effects to target.

**Seal/Judgement Mechanics:**
- **Seal:** Self-buff, lasts 30s. Must be active to Judge.
- **Judgement:** Applies seal effect to target, consumes seal.
- **Re-seal:** Judge -> re-cast Seal -> resume rotation.

---

#### Holy

**Core Concept:** Single-target healing with FoL spam, HL for burst, and proactive cooldowns.

**Priority Order:**
1. **Flash of Light** - Primary heal. Fast, efficient. Spam on target.
2. **Holy Light** - Big heal. Use for tank spikes or low HP targets.
3. **Holy Shock** - Instant. Use while moving or for quick saves.
4. **Cleanse** - Remove diseases/poisons/magic.

**Seal of Wisdom:**
- **Maintain:** Keep Seal active for mana return on melee.
- **Melee:** Stand in melee range to proc mana return.
- **Why:** Paladin mana sustain requires melee contact with Wisdom.

**When to Use What:**
- **Tank healing:** FoL spam. HL after big hits.
- **Raid healing:** FoL on low targets. Spread heals.
- **Movement:** Holy Shock. Judge Wisdom if in range.
- **Mana low:** Switch to Seal of Wisdom, melee for mana.

**Cooldowns:**
- **Divine Illumination:** -50% mana cost. Use during heavy healing.
- **Divine Favor:** Guaranteed crit. Use with HL for big burst.
- **Lay on Hands:** Full heal. 20min CD. Save for emergencies.
- **Avenging Wrath:** +20% healing. Use for burn phases.

**Why This Works:**
Holy Paladin is sustained single-target healing. FoL spam is the base. Cooldowns provide burst windows. The spec requires melee contact for mana (unique mechanic).

---

#### Protection

**Core Concept:** Holy damage tanking. Maintains Holy Shield for block charges and threat.

**Priority Order:**
1. **Holy Shield** - Maintain. 8 charges, 10s duration. Critical for threat.
2. **Avenger's Shield** - Ranged pull + silence. Use on casters.
3. **Judgement** - Maintain Light or Wisdom on target.
4. **Consecration** - AoE threat. Maintain on cooldown.
5. **Exorcism** - Undead/demon only. High threat.
6. **Holy Wrath** - AoE undead/demon stun + threat.

**Holy Shield Mechanics:**
- **8 charges:** Each block consumes 1 charge, deals holy damage.
- **Must maintain:** Drop = significant threat loss.
- **Prepull:** Cast before pull for initial threat.

**Seal Selection:**
- **Righteousness:** Default. Holy damage on hit.
- **Vengeance (SoV):** Stack to 5, maintain. Higher threat.

**When to Use What:**
- **Pull:** Avenger's Shield -> Holy Shield -> Judge -> Consecration.
- **Single target:** Holy Shield > Judge > Consecration > melee.
- **AoE:** Consecration priority. Tab-target Judge.
- **Undead/Demon:** Exorcism on cooldown (high threat).

**Cooldowns:**
- **Divine Protection:** -50% physical damage. 10s duration.
- **Bubble (Divine Shield):** Immunity. Use for emergencies or bad pulls.
- **Lay on Hands:** Self-heal or save healer.

**Why This Works:**
Prot Pally uses holy damage for threat. Holy Shield is the core mechanic - must never drop. The rotation is rigid: maintain buffs, generate holy threat, save cooldowns for spikes.

---

#### Retribution

**Core Concept:** Seal twisting and Crusader Strike spam. Melee holy damage dealer.

**Priority Order:**
1. **Crusader Strike** - Primary damage. Use on cooldown (6s).
2. **Judgement** - Use active seal effect.
3. **Seal of Command/Blood** - Main damage seals.
4. **Exorcism** - Undead/demon only. Instant cast.
5. **Consecration** - AoE or single target mana dump.

**Seal Twisting:**
- **Concept:** Cast two seals in one swing timer.
- **Method:** Cast SoC -> wait for swing -> cast SoB before swing lands.
- **Result:** Both seal procs on one swing.
- **Complexity:** Optional. Provides ~5% DPS increase.

**Seal Selection:**
- **Command:** Procs on swing. Random burst.
- **Blood:** Consistent damage. Slightly higher average.
- **Crusader:** Debuff seal. Use once at start, switch to Command/Blood.

**Vengeance Stacks:**
- **3 stacks:** +15% holy damage.
- **Maintain:** Keep at 3 stacks. Critical for DPS.
- **Duration:** 30s. Refresh with any holy damage.

**When to Use What:**
- **Opener:** Seal of Crusader -> Judge -> Command/Blood -> Crusader Strike.
- **Maintenance:** Crusader Strike on CD, Judge on CD, maintain seal.
- **Twist window:** SoC -> wait 0.5s -> SoB before swing.
- **Execute:** Continue rotation. No execute mechanic.

**Cooldowns:**
- **Avenging Wrath:** +20% damage. Use with trinkets.
- **Divine Protection:** Defensive. Use when taking damage.

**Why This Works:**
Ret is a melee holy DPS. Crusader Strike is the core button. Seal twisting is advanced optimization. Vengeance stacking is mandatory maintenance.

---

### PRIEST

---

#### Discipline

**Core Concept:** Shield-based mitigation healing. Power Word: Shield spam with Penance burst.

**Priority Order:**
1. **Power Word: Shield** - Primary heal. Absorb damage, prevent health loss.
2. **Penance** - Channeled burst heal. Use after big damage.
3. **Renew** - HoT maintenance.
4. **Flash Heal** - Direct heal when shield on cooldown.
5. **Pain Suppression** - Damage reduction cooldown.

**Weakened Soul:**
- **Debuff:** Applied after PW:Shield. 15s duration. Cannot re-shield.
- **Management:** Shield -> Weakened Soul -> Flash Heal -> Shield again when WS falls.
- **Goal:** Maximize shield uptime without clipping WS.

**Rapture:**
- **Mana return:** When shield is fully consumed, gain mana.
- **Optimization:** Shield targets taking consistent damage (tanks).

**When to Use What:**
- **Tank healing:** Shield -> Penance -> Renew -> Flash during WS.
- **Raid shielding:** Spread shields on anyone taking damage.
- **Emergency:** Pain Suppression + Penance on critical target.

**Cooldowns:**
- **Power Infusion:** +20% haste to target. Use on caster DPS.
- **Pain Suppression:** -40% damage. Tank cooldown.

**Why This Works:**
Disc is mitigation healing. Prevent damage rather than heal it. Rapture provides mana sustain. Weakened Soul management is the core skill.

---

#### Holy

**Core Concept:** Reactive healing with Circle of Healing and Prayer of Mending for raid.

**Priority Order:**
1. **Circle of Healing** - Smart heal. Hits 5 lowest HP targets in range. Primary raid heal.
2. **Prayer of Mending** - Bouncing HoT. Cast on tank before pull.
3. **Renew** - HoT maintenance.
4. **Flash Heal** - Single target burst.
5. **Greater Heal** - Big slow heal.
6. **Binding Heal** - Heal self + target. Use when both damaged.

**Holy Words:**
- **Chastise:** Stun/damage. Rarely used in PvE.
- **Sanctify:** Ground AoE. Situational.
- **Serenity:** Single target burst. Use for big heals.

**When to Use What:**
- **Raid healing:** CoH on cooldown. Spread Renew.
- **Tank healing:** Prayer of Mending -> Renew -> Flash Heal.
- **Movement:** Prayer of Mending, Renew (instant).

**Cooldowns:**
- **Guardian Spirit:** +40% healing, cheat death. Tank save.
- **Divine Hymn:** Channel for massive raid healing.

**Why This Works:**
Holy is raid healing. CoH is extremely efficient for groups. Prayer of Mending is proactive. The spec excels at healing multiple targets simultaneously.

---

#### Shadow

**Core Concept:** DoT maintenance with Mind Blast cooldown and execute via Shadow Word: Death.

**Priority Order:**
1. **Vampiric Touch** - Maintain DoT. 15s duration.
2. **Shadow Word: Pain** - Maintain DoT. 18s duration.
3. **Devouring Plague** - Maintain DoT. 24s duration (undead only).
4. **Mind Blast** - Use on cooldown. 5.5s base CD.
5. **Mind Flay** - Channel filler. 3 ticks over 3s.
6. **Shadow Word: Death** - Execute (<20% HP).

**DoT Management:**
- **Never clip:** Wait for DoTs to fall before refreshing.
- **VT timing:** Refresh at 2s or less remaining (haste affects duration).
- **SW:P:** Refresh when fallen off.

**Mind Flay Clipping:**
- **3 ticks:** Full channel.
- **2 ticks:** Clip after 2s if MB off CD.
- **1 tick:** Clip after 1s if movement needed.

**Execute Phase (<20%):**
- **Priority:** SW: Death > MB > MF.
- **Death spam:** Use on cooldown. Double Death if talented.

**Shadowfiend:**
- **Mana return:** Summon when mana <30%.
- **DPS contribution:** Pet deals significant damage.

**When to Use What:**
- **Opener:** VT -> SW:P -> DP -> MB -> MF.
- **Maintenance:** Keep DoTs up, MB on CD, MF filler.
- **Movement:** Instant DoTs only.
- **Execute:** SW: Death on cooldown.

**Why This Works:**
Shadow is DoT management with burst windows (MB). The rotation is rhythmic: maintain 3 DoTs, use MB on CD, fill with MF. Execute phase changes priority to SW: Death.

---

### ROGUE

All three specs use combo point system: Builder -> Builder -> Builder -> Finisher.

**Combo Point Management:**
- **5 points maximum.**
- **Finishers:** Spend at 4-5 points.
- **Energy:** 100 base, regenerates 10 per second.

**Common Abilities:**
- **Kick:** Interrupt. 10s CD.
- **Vanish:** Stealth reset. 5min CD.
- **Evasion:** Dodge buff. Defensive.
- **Sprint:** Speed boost. Utility.

---

#### Assassination

**Core Concept:** Poison damage and Envenom finishers. High sustained single-target DPS.

**Priority Order:**
1. **Mutilate** - Combo builder. 55 energy, hits with both weapons.
2. **Slice and Dice** - Finisher. Maintain attack speed buff. 1-5 CP.
3. **Rupture** - Finisher. DoT. Use at 5 CP.
4. **Envenom** - Finisher. Instant poison damage. Use at 4+ CP if Deadly Poison at 5 stacks.
5. **Eviscerate** - Finisher. Direct damage. Use if Envenom not available.

**Poison Requirements:**
- **Deadly Poison:** Must be on weapon. Stacks to 5.
- **Instant Poison:** Other weapon.
- **Envenom requirement:** Only use at 5 Deadly stacks.

**Hunger for Blood:**
- **Maintain:** +5% damage buff. Requires bleeding target.
- **Refresh:** At <10s remaining.

**Cold Blood:**
- **Guaranteed crit:** Next ability. Use with Envenom.

**When to Use What:**
- **Opener:** Mutilate to 4-5 CP -> SnD -> Mutilate -> Rupture -> Mutilate -> Envenom.
- **Maintenance:** Keep SnD and Hunger for Blood up. Rupture maintained.
- **Envenom window:** 5 Deadly stacks, 4+ CP.

**Why This Works:**
Assassination is poison-focused. Mutilate builds fast. Envenom requires setup (5 Deadly stacks). The rotation rewards maintaining buffs and proper finisher selection.

---

#### Combat

**Core Concept:** Sustained weapon damage with Blade Flurry cleave and Adrenaline Rush burst.

**Priority Order:**
1. **Sinister Strike** - Combo builder. 45 energy.
2. **Slice and Dice** - Finisher. Maintain at all times.
3. **Rupture** - Finisher. DoT. 5 CP.
4. **Eviscerate** - Finisher. Direct damage. 5 CP.
5. **Blade Flurry** - Cleave. +20% attack speed, hits 2 targets.
6. **Adrenaline Rush** - +100% energy regen. 15s duration.

**Bandit's Guile:**
- **Stacks:** Build to 30% damage buff (Shallow -> Moderate -> Deep).
- **Maintain:** Don't let drop. Keep SS spamming.

**Blade Flurry Usage:**
- **2+ targets:** Use on cooldown.
- **Single target:** Use if no energy capping risk.
- **Boss + adds:** Time with add spawns.

**Adrenaline Rush:**
- **Use:** When energy would cap, or during trinkets.
- **Combo:** AR + BF for massive cleave.

**When to Use What:**
- **Opener:** SS to 5 CP -> SnD -> SS to 5 CP -> Rupture.
- **Maintenance:** Keep SnD up. SS spam. BF on CD for cleave.
- **Execute:** Continue rotation. No execute mechanic.

**Why This Works:**
Combat is sustained weapon damage. Simple rotation: SS spam, maintain SnD, BF for cleave. Killing Spree provides burst. Less poison dependency than Assassination.

---

#### Subtlety

**Core Concept:** Stealth openers and control. Focused on PvP but viable for PvE.

**Priority Order:**
1. **Premeditation** + **Ambush** - Stealth opener. High burst.
2. **Hemorrhage** - Combo builder. Applies bleed debuff.
3. **Backstab** - Combo builder from behind. Higher damage than Hemo.
4. **Slice and Dice** - Finisher. Maintain.
5. **Rupture** - Finisher. DoT.
6. **Eviscerate** - Finisher. Burst.

**Shadow Dance:**
- **Stealth abilities while unstealthed:** 6s duration.
- **Use:** Ambush/Backstab spam.

**Premeditation:**
- **Free CP:** 2 combo points on target.
- **Use:** Before opener for instant 2 CP.

**When to Use What:**
- **Opener (PvE):** Premed -> Ambush -> SnD -> Hemo/Backstab -> Rupture.
- **Maintenance:** Hemo from front, Backstab from behind.
- **Dance window:** Shadow Dance -> 4x Ambush -> finisher.

**Why This Works:**
Subtlety is burst-focused. Stealth openers deal massive damage. Hemo provides raid debuff (+bleed damage). Less sustained than Combat/Assassination but higher burst.

---

### SHAMAN

All three specs use totem management. Totems are core to Shaman identity.

**Totem Categories:**
- **Earth:** Stoneskin (armor), Tremor (fear), Strength (AP).
- **Fire:** Searing (damage), Frost Resistance, Flametongue (spell damage).
- **Water:** Healing Stream (regen), Mana Spring (mana), Fire Resistance.
- **Air:** Windfury (haste), Grace of Air (agility), Grounding (spell absorb).

**Totem Twist:**
- **Method:** Drop WF -> wait 0.5s -> drop GoA before WF buff fades.
- **Result:** Both buffs on raid.
- **Complexity:** Advanced. Provides ~3% DPS increase.

---

#### Elemental

**Core Concept:** Spell casting with Clearcasting procs and Flame Shock management.

**Priority Order:**
1. **Flame Shock** - Maintain DoT. 18s duration.
2. **Lightning Bolt** - Primary nuke. 2.5s cast.
3. **Chain Lightning** - AoE or 2-target cleave.
4. **Earth Shock** - Interrupt or instant while moving.
5. **Lava Burst** - (Not TBC - removed).

**Clearcasting:**
- **Proc:** 10% chance on spell hit.
- **Effect:** Next spell free.
- **Usage:** Hold for Chain Lightning (most mana savings).

**Flame Shock Management:**
- **Refresh:** At <2s remaining (no clipping).
- **Priority:** Highest priority spell. Must maintain.

**When to Use What:**
- **Opener:** Flame Shock -> Lightning Bolt spam.
- **Clearcast:** Use on Chain Lightning (3+ targets) or Lightning Bolt.
- **Movement:** Earth Shock (instant).
- **AoE:** Chain Lightning on 2+ targets.

**Cooldowns:**
- **Elemental Mastery:** Guaranteed crit. Use with Chain Lightning.
- **Nature's Swiftness:** Instant spell. Emergency heal or Lightning Bolt.

**Why This Works:**
Elemental is casting with proc management. Flame Shock is mandatory. Clearcasting provides mana sustain. The rotation is simple but requires Flame Shock uptime.

---

#### Enhancement

**Core Concept:** Dual-wield melee with Stormstrike debuff and shock spell weaving.

**Priority Order:**
1. **Stormstrike** - Use on cooldown. Applies nature damage debuff.
2. **Flame Shock** - Maintain DoT.
3. **Earth Shock** - Instant filler. Use while moving.
4. **Lightning Bolt** - Cast when Stormstrike debuff on target.
5. **Chain Lightning** - AoE or 2+ targets with Stormstrike.

**Stormstrike Mechanic:**
- **Debuff:** +20% nature damage taken.
- **Duration:** 12s.
- **Use:** All shocks/LBs/CLs during debuff window.

**Shock Weaving:**
- **Melee swing:** 2.6s (typical).
- **Global CD:** 1.5s.
- **Method:** Stormstrike -> Shock -> melee -> repeat.

**Maelstrom Weapon:**
- **Stacks:** 5 stacks = instant Lightning Bolt/Chain Lightning.
- **Priority:** CL at 5 stacks if 2+ targets, else LB.

**When to Use What:**
- **Opener:** Stormstrike -> Flame Shock -> melee weave.
- **Maintenance:** Stormstrike on CD, shocks during melee downtime.
- **5 Maelstrom:** Instant LB/CL.
- **AoE:** Chain Lightning at 5 Maelstrom.

**Why This Works:**
Enhancement is melee weaving. Stormstrike debuff is critical. Shocks fill GCDs. Maelstrom provides burst windows. The spec rewards tight rotation timing.

---

#### Restoration

**Core Concept:** Chain Heal bouncing with Earth Shield and totem management.

**Priority Order:**
1. **Earth Shield** - Maintain on tank. 10 charges, heals when struck.
2. **Chain Heal** - Primary heal. Bounces to 2 nearby targets.
3. **Healing Wave** - Big slow heal. Single target.
4. **Lesser Healing Wave** - Fast heal. Emergency.
5. **Riptide** - (Not TBC - removed).

**Chain Heal Optimization:**
- **Bounce:** Targets must be within 12 yards.
- **Best use:** Grouped raid members.
- **Less effective:** Spread targets.

**Earth Shield:**
- **Tank only:** Expensive, high value on tank.
- **Refresh:** At <3 charges or before pull.

**Totem Priority:**
1. **Mana Tide Totem** - Party mana. Use on CD.
2. **Healing Stream Totem** - Passive regen.
3. **Wrath of Air Totem** - Caster haste.
4. **Windfury Totem** - Melee haste.

**When to Use What:**
- **Tank:** Earth Shield -> Chain Heal (if melee nearby) -> Healing Wave.
- **Raid:** Chain Heal on grouped members.
- **Emergency:** Lesser Healing Wave.

**Cooldowns:**
- **Nature's Swiftness:** Instant Chain Heal. Emergency.
- **Mana Tide Totem:** Party mana restore.

**Why This Works:**
Resto Shaman is group healing. Chain Heal is uniquely powerful for stacked groups. Earth Shield provides passive tank healing. Totems are mandatory raid buffs.

---

### WARLOCK

All three specs use shard system. Soul Shards are currency for powerful spells.

**Shard Management:**
- **Drain Soul:** Primary shard generation. Channel while target <25% HP.
- **Spenders:** Soul Fire, Shadowburn, Create Healthstone/Soulstone.
- **Cap:** 32 shards maximum in bags.

---

#### Affliction

**Core Concept:** Multi-DoT maintenance with Nightfall procs and Drain Soul execute.

**Priority Order:**
1. **Unstable Affliction** - Maintain. 18s duration.
2. **Corruption** - Maintain. 18s duration.
3. **Siphon Life** - Maintain. 30s duration. Heals you.
4. **Curse of Agony** - Maintain. 24s duration.
5. **Shadow Bolt** - Filler when no DoTs need refreshing.
6. **Drain Soul** - Execute (<25% HP). Also shard generation.

**Nightfall:**
- **Proc:** 4% chance on Corruption tick.
- **Effect:** Instant Shadow Bolt.
- **Usage:** Cast immediately (don't overwrite existing casts).

**Curse Selection:**
- **CoA:** Single target, default.
- **CoE:** If no mage for Scorch (fire/frost boost).
- **CoS:** If no warrior for Sunder (physical boost).

**Execute Phase:**
- **Drain Soul:** Replaces Shadow Bolt. Higher DPS + shards.

**When to Use What:**
- **Opener:** UA -> Corruption -> Siphon -> CoA -> Shadow Bolt.
- **Maintenance:** Refresh DoTs as they fall. Never clip.
- **Nightfall:** Instant SB immediately.
- **Execute:** Drain Soul spam.

**Why This Works:**
Affliction is DoT management. 4 DoTs provide sustained damage. Nightfall provides random burst. Execute phase changes to Drain Soul for damage + shards.

---

#### Demonology

**Core Concept:** Pet-focused with Felguard and Soul Link for survivability.

**Priority Order:**
1. **Corruption** - Maintain.
2. **Immolate** - Maintain.
3. **Shadow Bolt** - Primary nuke.
4. **Soul Fire** - Hard cast burst (requires shard).
5. **Shadowburn** - Execute + shard generation.

**Pet Management:**
- **Felguard:** Primary pet. Melee DPS.
- **Imp:** Caster pet. Phase shift for immunity.
- **Soul Link:** +20% damage to you, pet takes 20% of your damage.

**Demonic Empowerment:**
- **Pet buff:** Use on cooldown.
- **Effect:** Varies by pet type.

**When to Use What:**
- **Opener:** Send pet -> Corruption -> Immolate -> Shadow Bolt spam.
- **Pet danger:** Heal pet or resummon. Pet death = DPS loss.
- **Execute:** Shadowburn on CD.

**Why This Works:**
Demonology is pet + self hybrid. Felguard provides consistent DPS. Soul Link increases survivability. The rotation is simple because pet handles significant damage.

---

#### Destruction

**Core Concept:** Direct damage nukes with Immolate setup and Conflagrate burst.

**Priority Order:**
1. **Immolate** - Maintain. 15s duration. Setup for Conflagrate.
2. **Conflagrate** - Use when Immolate on target. Instant burst.
3. **Incinerate** - Primary nuke. Requires Immolate on target for bonus damage.
4. **Shadow Bolt** - Backup if no Immolate.
5. **Chaos Bolt** - (Not TBC - removed).

**Immolate -> Conflagrate Cycle:**
- **Step 1:** Cast Immolate.
- **Step 2:** Wait for Conflagrate CD or emergency burst need.
- **Step 3:** Conflagrate (consumes Immolate).
- **Step 4:** Re-cast Immolate.
- **Loop:** Immolate -> Incinerate spam -> Conflagrate when needed.

**Backlash:**
- **Proc:** 26% chance when hit.
- **Effect:** Next Shadow Bolt instant.
- **Usage:** Cast SB immediately.

**Shadowburn vs Incinerate:**
- **Incinerate:** Higher DPS when Immolate up.
- **Shadowburn:** Execute + shard generation.

**When to Use What:**
- **Opener:** Immolate -> Incinerate spam.
- **Burst need:** Conflagrate (consumes Immolate, reapply after).
- **Backlash:** Instant Shadow Bolt.
- **Execute:** Shadowburn on CD.

**Why This Works:**
Destruction is burst-focused. Immolate setup enables Conflagrate and buffs Incinerate. The rotation cycles between setup and burst. Shadowburn provides execute + shards.

---

### WARRIOR

All three specs use rage system. Rage generated from dealing/taking damage.

**Rage Management:**
- **0-100 rage.**
- **Builders:** Auto attack (generates rage), Bloodrage (ability).
- **Spenders:** All abilities cost rage.
- **Capping:** Avoid capping (wasted generation).

**Common Abilities:**
- **Battle Shout:** +AP buff. Maintain.
- **Commanding Shout:** +HP buff. Alternative to Battle.
- **Bloodrage:** Rage generation. Use on CD.
- **Berserker Rage:** Fear immunity. Situational.

---

#### Arms

**Core Concept:** Weapon damage with Mortal Strike debuff and Slam weaving.

**Priority Order:**
1. **Mortal Strike** - Use on cooldown. 6s CD. Applies healing debuff.
2. **Slam** - Cast time weapon attack. Primary filler.
3. **Overpower** - Use after target dodges. Cannot be dodged/blocked/parried.
4. **Execute** - <20% HP. High rage cost.
5. **Whirlwind** - AoE only. 4+ targets.
6. **Heroic Strike** - Rage dump. High threat.

**Slam Weaving:**
- **Cast time:** 1.5s (talented).
- **Weapon swing:** Must time to not delay auto attack.
- **Method:** Queue Slam immediately after auto attack lands.
- **Result:** Weapon damage + auto attack continues.

**Overpower:**
- **Trigger:** Target dodges.
- **Effect:** Cannot be avoided. +100% crit chance (talented).
- **Usage:** Immediate when available.

**Execute Phase:**
- **Spam:** Execute on every GCD.
- **Heroic Strike:** Disabled during execute (no rage for both).

**When to Use What:**
- **Opener:** Charge -> MS -> Slam weave.
- **Maintenance:** MS on CD, Slam between swings, OP when dodged.
- **Execute:** Execute spam, ignore MS/Slam.

**Cooldowns:**
- **Bladestorm:** (Not TBC - removed).
- **Retaliation:** Counterattack. Defensive.

**Why This Works:**
Arms is weapon damage. MS provides utility (healing debuff). Slam weaving maximizes weapon damage. Overpower punishes dodges. Execute is rage-intensive burst.

---

#### Fury

**Core Concept:** Dual-wield melee with Bloodthirst spam and Rampage maintenance.

**Priority Order:**
1. **Bloodthirst** - Use on cooldown. 4s CD. Scales with AP.
2. **Whirlwind** - AoE or rage dump. Single target if rage >50.
3. **Heroic Strike** - Rage dump. High threat.
4. **Execute** - <20% HP.
5. **Cleave** - 2-target alternative to HS.

**Rampage:**
- **Maintain:** 5 stacks = +250 AP.
- **Refresh:** Crits add stack, refresh duration.
- **Goal:** Keep at 5 stacks always.

**Flurry:**
- **Proc:** Crits trigger +30% attack speed.
- **Stacks:** 3 charges.
- **Maintenance:** Keep active via crits.

**Bloodthirst Priority:**
- **Never delay:** BT is highest DPS ability.
- **Rage check:** Use even at low rage (high DPR).

**Execute Phase:**
- **Problem:** Execute costs all rage. BT provides better DPR.
- **Solution:** BT > Execute if rage <30. Execute if rage >30.
- **Result:** Mixed BT/Execute rotation.

**When to Use What:**
- **Opener:** Bloodrage -> BT -> WW -> HS if rage >60.
- **Maintenance:** BT on CD, WW as filler, HS to prevent rage cap.
- **Execute:** BT first, then Execute.

**Why This Works:**
Fury is sustained melee. BT is the core button. Rampage and Flurry require crit maintenance. Execute phase is different - BT remains priority due to rage efficiency.

---

#### Protection

**Core Concept:** Shield-based tanking with Revenge procs and Shield Slam threat.

**Priority Order:**
1. **Shield Slam** - Use on cooldown. 6s CD. High threat.
2. **Revenge** - Use when available (after block/dodge/parry). Low cost, high threat.
3. **Devastate** - Sunder replacement. Applies Sunder + damage.
4. **Thunder Clap** - AoE threat + attack speed debuff. Maintain on 2+ targets.
5. **Heroic Strike** - Rage dump. High threat.
6. **Cleave** - AoE rage dump. 2+ targets.

**Shield Block:**
- **Active mitigation:** +75% block, guaranteed block.
- **Charges:** 2 charges, 10s duration.
- **Use:** Maintain for physical damage mitigation and Revenge procs.

**Revenge Procs:**
- **Trigger:** Block, dodge, or parry.
- **Availability:** 5s window after trigger.
- **Priority:** Highest threat per rage. Use immediately.

**Sunder Armor:**
- **Stack:** 5 stacks = -20% armor.
- **Devastate:** Applies Sunder + damage. Replaces Sunder.
- **Maintenance:** Keep at 5 stacks via Devastate.

**When to Use What:**
- **Pull:** Shield Block -> Shield Slam -> Revenge (if proced) -> Devastate.
- **Single target:** SS on CD, Revenge when up, Devastate filler.
- **AoE:** Thunder Clap, Cleave spam, tab-target SS.

**Cooldowns:**
- **Last Stand:** +30% HP. Emergency.
- **Shield Wall:** -75% damage. Major cooldown.
- **Bloodrage:** Rage generation.

**Why This Works:**
Prot Warrior is active mitigation. Shield Block enables Revenge and reduces damage. SS and Revenge provide high threat. Devastate maintains Sunder. The rotation is reactive based on procs.

---

## Shared Systems

### Interrupt Management
All specs use priority interrupt system:
- **Healer casts:** Highest priority (prevent heals).
- **Dangerous casts:** Second priority (prevent damage).
- **Generic casts:** Lowest priority.

### Defensive Thresholds
HP-based automatic defensive usage:
- **<80% HP:** Minor defensives (self-heals, absorbs).
- **<50% HP:** Major defensives (shields, immunities).
- **<30% HP:** Panic buttons (Lay on Hands, last stand).

### Leveling 1-70
- **Spell downranking:** Use lower rank spells for mana efficiency.
- **Pull optimization:** Skip cast-time spells on trivial targets (>10 levels below).
- **Mana conservation:** Three-tier system (full/conserve/emergency).

### PvP Mode
- **Enemy player targeting:** Detects and prioritizes enemy players.
- **Arena focus fire:** Targets lowest HP enemy in 2v2/3v2.
- **Battleground awareness:** Flag carrier priority, node defense.
- **Trinket usage:** Auto-trinket crowd control.

---

## Build and Ship

### Packaging
```bash
python tools/export_eax_plugins.py --output dist/eax_ship
```

### Validation
```bash
lua tools/rotation_validation.lua        # Spec validation
lua tools/api_hard_gate.lua                # API compliance
luac -p EAXWarriorFury/main.lua          # Syntax check
```

### What Ships
- `.lua` files
- `.md` files
- `libraries/` modules

### What Does Not Ship
- `.toc` files
- `.zip` artifacts (except plugins-listing)
- Screenshots / binaries / temp files

---

## Maintenance

1. Inspect git state first
2. Limit commits to requested scope
3. Keep EAX packages clean (`.lua` + `.md` only)
4. Verify deleted `.toc` files stay deleted
5. Push only after status/diff review

For detailed workflow guidance, see `AGENTS.md`.
