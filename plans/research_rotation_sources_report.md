# EaxRotations — Authoritative TBC/Vanilla Rotation Source Report

Generated: 2026-07-05
Scope: 29 TBC Classic Anniversary specs (2.5.5.x) + Vanilla/SoD references for expansion gating.

## Summary

Highest-fidelity PvE sources are the **wowsims/tbc-new** APL JSON files (`ui/<class>/<spec>/apls/*.apl.json`). They are community-maintained, simulator-executable, and versioned. For Vanilla/SoD contrast use **wowsims/classic**. Written guides (Icy Veins, Warcraft Tavern) agree on broad priorities but differ on subtleties such as melee-weaving value, bite-vs-Rip preference, and execute rage breakpoints. PvP sources are fragmented; the best consolidated quick-reference is **pvpskills.com**.

## Repository map — wowsims/tbc-new

Base raw URL prefix: `https://raw.githubusercontent.com/wowsims/tbc-new/master/`

| Class/Spec | APL file | Key notes |
|-----------|----------|-----------|
| Warrior Arms | `ui/warrior/dps/apls/arms.apl.json` | 2H vs DW via Slam cast-time check; Overpower weaving |
| Warrior Fury | `ui/warrior/dps/apls/fury.apl.json` | BT > WW > Execute; HS dump |
| Warrior Prot | `ui/warrior/protection/apls/default.apl.json` | Shield Block, Shield Slam/Revenge/Devastate priority, defensive swaps |
| Paladin Retribution | `ui/paladin/retribution/apls/default.apl.json` | Crusader→Blood/Martyr seal twist; CS/judge weaving |
| Paladin Protection | `ui/paladin/protection/apls/default.apl.json` | Holy Shield priority, JoW maintenance, Consecrate filler |
| Hunter | `ui/hunter/dps/apls/default.apl.json` | Kill Command, steady/auto weave, melee-weave variables |
| Rogue | `ui/rogue/dps/apls/swords.apl.json` | SnD/EA/Rupture uptime, Shiv poison refresh |
| Priest Shadow | `ui/priest/dps/apls/default.apl.json` | VT > SW:P > MB > clipped Mind Flay |
| Mage Arcane | `ui/mage/dps/apls/arcane.apl.json` | AB stacking, burn/conserve sequence, gem/evocation thresholds |
| Mage Fire/Frost | **not in tbc-new APLs** | Only blank/test APLs; use external sources |
| Warlock Affliction | `ui/warlock/dps/apls/affliction.apl.json` | Assigned curse > UA > Corruption/SL/CoA > Shadow Bolt |
| Warlock Demonology | `ui/warlock/dps/apls/demonology.apl.json` | Same as Affliction minus UA |
| Warlock Destruction | `ui/warlock/dps/apls/destruction.apl.json` | Immolate refresh > Shadow Bolt |
| Warlock Destro Fire | `ui/warlock/dps/apls/destro_fire.apl.json` | Immolate > Incinerate |
| Shaman Elemental | `ui/shaman/elemental/apls/default.apl.json` | Totem refresh ≤5s, LB/CL weave |
| Shaman Enhancement | `ui/shaman/enhancement/apls/default.apl.json` | Stormstrike, WF twist, shock/fire totem fillers |
| Druid Balance | `ui/druid/balance/apls/default.apl.json` | Moonfire/Insect Swarm multidot, Starfire filler, Innervate self |
| Druid Feral Cat | `ui/druid/feralcat/apls/default.apl.json` | Rip/FB, Mangle, Shred, powershift via energy logic |
| Druid Feral Bear | `ui/druid/feralbear/apls/default.apl.json` | Mangle/Lacerate/Demo Roar, Maul dump, survival CDs |
| Healer specs (Paladin Holy, Priest Holy/Disc, Shaman Resto, Druid Resto) | **no APL directories** | Healing not APL-modeled in tbc-new |

## Repository map — wowsims/classic (Vanilla/SoD)

Base raw URL prefix: `https://raw.githubusercontent.com/wowsims/classic/master/`

- Warrior: `ui/warrior/apls/dps_no_reck.apl.json`, `dps_reck.apl.json`
- Rogue: `ui/rogue/apls/combat_sinister_strike.apl.json`, `combat_backstab.apl.json`
- Mage: `ui/mage/apls/p1.apl.json` (scorch/fire)
- Warlock: `ui/warlock/apls/rotation.apl.json`
- Hunter: `ui/hunter/apls/p1.apl.json` (Aimed/Multi)
- Shadow Priest: `ui/shadow_priest/apls/p1.apl.json`

## Key APL rules per class

### Warrior
- **Arms**: Pre-pull Berserker Rage/Bloodrage/Battle Shout; Sunder group stacked to 5 or refreshed at ≤10s; Slam if ≥0.5s remains on swing; Execute sub-20%.
- **Fury**: Bloodthirst on CD, Whirlwind when BT >1.5s away, Execute sub-20%, HS dump.
- **Prot**: Shield Block when inactive; Shield Slam > Revenge > Devastate; Sunder refresh ≤6s; defensive CD chain ≤40% HP.

### Paladin
- **Ret**: Pre-pull Seal of the Crusader, judge at 0s, swap to Blood/Martyr; Crusader Strike on CD; Consecrate/Exorcism toggled off by default.
- **Prot**: Holy Shield prioritized; Judgement of Wisdom; Seal of Righteousness; Consecrate filler.

### Hunter
- Kill Command off-GCD; Steady Shot filler; Multi-Shot replaces one Steady; Arcane Shot optional; Viper below ~5% mana, Hawk above ~25%; melee weave variables exist but are contested.

### Rogue
- SnD uptime first; Expose Armor if talented; Rupture at 5cp if target lives >10s; Eviscerate otherwise; Shiv refreshes deadly poison.

### Priest (Shadow)
- VT pre-cast; Shadowfiend on short fights or OOM; Mind Blast on CD; Mind Flay clipped after 2 ticks if a higher-priority spell is ready.

### Mage
- **Arcane**: Pre-stack Arcane Blast; burn to ~20% mana, then 3AB→Arcane Missiles; gem/rune thresholds; AP/IV aligned with Bloodlust/Drums.
- **Fire/Frost**: No tbc-new APLs; use Icy Veins/SimC.

### Warlock
- Maintain assigned curse (Elements/Recklessness/Doom); Affliction keeps UA/Corruption/SL/CoA; Destro keeps Immolate; Shadow Bolt or Incinerate filler; Life Tap ≤15% mana; Shadowburn/Death Coil at ≤5% fight.

### Shaman
- **Elemental**: Totems ≤5s; Chain Lightning when cast time ≥1s and mana ≥30%, else Lightning Bolt.
- **Enhancement**: Stormstrike on CD; WF/Grace of Air totem twist; Shamanistic Rage at low mana; flame/earth/frost shock fillers; fire totem twisting.

### Druid
- **Balance**: Insect Swarm/Moonfire multidot; Starfire filler; Hurricane ≥4 targets; Innervate self at ≤30% mana.
- **Feral Cat**: Rip at ≥4cp if target lives >10s, else FB; maintain Mangle; Shred builder; powershift at low energy.
- **Feral Bear**: Mangle, Lacerate stack/refresh ≤3s, Demo Roar, Maul ≥50 rage; survival CDs at ≤40% HP.

## Conflicts between sources

1. **Hunter melee weaving**: wowsims/tbc-new APL implements it; Icy Veins says it is marginal and hard to execute.
2. **Feral finisher**: Icy Veins = Rip if target lives full duration; Warcraft Tavern = bite-weave can be BiS with good gear/buffs, full-Rip on high armor/poor gear.
3. **Warrior execute**: Icy Veins says BT between Executes if you reach 30 rage during Execute GCD; wowsims Fury inserts Execute above BT sub-20%.
4. **Mage fire/frost**: tbc-new has no authoritative APLs.
5. **Mind Flay**: wowsims clips after 2 ticks; some guides channel to completion unless DoTs about to drop.

## Expansion-gating mechanics (TBC vs Vanilla)

| Mechanic | TBC (2.5.5) | Vanilla/SoD |
|----------|-------------|-------------|
| Hunter filler | Steady Shot, Kill Command | Aimed/Multi only |
| Warrior | Rampage, Devastate, Commanding Shout | absent |
| Paladin seal | Blood/Martyr backported | Command/Crusader |
| Druid cat | Mangle, powershift Wolfshead | no Mangle |
| Warlock | Fel Armor, UA, Shadow Embrace | Soul Link/Sacrifice meta |

## Recent Fixes from Audit (2026-07-10)
- Arms Warrior: Moved SunderArmor higher in priority list and enabled in Battle stance (was Defensive only) to match SimC APL (sunder early for armor debuff) and Wowhead/Icy Veins guides. Verified with luac + full tests.
- Sources used: wowsims/tbc-new arms.apl.json, Icy Veins TBC Arms rotation, Wowhead TBC Warrior DPS.
- Feral Cat: Added Berserk usage in burst windows (pull, BL, high AP) to align with SimC/wowsims/icyveins (Berserk for max shred/rip during CDs). Previously only mentioned in header, no logic. Tigers Fury already had good gating (pull or 100 energy). Verified tests green.
- Sources: wowsims tbc feral, Wowhead TBC Feral rotation, Icy Veins TBC Feral.
- Retribution Paladin: Enabled seal twisting by default (Command rank 1 into Blood/Martyr for CS and Judge windows). Matches wowsims APL priority (twist before swing, CS under Blood, Judge under Blood shortly after auto) and Wowhead/Icy Veins TBC guides. The implementation already included CLEU swing diagnostics, PERFECT/PHANTOM logging, dynamic twist window, post-swing judge gate, rank-1 Command prep. Only the default was off; now auto users get source-aligned behavior. All tests green.
- Sources: wowsims/tbc-new paladin/retribution apl, Wowhead TBC Ret DPS guide, community seal twisting guides.
- Hunter (all specs): Enhanced with dynamic auto-shot buffer (min(500ms, 25% of current swing)) in hunter_core + shot_timer, matching wowsims APL "Buffer" variable. Updated can_cast_before_auto / can_cast_* across BM/MM/Survival to use dynamic buffer by default for better non-clip decisions and filler insertion (Multi/Arcane/Steady). Centralized helpers exposed. Prior Viper/Hawk + Aimed opener + KC priority already aligned. Tests green. Full shot-weave buffer calculations now closer to APL.
| Mage | Arcane Blast, IV, AP | Frostbolt/FB spam |
| Rogue | Envenom, Deadly Poison primary | Eviscerate primary |
| Shaman | Stormstrike charges, WF twist | single-charge SS |
| Priest | Vampiric Touch | no VT |

## Notable APL actions/conditions to expose in EaxRotations

1. Swing timers (`autoTimeToNext`, `autoTimeSinceLast`) for hunter and melee weaving.
2. Energy-tick tracking for druid powershift cycles.
3. Execute phase marker (sub-20% HP) for warrior/rogue/warlock.
4. Aura remaining time on self and target for debuff refresh rules.
5. Mana-percent thresholds for Viper, Arcane conserve, Shamanistic Rage.
6. Bloodlust/Drums encounter timing for cooldown alignment.
7. Assigned curse/debuff flag to prevent overwrites.
8. Defensive HP thresholds (30–40%) for tanks.
9. Target count for AoE abilities.
10. Healer specs have no APL source; keep threshold/priority logic.

## PvP sources

- **pvpskills.com/classes/warrior**: MS debuff 100% uptime; Hamstring 100%; Berserker Rage pre-Fear; Intercept stun on healers; Spell Reflect Polymorph/Fear/Frostbolt; Rend vs rogues; Disarm on enemy cooldowns.
- CC chains: Warrior/Druid Cyclone→Intercept→Cyclone; Warrior/Paladin Intimidating Shout→HoJ→Intercept.
- Notable class-discord pins and arena VODs are the next-best sources outside warrior.

## Recommendations

1. Use **wowsims/tbc-new APL JSONs** as the primary reference for all DPS/tank specs.
2. Source **Mage Fire/Frost** and all **healer specs** from Icy Veins/Warcraft Tavern/class Discord because tbc-new lacks APLs.
3. Gate Vanilla/SoD mechanics behind expansion checks.
4. Add swing-timer, mana-percent, aura-remaining-time, and assigned-debuff state fields to the EaxRotations engine so the wowsims APL conditions can be represented.
