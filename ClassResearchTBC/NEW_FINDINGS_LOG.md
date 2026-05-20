# New Findings Log
| Spec | Angle | Finding | Source needed |
|---|---|---|---|
| Druid Balance | A1 | Failure-case gating now resolves target validity, movement, pushback, threat, mana floor, and TTD before casting Moonfire [26988] / Insect Swarm [27013] / Starfire [26986] / Wrath [26984]. | Flux + Sonah + EaxRotations |
| Druid Balance | A2 | Boss modifiers split cleanly into movement, add-wave, pushback, threat-reset, and mana-drain branches, which maps directly to Barkskin [22812], Hurricane [27012], Force of Nature [33831], and Innervate [29166]. | Flux + EaxRotations |
| Druid Balance | A3 | Cross-spec support should skip caster Faerie Fire [26993] when Feral Faerie Fire [27011] is already live and should reserve Innervate [29166] / Rebirth [20484/20739/20741/20742/20747/26994] by assignment. | Sonah + EaxRotations |
| Druid Balance | A4 | The 800/1000/1200 SP bands are usable as mana-efficiency tiers for Starfire [26986], Moonfire [26988], Insect Swarm [27013], and Wrath [26984] tuning. | wowsims/tbc + logs |
| Druid Balance | A5 | Local implementation diverges: Flux is tiered and Wrath-fallback heavy, Sonah is clearcasting-first, EaxRotations adds explicit state flags and mana floors, and `SlyRotate_Druid.lua` is missing. | Flux + Sonah + EaxRotations + SlyRotate |
| Druid Feral DPS | A1 | Feral DPS needs a separate shift-state machine: energy floor, mana floor, GCD lock, and a spam throttle. | S+ research |
| Druid Feral DPS | A4 | AP breakpoints around 1500/2000/2500 justify different energy floors for spend vs pool behavior. | wowsims/tbc |
| Druid Bear Tank | A1 | Consecration must check cc_nearby before cast to prevent broken crowd control. | Icy Veins |
| Druid Bear Tank | A2 | Encounter modifiers split into raid / dungeon control buckets (movement, add waves, interrupts, tank spikes, resistance, threat resets), which maps directly to Bear threat and cooldown gating. | Encounters + Flux |
| Druid Bear Tank | A3 | Faerie Fire priority should prefer Feral Faerie Fire [16857/17390/17391/17392/27011] and reserve Innervate [29166] for assigned healer recovery before self-utility. | Flux + Sonah |
| Druid Bear Tank | A4 | Bear threat efficiency is highest on Mangle (Bear) [33987], with Maul [26996] as a rage dump, Lacerate [33745] as sustained value, Swipe [26997] as target-count gated, and Demoralizing Roar [26998] as mitigation-first. | Flux + SlyRotate |
| Druid Restoration | A1 | Lifebloom [33763] bloom timing must track target HP to avoid wasting bloom on full-HP targets. | Wowhead |
| Druid Restoration | A4 | Downrank table shows clear HpM efficiency at Chain Heal [25423] rank 4 vs 5 for conserve phases. | DB2 |
| Hunter Beast Mastery | A1 | Bestial Wrath [19574] and Rapid Fire [3045] should be staggered by ~5s for sustained haste overlap. | Wowhead |
| Hunter Marksmanship | A1 | Auto Shot must not be clipped by Steady Shot; gate on swing timer. | Wowhead |
| Hunter Survival | A1 | Expose Weakness [34500] must maintain >80% uptime; use Readiness [23989] if uptime drops. | Wowhead |
| Mage Arcane | A1 | 3-stack Arcane Blast [30451] must fallback to Arcane Missiles [38699] during movement to prevent stack drops. | Wowhead |
| Mage Fire | A1 | Ignite [12654] munching can be mitigated by tracking ignite tick timer and delaying large crits until after the tick. | Wowhead |
| Mage Frost | A1 | Frostbolt [38697] should queue immediately upon Frostbite [12494] proc to maximize Shatter combo crit rate. | Icy Veins |
| Paladin Holy | A1 | Blessing assignment should role-gate BoL [27144] vs BoW [27142] based on target role, not blanket apply. | S+ research |
| Paladin Protection | A1 | Consecration must check cc_nearby before cast to prevent broken crowd control. | Icy Veins |
| Paladin Retribution | A1 | Seal of Blood [31892/31893] must faction-gate vs Seal of the Martyr [348700/348701] (Alliance in local `wow_anniversary` DB2). | Wago DB2 + Wowhead |
| Priest Discipline | A1 | Power Word: Shield [25218] must check Weakened Soul [6788] before casting to avoid GCD waste. | Wowhead |
| Priest Holy | A1 | Guardian Spirit [47788] is WotLK-only; do not reference in TBC rotation. Circle of Healing [34861] and Lightwell [724] are valid TBC spells. | Wago DB2 |
| Priest Shadow | A1 | Vampiric Touch [34914] must maintain 100% uptime; never let drop for other spells. | Wowhead |
| Priest Smite | A1 | Must maintain Inner Fire [25431] uptime; re-cast when <5s remains. | Wowhead |
| Rogue Assassination | A1 | Must maintain Slice and Dice [6774] at 100% uptime; re-cast when <3s remains. | Wowhead |
| Rogue Combat | A1 | Must maintain Slice and Dice [6774] at 100% uptime; re-cast when <3s remains. | Wowhead |
| Rogue Subtlety | A1 | Must maintain Hemorrhage [26864] debuff on boss; re-apply when <3s remains. | Wowhead |
| Shaman Elemental | A1 | Flame Shock [25457] should refresh only when <1s remains to avoid GCD waste. | Wowhead |
| Shaman Enhancement | A1 | Totem twist should gate on main-hand swing timer >0.2s to avoid losing Windfury procs. | Warcraft Tavern |
| Shaman Restoration | A1 | Chain Heal should filter pets from bounce targets to avoid wasted healing. | Wowhead |
| Warlock Affliction | A1 | DoTs should refresh only when <1.5s remains to avoid clipping and mana waste. | Wowhead |
| Warlock Demonology | A1 | Must ensure Felguard [30146] uptime; resummon immediately on death. | Wowhead |
| Warlock Destruction | A1 | Conflagrate [17962] must verify Immolate [27215] is active before casting. | Wowhead |
| Warrior Arms | A1 | Slam [25242] must cast after auto-attack lands, not before, to prevent clipping. | Wowhead |
| Warrior Fury | A1 | Should prioritize Bloodthirst [30335] over Whirlwind [25234] and maintain max-rank Rampage [30033] 5-stack. | Wago DB2 + Wowhead |
| Warrior Protection | A1 | Shield Block [2565] must maintain 100% uptime; re-cast when <2s remains. | Icy Veins |
