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
- [x] Drain Soul TBC shard-capture (Affliction + Demonology) — not a Wrath sub-25% execute (`c3565364`)
- [x] Prot Paladin — Holy Shield above Consecration (crush-cap survival > threat) (`6b1ec84b`)
- [x] Prot Warrior — Demo Shout + Thunder Clap above Devastate (survival debuff uptime) (`a31d1fe5`)
- [x] Holy Paladin — Avenging Wrath burst CD added (heavy-healing window; the one missing-spell gap research surfaced) (`9b14c93e`)
- [x] Disc Priest — Pattern 15 header fixed (Wrath Penance/Borrowed refs removed; code was TBC-correct) (`df1c7ed6`)
- [x] ALL 3 tanks addressed: Prot Paladin fixed, Bear verified, Prot Warrior fixed
- [x] ALL 21 remaining specs VERIFIED vs guides, no change (DPS: Arms/BM/MM/Arcane/Fire/Frost/Combat/Enhancement/Smite/Shadow/Balance/Cat/Bear/Subtlety/Survival/Ret; healers: Holy Paladin/Holy Priest/Resto Druid/Resto Shaman/Disc-code)
- [x] G1–G4 DPS research + healer/tank research + Prot Warrior research agents (8 parallel, all completed)
- [x] Releases cut: v2026-06-26.442b0ac6 (DPS round) + v2026-06-26.aa67f8df (healer/tank round)

## APL ROUND COMPLETE — all 29 TBC specs reviewed (8 fixes + 1 gap-fill + 21 verified)

## In Progress
- (none active)

## Deferred / Next
- [ ] Vanilla Anniversary variant audit (`*_vanilla.lua`, lower priority)
- [ ] Optional new-spell gaps (e.g. Holy Paladin Avenging Wrath) — deferred (new-spell risk per Rule 5)
- [ ] B6.2 per-spec predictive threshold sliders
- [ ] EaxAutoQuester verification (separate product)
- [ ] Cut next release after tanking round (Prot Paladin + Prot Warrior fixes)

## Rules
- One concern per commit
- `luac -p` + full gate after every spec
- Update this file after each spec
- Reference: `plans/apl-guide-optimization-2026-06.md` (full matrix)
