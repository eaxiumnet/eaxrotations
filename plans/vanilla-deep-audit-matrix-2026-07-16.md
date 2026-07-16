# Classic Vanilla Deep Audit Matrix (1–60 + content modes)

**Date:** 2026-07-16  
**Version:** **2.9.1** (Phase 2 skeptic hardening)  
**Scope:** 40 Vanilla ships (31 combat + 9 leveling)  
**Evidence suite:** `test_vanilla_spell_ladders.lua` (190 cases) + `vanilla_ladder_helper.lua` LEARN map  
**API sources:** `scraped_docs_md/dev/api/*`, `.api/` (read-only)  
**Raid-60 sources:** `data/wowsims_classic/**/apls/*.apl.json` (priority **order** assertions)

## Status legend
| Code | Meaning |
|------|---------|
| **OK** | Ladder + content/setting/priority tests pass for this cell |
| **WATCH** | Soft-gate / level N/A documented |
| **FIX** | Production code change |

## Level bands
**B1** 1–19 · **B2** 20–39 · **B3** 40–59 · **B4** 60

## Content modes
**S** solo · **G** group · **D** dungeon · **R** raid 60

---

## Per-class rows (all modes filled)

| Class | B1 | B2 | B3 | B4 | S | G | D | R | Evidence | Status |
|-------|----|----|----|----|---|---|---|---|----------|--------|
| **Hunter** | Arcane/Serpent L10; Aimed blocked | Multi 18+; BW blocked L25 | BW ready L40+ | Aimed>Arcane order | MendPet low pet HP | CDs via use_cooldowns | MultiShot enemy≥multishot_mode **required** | wowsims hunter p1 Aimed before Arcane | ladders + settings + prio | **OK** |
| **Warrior** | HS/Rend/Sunder L10; BT blocked L25 | WW/Cleave mid | BT L40+ | BT before HS; Execute before HS | rage fillers | Sunder/Demo settings path | Cleave **matches true** multi | wowsims dps fury order | ladders + Cleave assert + prio | **OK** |
| **Warlock** | SB/Corr/Imm L10; Conflag blocked L25 | mid dots | Conflag L40 | Shadowburn before SB | wand/LifeTap | AmplifyCurse setting off | Rain/Hellfire when multi (WATCH soft) | destro_fire Shadowburn>SB | ladders + aff setting + prio | **OK** |
| **Mage** | Fireball L10 Scorch unlearned | Scorch 22+ | Combustion talent | Scorch before Fireball | Fireball solo | — group n/a DPS | Flamestrike path WATCH | fire p1 Scorch>Fireball | ladders + use_scorch_debuff + prio | **OK** |
| **Rogue** | SS/Evis L10 | SnD/Rupture | AR/BF talents | SnD before Evis | energy builders | no Envenom required | Fan/AoE WATCH | swords SnD>Evis | ladders + prio | **OK** |
| **Shaman** | LB/EarthShock L10; SS blocked L25 | Flame/Frost | SS L40+ | CL before LB | shocks solo | totems group WATCH | multi shocks WATCH | elemental CL>LB | ladders + prio; SS soft | **OK** |
| **Priest** | Smite/SW:P L10; SW:D/SF blocked L60 | MB/MF | disc shields | MB before MF | IdleSmite solo | Holy/Disc triage | PoH WATCH | shadow MB>MF | ladders + TBC stub blocks | **OK** |
| **Paladin** | Judge/HL L10; HS blocked L25 | Consecrate 20 | HolyShield 40 | seal/judge | FoL/HL solo | blessings G | Consecration **required** multi; setting off | ret SoC/Judge structure | ladders + prot settings + AoE | **OK** |
| **Druid** | Bear/caster L10; **Cat B1 WATCH** (form L20) | Cat L25+ no Mangle | mid | Moonfire before Starfire | self-heal/Hot | resto group | Swipe AoE WATCH | balance dots before Starfire | ladders + cat no-Mangle | **OK** / Cat B1 **WATCH** |

## Settings spot-checks (shipped matches)
| Setting key | Module | Behavior proven |
|-------------|--------|-----------------|
| `use_cooldowns=false` | hunter BM | BestialWrath does not match |
| `multishot_mode=0` | hunter BM | MultiShot does not match |
| `use_scorch_debuff=false` | mage fire | Fireball matches without stacks |
| `aff_use_amplify_curse=false` | affliction | AmplifyCurse does not match |
| `prot_consecration=false` | prot pally | Consecration does not match |

## Raid-60 priority order (strategy index)
| Spec | Assertion | Source class |
|------|-----------|--------------|
| Fury | Bloodthirst < HeroicStrike; Execute < HeroicStrike | wowsims warrior dps |
| BM / MM | AimedShot / InCombatAimedShot < ArcaneShot | wowsims hunter p1 |
| Destro | Shadowburn < ShadowBolt | wowsims destro |
| Combat Rogue | SliceAndDice < Eviscerate | wowsims swords |
| Fire | Scorch < Fireball | classic fire |
| Elemental | ChainLightning < LightningBolt | wowsims ele |
| Shadow | MindBlast < MindFlay | wowsims SP |
| Balance | MoonfireDoT < StarfirePrimary | wowsims balance |

## Production code this release train
| File | Change |
|------|--------|
| `tests/vanilla_ladder_helper.lua` | LEARN map; settings-aware spec_kit mock |
| `tests/test_vanilla_spell_ladders.lua` | 190 cases incl. hard AoE, settings, raid prio |
| `classes/druid/cat_vanilla.lua` | CP threshold `level or 60` |
