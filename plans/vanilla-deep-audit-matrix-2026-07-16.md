# Classic Vanilla Deep Audit Matrix (1–60 + content modes)

**Date:** 2026-07-16  
**Version:** **2.9.0** (Phase 2 ladders)  
**Scope:** 40 Vanilla ships (31 combat + 9 leveling)  
**API sources:** `scraped_docs_md/dev/api/*`, `.api/` (read-only)  
**Priority sources:** `data/wowsims_classic`, class rank `levels` tables  

## Status legend
| Code | Meaning |
|------|---------|
| **OK** | Ladder tests prove filler at L10/25/40/60 with high talents unlearned |
| **FIX** | Code fix in Phase 1/2 |
| **WATCH** | Soft-gate or level band N/A (documented) |

## Level bands
- **B1** 1–19 · **B2** 20–39 · **B3** 40–59 · **B4** 60 raid

## Content modes
- **S** solo · **G** group · **D** dungeon AoE · **R** raid 60

## Evidence suite
| Test | Proves |
|------|--------|
| `test_vanilla_content_coverage.lua` | All 40 modules load (class-gated) |
| `test_vanilla_spell_ladders.lua` | **175** cases: L10/25/40/60 fillers + high-talent blocked + content smokes |
| `vanilla_ladder_helper.lua` | LEARN map + `spell_ready` filter by level |
| `test_hunter_vanilla_aimed_shot.lua` | Aimed 3s weave + manual record |

---

## Per-class evidence (Phase 2)

| Class | Files | B1–B4 ladder | S/G/D/R | Notes | Status |
|-------|-------|--------------|---------|-------|--------|
| Hunter | BM, MM, Surv, leveling | Arcane/Serpent L10; Aimed blocked L10; BW blocked L25 | Pet Mend solo; Multi AoE | LEARN: Aimed 20, Multi 18, BW 40 | **OK** |
| Warrior | Arms, Fury, Prot, Kebab, leveling | HS/Rend/Sunder L10; BT blocked L25 | Cleave multi | LEARN: BT/MS 40 | **OK** |
| Warlock | Aff, Demo, Destro, leveling | SB/Corr/Imm L10; Conflag blocked L25 | FelArmor not required | SoulFire execute (2.7.9) | **OK** |
| Mage | Fire, Frost, Arcane, leveling | Fireball L10 w/ Scorch unlearned | — | Scorch 22 | **OK** |
| Rogue | Combat, Sin, Sub, leveling | SS/Evis/SnD ladder | — | No Envenom required | **OK** |
| Shaman | Ele, Enh, Resto, leveling | LB/shock L10; SS blocked L25 | Resto HealingWay | WoA no-op; SS soft | **OK** |
| Priest | Shadow, Smite, Holy, Disc, leveling | Smite/SW:P L10; SW:D/SF blocked L60 | Solo/group heal paths | No VT core | **OK** |
| Paladin | Ret, Prot, Holy, leveling | Judge/HL ladder; HS blocked L25 | Consecrate AoE | — | **OK** |
| Druid | Bal, Cat, Bear, Caster, Resto, leveling | Bear/caster L10; **Cat L25+** (form L20) | No Mangle required | Cat B1 N/A form unlock | **OK** / **WATCH** cat B1 |

## Content-mode smokes (in ladder suite)
- Hunter MendPet low pet HP (solo)
- Fury Cleave with multi targets
- Destruction FelArmor must not match Classic

## Residual WATCH
- Cat **B1 (1–19):** Cat Form is L20 — no cat combat ladder before 20 (by design).
- Enh Stormstrike: LEARN 40; blocked when unlearned (soft-gate).
- Smite TBC stubs: SW:D / Shadowfiend blocked at L60 via LEARN map.

## Material code this phase
| File | Change |
|------|--------|
| `tests/vanilla_ladder_helper.lua` | **New** learned-spell mock |
| `tests/test_vanilla_spell_ladders.lua` | **New** 9-class ladder suite |
| `classes/druid/cat_vanilla.lua` | `level or 60` for CP threshold (was 70) |
