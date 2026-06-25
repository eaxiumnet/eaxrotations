# APL Optimization Session — Active Effort

**Started:** 2026-06-25
**Agent:** main + 4 research subagents
**Goal:** Compare all 29 TBC specs against Wowhead/IcyVeins guides, fix priority gaps

## Method
1. **Research phase:** 4 parallel agents research guide priorities for spec groups
2. **Implementation phase:** Sequential edits, one spec at a time, gated
3. **Release:** Cut zip after every 5-7 specs

## Spec Groups

| Group | Specs | Agent Status |
|-------|-------|-------------|
| G1 Warrior + Paladin | arms, fury, prot, holy, prot, ret | 🔄 launching |
| G2 Hunter + Druid | bm, mm, surv, balance, cat, bear, resto | 🔄 launching |
| G3 Mage + Priest | arcane, fire, frost, holy, disc, shadow, smite | 🔄 launching |
| G4 Warlock + Rogue + Shaman | aff, demo, dest, assass, combat, subtle, ele, enh, resto | 🔄 launching |

## Completed
- [x] Fury Warrior — Execute repositioned below BT/WW (`014e81c7`)
- [x] Arms Warrior — verified correct (no changes)
- [x] Destruction / Elemental / Assassination — prior-session guide fixes (`f9b8a60f`/`6c88a6d8`/`23e5496d`)
- [x] Demonology — Corruption before Immolate (`cddd6393`) [this session]
- [x] 16 DPS specs VERIFIED vs guides, no change: Arms, BM, MM, Arcane, Fire, Frost, Combat (prior) + Enhancement, Smite, Shadow, Balance, Cat, Bear, Subtlety, Survival, Retribution (this session)
- [x] Affliction — ordering verified; DrainSoul execute caveat deferred
- [x] G1–G4 research agents (4 parallel, all completed)

## In Progress
- (none active)

## Deferred
- [ ] 5 healers (Holy Paladin, Holy Priest, Disc, Resto Druid, Resto Shaman) — reactive; separate healing-priority review
- [ ] Prot Paladin — tank threat, skipped (same rationale as Prot Warrior)
- [ ] Drain Soul sub-25% "execute" (Affliction + Demonology) — Wrath mechanic, not TBC; see `plans/deferred_drain_soul_execute.md`

## Rules
- One concern per commit
- `luac -p` + full gate after every spec
- Update this file after each spec
- Reference: `plans/apl-guide-optimization-2026-06.md` (full matrix)
