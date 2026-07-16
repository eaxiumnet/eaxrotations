# TBC Anniversary Deep Audit Matrix (1–70 + content modes)

**Date:** 2026-07-16  
**Version:** **2.10.0** (Phase 2 spell ladders + Solo/Group/Dungeon/Raid-70 matches)  
**Scope:** 29 TBC combat `*_sylvanas.lua` + 9 `leveling_sylvanas.lua`  
**Evidence suite:** `test_tbc_spell_ladders.lua` (**275** cases) + `tbc_ladder_helper.lua` LEARN map  
**API sources:** `scraped_docs_md/dev/api/*`, `.api/` (read-only)  
**Raid-70 sources:** strategy index vs wowsims/tbc-new structure where applicable  
**Baseline not re-claimed:** `plans/tbc-rotation-gap-matrix-2026-07-16.md` endgame “aligned” header pass

## Status legend
| Code | Meaning |
|------|---------|
| **OK** | Ladder + content/setting/priority tests pass for this cell |
| **WATCH** | Soft-gate / level N/A documented |
| **FIX** | Production code change this release |
| **GAP** | Known hole (must not mark OK) |

## Level bands
**B1** L10 · **B2** L25 · **B3** L40 · **B4** L60 · **B5** L70

## Content modes
**S** solo · **G** group · **D** dungeon · **R** raid 70

---

## Per-class rows (all modes filled)

| Class | B1 | B2 | B3 | B4 | B5 | S | G | D | R | Evidence | Status |
|-------|----|----|----|----|----|---|---|---|---|----------|--------|
| **Hunter** | Arcane/Serpent L10; Steady/KC blocked | mid; BW blocked L25 | BW L40+ | Steady 50+ | KC 66+ | MendPet low pet HP | RapidFire `use_cooldowns` ON/OFF | MultiShot/Volley required | KillCommand&lt;Steady&lt;Volley | ladders + 5 flips + prio | **OK** |
| **Warrior** | HS path L10; BT blocked L25 | mid | BT/MS L40+ | mid | L70 | rage fillers | sunder_mode + DeathWish/Reck CDs + kebab sunder/demo | Cleave multi **matches** | BT&lt;HS; Execute&lt;HS | ladders + ≥3 flips + prio | **OK** |
| **Warlock** | SB/Corr/Imm L10; Conflag/UA blocked | mid | Conflag 40 | UA 50 | L70 | LifeTap path | curse_mode + assigned_curse ON/OFF | Rain/Hellfire/Seed multi | Shadowburn&lt;SB | curse flips + prio | **OK** |
| **Mage** | Fireball L10 Scorch unlearned | Scorch 22+ | Combustion | AB 64 | L70 | Fireball solo | use_scorch + Combustion CDs + ManaGem | Flamestrike/AE path | Scorch&lt;Fireball | 3+ flips + prio | **OK** |
| **Rogue** | SS/Evis L10 | SnD/Rupture | AR/BF | Mutilate 50 | Envenom 62 | energy builders | use_cooldowns BF + blade_flurry_count | BladeFlurry multi + SnD | SnD&lt;Evis | BF flips + prio | **OK** |
| **Shaman** | LB/EarthShock L10; SS blocked | mid | SS L40+ | WaterShield 62 | BL 70 | shocks solo | EM + FireNova + manage_totems + Bloodlust CDs | FireNovaTotem multi **required** | CL&lt;LB | 5 flips + dungeon AoE | **OK** |
| **Priest** | Smite/SW:P L10; VT/SF/SW:D blocked | MB/MF | mid | VT 50 | SF 66 | IdleSmite solo | smite_use_mb + holy_use_pws + disc PI OFF | PsychicScream enemy_count≥3 **required** | MB&lt;MF | settings OFF + dungeon AoE | **OK** |
| **Paladin** | Judge/HL L10; HS/CS blocked | Consecrate 20 | HolyShield 40 | CS 50 | AW 70 | FoL/HL solo | prot_holy_shield + consecration + seal OFF | Consecration multi **required** | HolyShield&lt;Cons | seal/HS/Cons flips | **OK** |
| **Druid** | Bear/caster L10; **Cat B1 WATCH** (form L20) | Cat L25+ no Mangle (**FIX** MangleDebuff) | mid | Mangle 50 | Lacerate 66 | self-heal | bear_demo + insect_swarm + resto SoloWrath | SwipeAoE multi **required** | MoonfireDoT&lt;StarfirePrimary | cat soft-gate + flips + AoE | **OK** / Cat B1 **WATCH** |

## Settings spot-checks — honest ON=true / OFF=false (or OFF-only where noted)

| Class | Keys proven in `test_tbc_spell_ladders` |
|-------|----------------------------------------|
| Hunter | **use_cooldowns** (RapidFire), **multishot_mode**, **use_volley**, **use_melee**, **use_explosive_trap** — all ON/OFF |
| Warrior | **sunder_mode** (SunderArmor), **use_cooldowns** (DeathWish + Recklessness), kebab **sunder_armor_mode**, kebab **maintain_demo_shout** — all ON/OFF |
| Warlock | **warlock_curse_mode**, **warlock_assigned_curse** (CoE/Agony) — ON/OFF |
| Mage | **use_scorch_debuff** (Fireball when off), **use_cooldowns** (Combustion), **use_mana_gem** — ON/OFF |
| Rogue | **use_cooldowns** (BladeFlurry), **combat_blade_flurry_count** (high vs low targets) |
| Shaman | **elemental_use_elemental_mastery**, **elemental_use_fire_nova_aoe**, **restoration_manage_totems** (Strength + ManaSpring), **use_cooldowns** (enh Bloodlust) — ON/OFF |
| Priest | **smite_use_mb** ON/OFF; **holy_use_pws** OFF blocks; **discipline_use_power_infusion** OFF blocks |
| Paladin | **prot_holy_shield**, **prot_consecration** ON/OFF; **prot_seal_of_righteousness** OFF blocks |
| Druid | **bear_demo_roar**, **balance_use_insect_swarm** ON/OFF; **resto_dps_when_idle** solo ON / group OFF |

## Raid-70 priority order (strategy index)
| Spec | Assertion |
|------|-----------|
| Fury | Bloodthirst &lt; HeroicStrike; Execute &lt; HeroicStrike |
| BM | KillCommand &lt; SteadyShot; SteadyShot &lt; Volley |
| Destro | Shadowburn &lt; ShadowBolt |
| Combat Rogue | SliceAndDice &lt; Eviscerate |
| Fire | Scorch &lt; Fireball |
| Elemental | ChainLightning &lt; LightningBolt |
| Shadow | MindBlast &lt; MindFlay |
| Balance | MoonfireDoT &lt; StarfirePrimary |
| Prot | HolyShield &lt; Consecration |

## LEARN map (key TBC cores)
| Spell | Min level |
|-------|-----------|
| SteadyShot | 50 |
| KillCommand | 66 |
| Bloodthirst / MortalStrike | 40 |
| Mangle | 50 |
| Lacerate | 66 |
| Lifebloom | 64 |
| VampiricTouch | 50 |
| Shadowfiend | 66 |
| ShadowWordDeath | 62 |
| Stormstrike | 40 |
| EarthShield | 50 |
| ArcaneBlast | 64 |
| UnstableAffliction | 50 |
| FelArmor | 62 |
| IceLance | 66 (2.5.5 backport) |
| CrusaderStrike | 50 |
| Bloodlust | 70 |

## Production code this release
| File | Change |
|------|--------|
| `tests/tbc_ladder_helper.lua` | LEARN map + level-aware spell mock |
| `tests/test_tbc_spell_ladders.lua` | 275 cases: ladders, honest setting flips, dungeon AoE, raid prio |
| `tests/run_rotation_tests.lua` | register suite |
| `classes/druid/cat_sylvanas.lua` | **FIX** `MangleDebuff` soft-gate via `spell_exists(ACTION.MangleCat)` |

## Soft-gate audit
- Negative controls assert strategy **presence** then non-match (no silent skip).
- `EarthShieldTank` blocked at L25 when `earth_shield_ready` false from LEARN (not forced ready).
- Cat `MangleDebuff` soft-gated this release.
- Cat B1 L10 remains **WATCH** (Cat Form L20+).
