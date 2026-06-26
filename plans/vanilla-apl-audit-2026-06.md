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

### Phase 1: Warrior + Paladin (7 specs)
- [ ] **P1.1** Arms — compare against Classic Arms Warrior guide
- [ ] **P1.2** Fury — compare against Classic Fury Warrior guide
- [ ] **P1.3** Protection — compare against Classic Prot Warrior guide
- [ ] **P1.4** Kebab — compare (meme spec, likely low-priority)
- [ ] **P1.5** Holy Paladin — compare against Classic Holy Paladin guide
- [ ] **P1.6** Protection Paladin — compare against Classic Prot Paladin guide
- [ ] **P1.7** Retribution — compare against Classic Ret Paladin guide

### Phase 2: Hunter + Mage (6 specs)
- [ ] **P2.1** Beast Mastery — compare against Classic BM Hunter guide
- [ ] **P2.2** Marksmanship — compare against Classic MM Hunter guide
- [ ] **P2.3** Survival — compare against Classic SV Hunter guide
- [ ] **P2.4** Arcane — compare against Classic Arcane Mage guide
- [ ] **P2.5** Fire — compare against Classic Fire Mage guide
- [ ] **P2.6** Frost — compare against Classic Frost Mage guide

### Phase 3: Rogue + Warlock (6 specs)
- [ ] **P3.1** Assassination — compare against Classic Assassination Rogue guide
- [ ] **P3.2** Combat — compare against Classic Combat Rogue guide
- [ ] **P3.3** Subtlety — compare against Classic Subtlety Rogue guide
- [ ] **P3.4** Affliction — compare against Classic Affliction Warlock guide
- [ ] **P3.5** Demonology — compare against Classic Demonology Warlock guide
- [ ] **P3.6** Destruction — compare against Classic Destruction Warlock guide

### Phase 4: Priest + Shaman + Druid (13 specs)
- [ ] **P4.1** Discipline — compare against Classic Disc Priest guide
- [ ] **P4.2** Holy — compare against Classic Holy Priest guide
- [ ] **P4.3** Shadow — compare against Classic Shadow Priest guide
- [ ] **P4.4** Smite — compare against Classic Holy DPS Priest guide
- [ ] **P4.5** Elemental — compare against Classic Ele Shaman guide
- [ ] **P4.6** Enhancement — compare against Classic Enh Shaman guide
- [ ] **P4.7** Restoration — compare against Classic Resto Shaman guide
- [ ] **P4.8** Balance — compare against Classic Boomkin guide
- [ ] **P4.9** Feral Cat — compare against Classic Cat Druid guide
- [ ] **P4.10** Feral Bear — compare against Classic Bear Druid guide
- [ ] **P4.11** Restoration — compare against Classic Resto Druid guide
- [ ] **P4.12** Caster — compare (druid caster, likely low-priority)

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
