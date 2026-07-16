# Classic Vanilla (1.15) Combat Spec Gap Matrix

**Date:** 2026-07-16  
**Scope:** All **31** Classic Era combat specializations (`*_vanilla.lua`) — **not** TBC `*_sylvanas`, **not** WotLK  
**Baseline version:** 2.7.8 → release **2.7.9**  
**Primary sources:** local `data/wowsims_classic` APLs, Wowhead Classic / Icy Veins Classic / Warcraft Tavern, scorecard Vanilla rows  
**Tie-breakers:** wowsims classic / SimC APL for PvE DPS when present; written guides for healers; **no TBC backports as Vanilla core path**

### Verdict legend
| Verdict | Meaning |
|---------|---------|
| **aligned** | Core priority + playstyles match Classic sources |
| **gap** | Material mismatch — **fixed this pass** if listed under Fixes |
| **source-disagreement** | Guides/APL conflict; tie-breaker documented |

### Vanilla-vs-TBC rules (matrix-wide)
| Mechanic | Vanilla (1.15) | Must not be core path |
|----------|----------------|------------------------|
| Hunter filler | **Aimed Shot** + Multi + Serpent | Steady Shot / Kill Command |
| Shadow Priest | SW:P / MB / MF | Vampiric Touch |
| Warrior tank | Sunder / Revenge / Shield Slam | Devastate / Rampage |
| Druid cat/bear | Shred / Maul / Swipe | Mangle / Lacerate as required |
| Warlock | Demon Armor, Shadow Bolt | Fel Armor / Felguard / UA |
| Shaman | WF / SoE / GoA totems | Water Shield / Earth Shield / Bloodlust as core |

---

## Matrix (31 combat specs)

| # | Spec | File | Sources | Priority / logic | Settings / playstyles | Verdict |
|---|------|------|---------|------------------|----------------------|---------|
| 1 | Warrior Arms | `warrior/arms_vanilla.lua` | wowsims `warrior/apls/dps_*.apl.json`, IV | MS > OP > WW > Execute; HS dump | Stance dance, rage dumps | **aligned** |
| 2 | Warrior Fury | `warrior/fury_vanilla.lua` | wowsims warrior DPS APL | Execute > BT > WW > HS | CDs, DW/2H | **aligned** |
| 3 | Warrior Protection | `warrior/protection_vanilla.lua` | wowsims tank_warrior APL | Revenge / SS / Sunder / Shield Block | Taunts, defensives | **aligned** |
| 4 | Warrior Kebab | `warrior/kebab_vanilla.lua` | community hybrid | MS/WW/Execute hybrid | Hybrid toggles | **aligned** |
| 5 | Hunter BM | `hunter/beast_mastery_vanilla.lua` | wowsims `hunter/apls/p1.apl.json` | **Aimed** > Multi > Serpent; BW/pet | Aspects, sting mode, FD | **gap → fixed**: Aimed Shot was missing |
| 6 | Hunter MM | `hunter/marksmanship_vanilla.lua` | same p1 APL | Aimed in combat + prepull; Multi; Serpent | Trueshot N/A spam, RF | **aligned** |
| 7 | Hunter Survival | `hunter/survival_vanilla.lua` | same p1 + traps | **Aimed** + Multi + traps/Raptor | Scorpid, traps | **gap → fixed**: Aimed Shot was missing |
| 8 | Mage Arcane | `mage/arcane_vanilla.lua` | IV / classic (no AB) | AP-boosted Frostbolt / AM | AP/PoM/Evo | **aligned** (AP Frost hybrid) |
| 9 | Mage Fire | `mage/fire_vanilla.lua` | wowsims `mage/apls/p1.apl.json` | Scorch 5 > Fireball > Combustion | Scorch duty, AoE | **aligned** |
| 10 | Mage Frost | `mage/frost_vanilla.lua` | IV / classic | Frostbolt + WC + Nova/CoC | Shatter windows | **aligned** |
| 11 | Paladin Holy | `paladin/holy_vanilla.lua` | IV / Tavern | FoL/HL triage, DF, blessings | Thresholds, solo seals | **aligned** |
| 12 | Paladin Protection | `paladin/protection_vanilla.lua` | wowsims prot pally APL | Holy Shield > Consec > Judge > SoR | No taunt (Vanilla) | **aligned** |
| 13 | Paladin Retribution | `paladin/retribution_vanilla.lua` | wowsims ret basic APL | SoC/Crusader judge, Consecrate | Seal twist settings | **aligned** |
| 14 | Priest Discipline | `priest/discipline_vanilla.lua` | wowsims healing_priest disc | PWS emergency, GH/FH, PI | PI target, shields | **aligned** |
| 15 | Priest Holy | `priest/holy_vanilla.lua` | wowsims holy + guides | Renew, FH/GH, PoH | Downrank, idle DPS | **aligned** |
| 16 | Priest Shadow | `priest/shadow_vanilla.lua` | wowsims `shadow_priest/apls/p1.apl.json` | SW:P > MB > MF; no VT | Multi SWP, WE | **aligned** |
| 17 | Priest Smite | `priest/smite_vanilla.lua` | community niche | Smite/Holy Fire/MB | Soft-gated TBC stubs | **aligned** |
| 18 | Rogue Assassination | `rogue/assassination_vanilla.lua` | IV Classic Sin | SnD > Rupture > Evis; Backstab/Ambush | EA, openers | **aligned** |
| 19 | Rogue Combat | `rogue/combat_vanilla.lua` | wowsims combat_sinister_strike | SnD > Rupture > Evis > SS | AR/BF, energy | **aligned** |
| 20 | Rogue Subtlety | `rogue/subtlety_vanilla.lua` | IV Sub (PvP-leaning) | Hemo/SnD/Rupture/openers | Prep/Vanish | **aligned** |
| 21 | Shaman Elemental | `shaman/elemental_vanilla.lua` | wowsims elemental APL | LB/CL + shocks; totems | Totem set; WoA stub no-op | **aligned** |
| 22 | Shaman Enhancement | `shaman/enhancement_vanilla.lua` | wowsims enh APL + Era | WF weapon + totems + shocks | Stormstrike soft-gated if unlearned | **source-disagreement**: classic APL lists SS (SoD/era mix); Era soft-gates via spell_ready |
| 23 | Shaman Restoration | `shaman/restoration_vanilla.lua` | IV / Tavern | CH / HW / LHW; no ES | Totems, NS | **aligned** |
| 24 | Druid Balance | `druid/balance_vanilla.lua` | wowsims balance APL | MF/IS + Starfire/Wrath | Innervate, Hurricane | **aligned** |
| 25 | Druid Bear | `druid/bear_vanilla.lua` | wowsims feral tank | Maul/Swipe/Demo; no Mangle required | FR/Barkskin | **aligned** |
| 26 | Druid Cat | `druid/cat_vanilla.lua` | wowsims feral APL | Shred/Rip/FB; no Mangle required | Powershift, TF | **aligned** |
| 27 | Druid Caster | `druid/caster_vanilla.lua` | hybrid guides | Wrath/SF/MF + HT | Hybrid | **aligned** |
| 28 | Druid Resto | `druid/resto_vanilla.lua` | IV / Tavern | Rejuv/Regrowth/HT/Swiftmend; no LB 3-stack TBC core | Innervate target | **aligned** |
| 29 | Warlock Affliction | `warlock/affliction_vanilla.lua` | wowsims warlock rotation | Corr/SL/Curse/SB; Demon Armor | Curse mode, pet | **aligned** |
| 30 | Warlock Demonology | `warlock/demonology_vanilla.lua` | same + DS/Ruin | DS, DoTs, SB filler; no Felguard | Pet/DS | **aligned** |
| 31 | Warlock Destruction | `warlock/destruction_vanilla.lua` | wowsims warlock rotation | Immolate/Conflag/SB; Shadowburn execute | **gap → fixed**: SoulFire always-matched with shard (spammed); gated to execute; Shadowburn above filler |

---

## Material fixes this pass

| Spec | Issue | Fix | Test |
|------|-------|-----|------|
| Hunter BM | No Aimed Shot | Aimed strategy + state; Arcane yields when Aimed ready | `test_hunter_vanilla_aimed_shot.lua` |
| Hunter Survival | No Aimed Shot | Same | same |
| Destruction | SoulFire always true with shard | Execute-phase gate; Shadowburn before SoulFire | `test_destruction_vanilla_soul_fire_execute.lua` |

## Source index (local)

| Source | Path |
|--------|------|
| wowsims classic APLs | `data/wowsims_classic/ui/**/apls/*.apl.json` |
| Research (classic section) | `plans/research_rotation_sources_report.md` |
| Scorecard Vanilla rows | `docs/SCORECARD.md` |
