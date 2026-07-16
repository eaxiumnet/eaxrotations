# TBC Combat Spec Gap Matrix — Guide / APL Re-verification

**Date:** 2026-07-16  
**Scope:** All **29** TBC Classic Anniversary combat specializations (`*_sylvanas.lua`)  
**Baseline version:** 2.7.7 → release **2.7.8** after this pass  
**Primary sources:** local `data/tbc-new` wowsims APLs, `plans/research_rotation_sources_report.md`, prior `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` (COMPLETE), Wowhead / Icy Veins / Warcraft Tavern consensus for healers + Fire/Frost Mage  
**Tie-breakers:** DBC for spell validity; **wowsims APL for PvE DPS priority** when present; written guides when no APL (healers, Fire/Frost)

### Verdict legend
| Verdict | Meaning |
|---------|---------|
| **aligned** | Core priority + playstyle toggles match sources; no material combat-behavior gap |
| **gap** | Material mismatch (wrong/missing core priority, broken toggle, dead strategy) — **fixed in this pass** if listed under Fixes |
| **source-disagreement** | Guides conflict; project tie-breaker applied and documented |

### Settings / playstyles column
Summarizes presence of guide-standard toggles (AoE mode, assigned curse, aspect mana, seal twist, multidot, healer thresholds, etc.) via class `schema_sylvanas.lua` + middleware.

---

## Matrix (29 combat specs)

| # | Spec | File | Sources | Priority / logic | Settings / playstyles | Verdict |
|---|------|------|---------|------------------|----------------------|---------|
| 1 | Warrior Arms | `warrior/arms_sylvanas.lua` | wowsims `arms.apl.json`, IV/Wowhead | MS > OP > Slam > WW; Sunder early; Execute sub-20; Overpower weave | Stance dance, hit-cap, rage dumps, CDs | **aligned** |
| 2 | Warrior Fury | `warrior/fury_sylvanas.lua` | wowsims `fury.apl.json`, IV | Execute > BT > WW > Slam; HS dump; OP weave opt-in | Overpower weave toggle, Rampage, hit-cap | **source-disagreement**: IV allows BT between Executes; **wowsims Execute-first applied** |
| 3 | Warrior Protection | `warrior/protection_sylvanas.lua` | wowsims prot APL, IV | SS > Revenge > Devastate; Shield Block high; WW multi; Demo/TC | Threat vs mit, taunts, defensives, incoming-damage Shield Block | **aligned** (health_pred refresh polish in WIP) |
| 4 | Warrior Kebab | `warrior/kebab_sylvanas.lua` | community kebab/arms hybrid | MS/WW/Execute hybrid priority | Hybrid toggles | **aligned** |
| 5 | Paladin Retribution | `paladin/retribution_sylvanas.lua` | wowsims ret APL, Wowhead seal twist | CS > Judge under Blood/Martyr; Command r1 twist default ON | Seal twist, post-swing judge, Consecrate/Exo toggles | **aligned** |
| 6 | Paladin Protection | `paladin/protection_sylvanas.lua` | wowsims prot pally APL | Holy Shield > Judge > Seal > Consecrate; Avenger's pull | JoW mana hysteresis, HS charges, auras/blessings | **aligned** |
| 7 | Paladin Holy | `paladin/holy_sylvanas.lua` | IV / Wowhead / Tavern (no APL) | LG chain + build, HS emergency, FoL/HL triage, cleanse | HL threshold, LG build, blessings, solo seals | **aligned** |
| 8 | Hunter BM | `hunter/beast_mastery_sylvanas.lua` | wowsims hunter APL, IV | KC > Steady weave; Multi/Arcane; pet BW/Mend; aspects | Viper 5%/Hawk 25%, melee weave, shot buffer | **aligned** |
| 9 | Hunter MM | `hunter/marksmanship_sylvanas.lua` | same + Aimed opener ≤0.5s combat | Same shot priority; Aimed prepull only in combat gate | Trueshot, Readiness, aspect mana | **aligned** |
| 10 | Hunter Survival | `hunter/survival_sylvanas.lua` | same + traps/Wyvern | KC + Steady + melee weave (Raptor/Wing Clip) | Traps, Scorpid, weave | **aligned** |
| 11 | Rogue Assassination | `rogue/assassination_sylvanas.lua` | TBC Sin guides + rogue APL patterns | SnD > Rupture long TTD > Envenom (DP stacks) > Mutilate; Shiv DP | EA, min DP stacks, openers | **aligned** |
| 12 | Rogue Combat | `rogue/combat_sylvanas.lua` | wowsims `swords.apl.json` | SnD > Rupture > **Eviscerate** > SS; AR/BF CDs | Energy pooling, Envenom optional at 5 DP (after Evis per swords APL) | **source-disagreement**: poison-Envenom guides vs **swords APL Evis-first** — APL wins |
| 13 | Rogue Subtlety | `rogue/subtlety_sylvanas.lua` | Sub guides + APL patterns | Premed/Shadowstep openers; Hemo; SnD; Rupture | Vanish/Prep resets, positional BS | **aligned** |
| 14 | Priest Shadow | `priest/shadow_sylvanas.lua` | wowsims priest DPS APL | VT > SW:P > MB > MF (clip); Shadowfiend; SW:D | Multi-DoT, Inner Focus+MB, Fade | **aligned** |
| 15 | Priest Holy | `priest/holy_sylvanas.lua` | IV / Wowhead / Tavern | PWS/PoM/CoH/GH/FH tiers; Renew; Lightwell | Downrank tiers, stop-cast, idle DPS | **aligned** |
| 16 | Priest Discipline | `priest/discipline_sylvanas.lua` | IV / Wowhead | PWS tank/emergency, PoM, GH triage, PI/Pain Supp | Shield absorb gates, PI target | **aligned** |
| 17 | Mage Arcane | `mage/arcane_sylvanas.lua` | wowsims `arcane.apl.json` | Burn AB spam; conserve AB3→Frostbolt; gem/evo; AP/PoM | Burn/conserve thresholds, mana gem | **aligned** |
| 18 | Mage Fire | `mage/fire_sylvanas.lua` | IV / Wowhead (no tbc-new APL) | Scorch 5-stack duty > Fireball > Fire Blast move; Combustion | Scorch duty, AoE FS/AE, PoM Pyro | **aligned** (low-level Scorch gate fix in WIP) |
| 19 | Mage Frost | `mage/frost_sylvanas.lua` | IV / community frost | Frostbolt + WC; shatter Ice Lance; IV/WE/Cold Snap; Blizzard AoE | Shatter windows, water elemental | **aligned** |
| 20 | Warlock Affliction | `warlock/affliction_sylvanas.lua` | wowsims `affliction.apl.json` | Assigned curse > UA > Corruption/SL > SB; Drain Soul/Shadowburn execute | Multi-DoT, curse mode, pet | **aligned** |
| 21 | Warlock Demonology | `warlock/demonology_sylvanas.lua` | wowsims `demonology.apl.json` | Curse > Immolate/Corruption > SB; Felguard/Soul Link | Pet preference, Soul Link, Domination | **aligned** (Corruption before Immolate DPCT vs APL snapshot — guide majority) |
| 22 | Warlock Destruction | `warlock/destruction_sylvanas.lua` | wowsims `destruction.apl.json` + `destro_fire.apl.json` | Curse > Immolate > **Shadowburn execute** > Incinerate/SB; Conflagrate consume | Curse mode, Immolate min SP, Shadowburn HP | **gap → fixed**: Shadowburn was **after** ShadowBolt/Incinerate (dead while stationary). Reordered above fillers. |
| 23 | Shaman Elemental | `shaman/elemental_sylvanas.lua` | wowsims elemental APL | Totems first; CL when cast≥1s mana ok else LB; shocks | Totem set, EM/NS, BL | **aligned** |
| 24 | Shaman Enhancement | `shaman/enhancement_sylvanas.lua` | wowsims enhancement APL | SS on CD; WF/GoA twist; shocks; fire totems; SR low mana | Weapon imbues (level-aware), totem twist, shock twist | **aligned** |
| 25 | Shaman Restoration | `shaman/restoration_sylvanas.lua` | IV / Wowhead / Tavern | ES tank, CH cluster, HW/LHW triage, Water Shield | Shield type, downrank CH, totems | **aligned** |
| 26 | Druid Balance | `druid/balance_sylvanas.lua` | wowsims balance APL | IS/MF multi-dot; FF; Starfire filler; Hurricane AoE; Innervate | Multi-DoT opt, Starfall/FoN, mana Wrath | **aligned** |
| 27 | Druid Feral Cat | `druid/cat_sylvanas.lua` | wowsims feralcat APL, IV/Tavern | Mangle maintain; Rip ≥4–5 long TTD else FB; Shred; powershift; TF/Berserk | Bite-weave / Rip TTD, powershift, snapshot | **source-disagreement**: bite-weave vs full Rip — **TTD gates implement both** |
| 28 | Druid Feral Bear | `druid/bear_sylvanas.lua` | wowsims feralbear APL | Mangle > Lacerate > Demo; Maul dump; Swipe AoE; FR/Barkskin | Rage thresholds, FR HP, pure-bear (no shift) | **aligned** |
| 29 | Druid Restoration | `druid/resto_sylvanas.lua` | IV / Wowhead / Tavern | LB 3-stack roll; Swiftmend; Rejuv; Regrowth spot/downrank; Tree | Bloom let-bloom, innervate target, tree | **aligned** |

---

## Material fixes this pass

| Spec | Issue | Fix | Test |
|------|-------|-----|------|
| Destruction | Shadowburn listed after always-matching ShadowBolt/Incinerate → execute never cast while stationary | Move Shadowburn above fillers (matches `destro_fire.apl.json` Shadowburn-before-Incinerate) | `test_destruction_shadowburn.lua` asserts strategy index order |

## Non-material / deferred (documented, not blocking)

- **Fury Execute vs BT interleave** — IV vs wowsims; keep wowsims.
- **Combat Envenom vs Evis** — poison guides vs swords APL; keep Evis primary, Envenom secondary at 5 DP.
- **Cat bite-weave** — both paths exist via TTD/settings.
- **DeathCoil on Destruction** — EAX = self-HP survival; APL = target TTD execute. Not reworked (would change defensive semantics); Shadowburn covers execute damage.
- **Healer advanced health_pred / target_selector wiring** — quality polish present in working tree; not required for APL priority alignment.
- **Vanilla / WotLK** — out of primary scope per plan non-goals.

## Source index (local)

| Source | Path / URL class |
|--------|------------------|
| wowsims tbc-new APLs | `data/tbc-new/ui/**/apls/*.apl.json` |
| Prior research report | `plans/research_rotation_sources_report.md` |
| Become-1 completion | `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` |
| Scorecard | `docs/SCORECARD.md` (TBC avg ~4.7/5) |
| Written guides | Icy Veins TBC, Wowhead TBC, Warcraft Tavern (healers / Fire-Frost) |

## Validation notes

- Re-audit method: strategy name order extraction for all 29 files + APL spell-id priority lists + header source citations + prior Tier-3 audit notes.
- Only one **material** priority inversion found after re-check: Destruction Shadowburn.
- All other specs match prior closed gaps (Envenom sin, Conflagrate order, elemental totems, hunter buffer, ret twist default, etc.).
