# Implementation Plan: Vanilla Anniversary APL Audit (40 files)

**Created:** 2026-06-26
**Scope:** All `*_vanilla.lua` files under `EaxRotations/classes/`
**Game Version:** WoW Classic Anniversary (1.15.x)
**API Surface:** Same as TBC round — `api/` + `apidocs/`
**Docs References:** AGENTS.md Pattern 10, Pattern 14, Pattern 15

## Overview

The TBC APL optimization round is COMPLETE (all 29 specs). The next product-value target is the Vanilla Anniversary variant. The vanilla spell-contamination audit already passes (`run_vanilla_audit_tests.lua` — 31 spec files, 0 tainted), but APL priorities have NOT been guide-reviewed against Vanilla-specific sources.

Vanilla Anniversary (1.15.x) is a live product. Rotations differ from TBC because:
- No TBC spells/talents (e.g., no Vampiric Touch for Shadow Priest, no Kill Command for Hunter)
- Different talent trees (31-point capstone talents, no TBC additions)
- Level 60 cap, different itemization
- Some specs have fundamentally different priorities in Vanilla vs TBC

## Methodology (Per Spec)

Same as TBC round:
1. **Research** — Read 2–3 authoritative Vanilla/Classic sources
2. **Extract Priority List** — Build ordered priority list from guides
3. **Compare** — Read current `<spec>_vanilla.lua` strategy table
4. **Identify Gaps** — Missing strategies, wrong ordering, outdated spells
5. **Implement** — Edit spec file (Pattern 10, nil-guard per Pattern 14)
6. **Validate** — `luac -p` + `validate.cmd` + update test if behavior changes
7. **Commit** — One concern per commit

## Files to Touch

| File | Change | Verification |
|------|--------|------------|
| `EaxRotations/classes/<class>/<spec>_vanilla.lua` | Strategy reordering/addition/removal | Gate + luac -p |
| `EaxRotations/tests/test_<spec>_vanilla_*.lua` (existing) | Update if strategies change | Existing test must still pass |
| `plans/vanilla-apl-audit-2026-06.md` | Mark spec done | Track progress |

## Current State

- 40 vanilla files total: 31 spec + 9 leveling
- Only 5 have Pattern 15 headers (balance, bear, cat, resto druid, holy priest)
- 35 lack Pattern 15 — strong signal of older/less-maintained code
- Vanilla spell audit: 31 specs PASS, 0 tainted

## Task List

### Phase 1: Warrior + Paladin (7 specs) ✅ COMPLETE
- [x] **P1.1** Arms — verified Execute already above MS; added APL comment (Icy Veins/Wowhead)
- [x] **P1.2** Fury — Execute moved above Death Wish; Bloodthirst moved above Overpower; HS threshold 60→50
- [x] **P1.3** Protection — Revenge moved above ShieldSlam; Taunt/MockingBlow single-target gate removed; ShieldBlock buff ID fixed (2565)
- [x] **P1.4** Kebab — reviewed; Execute properly high (pos 3); no changes needed
- [x] **P1.5** Holy Paladin — reviewed; Flash of Light primary, Holy Light burst, downranking present; no changes needed
- [x] **P1.6** Protection Paladin — reviewed; Holy Shield > Consecration > Judgement > Seal; no taunt (correct); no changes needed
- [x] **P1.7** Retribution — reviewed; seal twisting, JoCrusader, Consecration all present; no changes needed

### Phase 2: Hunter + Mage (6 specs) ✅ COMPLETE
- [x] **P2.1** Beast Mastery — reviewed; no Steady Shot (correct for Vanilla), pet management + Multi-Shot/Arcane Shot; no changes needed
- [x] **P2.2** Marksmanship — reviewed; Aimed Shot > Multi-Shot cycle correct; no changes needed
- [x] **P2.3** Survival — reviewed; melee weaving (Raptor Strike/Wing Clip) + Scorpid Sting; niche spec, no changes needed
- [x] **P2.4** Arcane — reviewed; AP Frost hybrid (no Arcane Blast in Vanilla); Frostbolt primary + AM filler; burn/conserve phases; no changes needed
- [x] **P2.5** Fire — reviewed; Scorch 5-stack → Fireball → Fire Blast; Combustion + PoM; correct for Vanilla; no changes needed
- [x] **P2.6** Frost — fixed: Frostbolt moved above Scorch/ArcaneMissiles fillers (was below — primary nuke should never be last priority)

### Phase 3: Rogue + Warlock (6 specs) ✅ COMPLETE
- [x] **P3.1** Assassination — reviewed; SnD > Rupture > Eviscerate + Seal Fate crit procs; no changes needed
- [x] **P3.2** Combat — reviewed; SnD > Rupture(optional) > Eviscerate + AR/Blade Flurry; no changes needed
- [x] **P3.3** Subtlety — reviewed; Hemorrhage support build, Ghostly Strike, SnD; niche spec; no changes needed
- [x] **P3.4** Affliction — reviewed; SM/Ruin: Curse > Corruption > Shadow Bolt filler + Life Tap/Dark Pact; no changes needed
- [x] **P3.5** Demonology — reviewed; DS/Ruin: pet management + Corruption/Shadow Bolt + FelDomination; no changes needed
- [x] **P3.6** Destruction — reviewed; Immolate/Conflagrate (talent-gated) > Shadow Bolt spam; no changes needed

### Phase 4: Priest + Shaman + Druid (12 specs) ✅ COMPLETE
- [x] **P4.1** Discipline — reviewed; PW:S > Renew > Flash Heal; no Penance in Vanilla; no changes needed
- [x] **P4.2** Holy — reviewed; Greater Heal > Flash Heal > Renew > PoH; downranking present; no changes needed
- [x] **P4.3** Shadow — reviewed; SW:P > Mind Blast > Mind Flay; no Vampiric Touch in Vanilla (correct); no changes needed
- [x] **P4.4** Smite — reviewed; Smite spam + Power Infusion; no changes needed
- [x] **P4.5** Elemental — reviewed; Lightning Bolt + Chain Lightning + shocks; no changes needed
- [x] **P4.6** Enhancement — reviewed; Stormstrike + Earth Shock + auto-attack; no changes needed
- [x] **P4.7** Restoration — reviewed; Healing Wave, Lesser Healing Wave, Chain Heal; no changes needed
- [x] **P4.8** Balance — reviewed; Moonkin: Starfire/Moonfire/Insect Swarm; no changes needed
- [x] **P4.9** Feral Cat — reviewed; Shred + Rip + powershifting; no Savage Roar in Vanilla (correct); no changes needed
- [x] **P4.10** Feral Bear — FIXED: removed FerociousBiteExecute (cat-form ability w/ combo points — impossible in bear form); removed dead RAGE_SAFE_RESERVE constant; updated test_bear_vanilla_nil_guards (removed FerociousBiteExecute assertion + mock). Vanilla bear uses Maul > Swipe > Demo Roar (no Mangle/Lacerate)
- [x] **P4.11** Restoration (Druid) — reviewed; HoT stacking (Rejuv + Regrowth + Lifebloom); no changes needed
- [x] **P4.12** Caster — reviewed; support/OOC utility; no changes needed

### Phase 5: Leveling files (9 files)
- [ ] **P5.1** Audit all `leveling_vanilla.lua` files for Vanilla correctness

### Phase 6: Final Validation
- [ ] **P6.1** Full gate: `validate.cmd` → ALL CHECKS PASSED
- [ ] **P6.2** Pattern 15 headers added to all edited files
- [ ] **P6.3** Cut release zip after every 5–7 specs

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Vanilla guides are for Classic Era / SoD, not Anniversary 1.15.x | Wrong priorities | Cross-check multiple sources; Anniversary is close to Era baseline |
| Less test coverage for vanilla than TBC | Regression harder to catch | Run full gate after every change; add tests for behavior changes |
| Large scope (31 specs) causes fatigue/loops | Incomplete or buggy work | Phase-by-phase approach; stop after each phase if needed |

## References

- AGENTS.md Pattern 10 (spec structure), Pattern 14 (nil-guards), Pattern 15 (headers)
- `plans/apl-guide-optimization-2026-06.md` — TBC round methodology (proven)
- `EaxRotations/tests/run_vanilla_audit_tests.lua` — spell contamination gate
- `validate.cmd` — full validation gate (Lua 5.1)
