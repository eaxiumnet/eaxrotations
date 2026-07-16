# Classic Vanilla Deep Audit Matrix (1–60 + content modes)

**Date:** 2026-07-16  
**Version target:** 2.8.0  
**Scope:** 40 Vanilla ships (31 combat + 9 leveling)  
**API sources:** `scraped_docs_md/dev/api/*`, `.api/` (read-only)  
**Priority sources:** `data/wowsims_classic`, Wowhead/IV/Tavern Classic  

## Status legend
| Code | Meaning |
|------|---------|
| **OK** | Loaded, strategies present, known material gaps closed or soft-gated |
| **FIX** | Material fix landed this deep-audit pass |
| **WATCH** | Soft-gate / document; not combat-breaking when spell unlearned |

## Level bands
- **B1** 1–19 · **B2** 20–39 · **B3** 40–59 · **B4** 60 raid

## Content modes
- **S** solo · **G** group · **D** dungeon AoE/threat · **R** raid 60 APL

---

## Inventory (all 40)

| File | Role | B1–B4 | S/G/D/R | Notes / sources | Status |
|------|------|-------|---------|-----------------|--------|
| `druid/balance_vanilla.lua` | combat | OK | S/G/R | wowsims balance APL; MF/IS/Starfire | OK |
| `druid/bear_vanilla.lua` | combat | FIX level default 60 | S/D/R | Maul/Swipe; no Mangle required | FIX |
| `druid/cat_vanilla.lua` | combat | FIX level default 60 | S/D/R | low-level CP/FF gates | FIX |
| `druid/caster_vanilla.lua` | combat | FIX level default 60 | S | hybrid | FIX |
| `druid/resto_vanilla.lua` | combat | OK | G/D/R | HoTs no LB stacks required | OK |
| `druid/leveling_vanilla.lua` | leveling | OK | S/D | form + filler ladder | OK |
| `hunter/beast_mastery_vanilla.lua` | combat | OK | S/D/R | Aimed weave (v2.7.9+) | OK |
| `hunter/marksmanship_vanilla.lua` | combat | FIX pre-Aimed ladder | S/D/R | Classic fillers when Aimed down | FIX |
| `hunter/survival_vanilla.lua` | combat | FIX pre-Aimed ladder | S/D/R | Aimed + traps | FIX |
| `hunter/leveling_vanilla.lua` | leveling | OK | S/D | Aimed/Arcane/Multi/pet | OK |
| `mage/arcane_vanilla.lua` | combat | OK | S/R | AP Frost hybrid (no AB) | OK |
| `mage/fire_vanilla.lua` | combat | OK | S/R | Scorch known gate | OK |
| `mage/frost_vanilla.lua` | combat | OK | S/R | Frostbolt filler | OK |
| `mage/leveling_vanilla.lua` | leveling | OK | S/D | nuke ladder | OK |
| `paladin/holy_vanilla.lua` | combat | OK | G/D/R | FoL/HL | OK |
| `paladin/protection_vanilla.lua` | combat | OK | D/R | Holy Shield / Consec | OK |
| `paladin/retribution_vanilla.lua` | combat | OK | S/R | SoC/Judge | OK |
| `paladin/leveling_vanilla.lua` | leveling | OK | S/D | seals | OK |
| `priest/discipline_vanilla.lua` | combat | OK | G/D/R | PWS/PI | OK |
| `priest/holy_vanilla.lua` | combat | OK | G/D/R | FH/GH | OK |
| `priest/shadow_vanilla.lua` | combat | OK | S/R | no VT | OK |
| `priest/smite_vanilla.lua` | combat | WATCH | S | TBC stubs spell_exists | WATCH |
| `priest/leveling_vanilla.lua` | leveling | OK | S/D | Smite ladder | OK |
| `rogue/assassination_vanilla.lua` | combat | FIX level default 60 | S/R | BS/Evis | FIX |
| `rogue/combat_vanilla.lua` | combat | OK | S/R | SS/Evis | OK |
| `rogue/subtlety_vanilla.lua` | combat | OK | S/G | PvP lean | OK |
| `rogue/leveling_vanilla.lua` | leveling | OK | S/D | SS/Evis | OK |
| `shaman/elemental_vanilla.lua` | combat | OK | S/R | LB/CL; WoA no-op | OK |
| `shaman/enhancement_vanilla.lua` | combat | WATCH | S/R | Stormstrike soft-gate Era | WATCH |
| `shaman/restoration_vanilla.lua` | combat | OK | G/D/R | CH/HW | OK |
| `shaman/leveling_vanilla.lua` | leveling | OK | S/D | shocks | OK |
| `warlock/affliction_vanilla.lua` | combat | OK | S/R | dots/SB | OK |
| `warlock/demonology_vanilla.lua` | combat | OK | S/R | DS/Ruin | OK |
| `warlock/destruction_vanilla.lua` | combat | OK | S/R | SoulFire execute (v2.7.9) | OK |
| `warlock/leveling_vanilla.lua` | leveling | OK | S/D | dots/SB/wand | OK |
| `warrior/arms_vanilla.lua` | combat | OK | S/R | MS/OP | OK |
| `warrior/fury_vanilla.lua` | combat | OK | S/R | BT/WW | OK |
| `warrior/protection_vanilla.lua` | combat | OK | D/R | SS/Revenge | OK |
| `warrior/kebab_vanilla.lua` | combat | OK | S | hybrid | OK |
| `warrior/leveling_vanilla.lua` | leveling | OK | S/D | HS/Rend/BT | OK |

## Shared infrastructure
| Module | Change |
|--------|--------|
| `shared/leveling_helpers_sylvanas.lua` | `vanilla_level_from_context` → default **60** |
| `tests/test_vanilla_content_coverage.lua` | Loads all 40 files; BM/Destro band smoke |

## API compliance notes (scraped_docs / .api)
- Cast path: existing `NS.try_cast` / `spell_ready` (spellbook.md, spell_helper) — no new APIs introduced.
- Hunter weave: `HunterClipTracker.ms_until_auto` + buffer (same contract as shot timer docs).
- Pet: Call/Mend via spell_ready skip_range (pet-handler patterns).

## Material fixes this deep-audit pass
1. **Level default 70→60** on Vanilla combat paths (cat/bear/caster/assassin/hunter pre-Aimed).
2. **Hunter MM/Survival pre-Aimed ladder**: Classic has no Steady; enable Arcane/Sting fillers when Aimed unready or L&lt;20 (not TBC `&lt;62` with default 70).
3. **Coverage harness** proves all 40 modules load under mock NS.

## Residual risk
- Full per-spell “matches at L10 with only rank-1 learned” matrix needs ongoing class batches (Phase 2 of plan).
- Live dungeon/raid parse validation still out of environment scope.
