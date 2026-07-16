# TBC Anniversary Deep Audit Matrix (1–70 + content modes)

**Date:** 2026-07-16  
**Version:** **2.10.0** (Phase 2 spell ladders + Solo/Group/Dungeon/Raid-70 matches)  
**Scope:** 29 TBC combat `*_sylvanas.lua` + 9 `leveling_sylvanas.lua`  
**Evidence suite:** `test_tbc_spell_ladders.lua` (**281** cases) + `tbc_ladder_helper.lua` LEARN map  
**API sources:** `scraped_docs_md/dev/api/*`, `.api/` (read-only)  
**Raid-70 sources:** strategy index vs `data/tbc-new` APL structure where applicable; healer guides for triage  
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
| **Hunter** | Arcane/Serpent L10; Steady/KC blocked | mid Multi/BW blocked L25 | BW L40+ | Steady L50+ | KC L66+ | MendPet low pet HP | use_cooldowns / Multishot | MultiShot/Volley enemy_count **required** | KillCommand before Steady; Steady before Volley | ladders + settings + prio | **OK** |
| **Warrior** | HS/Sunder path L10; BT blocked L25 | mid fillers | BT/MS L40+ | mid | L70 | rage fillers | **sunder_mode** off/high | Cleave/WW multi **matches** | BT before HS; Execute before HS | ladders + sunder_mode + prio | **OK** |
| **Warlock** | SB/Corr/Imm L10; Conflag/UA blocked L25 | mid dots | Conflag 40 | UA 50 | Fel/Seed 70 | LifeTap/wand path | **warlock_curse_mode / assigned_curse** | Rain/Hellfire/Seed multi | Shadowburn before ShadowBolt | curse + Shadowburn prio | **OK** |
| **Mage** | Fireball L10 Scorch unlearned | Scorch 22+ | Combustion | AB L64 | L70 | Fireball solo | use_scorch / CDs / gem / pot | Flamestrike/AE path | Scorch before Fireball | Scorch gate + 4+ settings | **OK** |
| **Rogue** | SS/Evis L10 | SnD/Rupture | AR/BF | Mutilate 50 | Envenom 62 | energy builders | use_cooldowns / BF count | BladeFlurry multi + SnD | SnD before Evis | combat settings + prio | **OK** |
| **Shaman** | LB/EarthShock L10; SS blocked L25 | Flame/Frost | SS L40+ | WaterShield 62 | BL 70 | shocks solo | manage_totems / EM / FireNova | multi shocks WATCH | CL before LB | totem/EM settings + prio | **OK** |
| **Priest** | Smite/SW:P L10; VT/SF/SW:D blocked | MB/MF | mid | VT 50 | SF 66 / SW:D 62 | IdleSmite solo | holy_use_pws / PI / MB off | PoH WATCH | MB before MF | healer settings + VT/SF gates | **OK** |
| **Paladin** | Judge/HL L10; HS/CS blocked L25 | Consecrate 20 | HolyShield 40 | CS 50 | AW 70 | FoL/HL solo | prot_seal / sanctity / blessings | Consecration **required** multi | HolyShield before Consecration | seals+prio | **OK** |
| **Druid** | Bear/caster L10; **Cat B1 WATCH** (form L20) | Cat L25+ no Mangle (**FIX** MangleDebuff soft-gate) | mid | Mangle 50 | Lacerate 66 / LB 64 | self-heal/Hot | bear_demo / resto idle / insect | Swipe AoE WATCH | MoonfireDoT before StarfirePrimary | cat soft-gate + settings + prio | **OK** / Cat B1 **WATCH** |

## Settings spot-checks (shipped matches) — ≥3–5 keys per class
| Class | Keys proven (`test_tbc_spell_ladders`) |
|-------|----------------------------------------|
| Hunter | use_cooldowns, multishot_mode, use_volley, use_melee, use_explosive_trap |
| Warrior | sunder_mode (off + high match), kebab sunder off path |
| Warlock | warlock_curse_mode, warlock_assigned_curse (CoE/Agony), use_auto_potions |
| Mage | use_scorch_debuff, use_cooldowns, use_mana_gem, use_auto_potions, PresenceOfMind CD gate |
| Rogue | use_cooldowns, combat_blade_flurry_count, use_auto_potions (combat+sub) |
| Shaman | elemental_use_elemental_mastery, elemental_use_fire_nova_aoe, restoration_manage_totems, use_cooldowns (Bloodlust) |
| Priest | holy_use_pws, holy_use_poh, shadow_use_inner_fire, discipline_use_power_infusion, smite_use_mb |
| Paladin | prot_holy_shield, prot_consecration, prot_seal_of_righteousness, sanctity_aura_enabled, blessing_of_might_self |
| Druid | bear_demo_roar, balance_use_insect_swarm, resto_dps_when_idle, use_auto_potions, balance_auto_dispel |

## Raid-70 priority order (strategy index)
| Spec | Assertion | Source class |
|------|-----------|--------------|
| Fury | Bloodthirst < HeroicStrike; Execute < HeroicStrike | wowsims / TBC fury |
| BM | KillCommand < SteadyShot; SteadyShot < Volley | TBC hunter weave |
| Destro | Shadowburn < ShadowBolt | existing Shadowburn regression |
| Combat Rogue | SliceAndDice < Eviscerate | swords APL |
| Fire | Scorch < Fireball | TBC fire |
| Elemental | ChainLightning < LightningBolt | wowsims ele |
| Shadow | MindBlast < MindFlay | SP |
| Balance | MoonfireDoT < StarfirePrimary | balance |
| Prot | HolyShield < Consecration | tank priority |

## LEARN map (key TBC cores)
| Spell | Min level | Notes |
|-------|-----------|-------|
| SteadyShot | 50 | Hunter weave core |
| KillCommand | 66 | Pet burst |
| Bloodthirst / MortalStrike | 40 | Warrior talent |
| Mangle / MangleCat / MangleBear | 50 | Feral talent |
| Lacerate | 66 | Bear TBC |
| Lifebloom | 64 | Resto |
| VampiricTouch | 50 | Shadow |
| Shadowfiend | 66 | Mana |
| ShadowWordDeath | 62 | Shadow/Smite |
| Stormstrike | 40 | Enh |
| EarthShield | 50 | Resto |
| ArcaneBlast | 64 | Arcane |
| UnstableAffliction | 50 | Aff |
| FelArmor | 62 | Lock armor |
| IceLance | 66 | 2.5.5 backport — DBC valid |
| CrusaderStrike | 50 | Ret |
| AvengingWrath | 70 | Pally CD |
| Bloodlust | 70 | Shaman |

## Production code this release
| File | Change |
|------|--------|
| `tests/tbc_ladder_helper.lua` | **NEW** LEARN map + level-aware spell mock for TBC 1–70 |
| `tests/test_tbc_spell_ladders.lua` | **NEW** 281 cases: ladders B1–B5, AoE, settings, group overwrite, raid prio |
| `tests/run_rotation_tests.lua` | register `test_tbc_spell_ladders.lua` |
| `classes/druid/cat_sylvanas.lua` | **FIX** `MangleDebuff` soft-gate via `spell_exists(ACTION.MangleCat)` |

## Soft-gate audit notes
- 117 `spell_exists` call sites across `*_sylvanas.lua` (existing soft-gates).
- Ladder suite negative controls: Steady/KC/BW, BT/MS, Conflag/UA, AB, Mutilate, SS/ES, VT/SF/SW:D, HolyShield/CS, MangleDebuff/Lacerate.
- Cat `MangleDebuff` previously matched when unlearned → **FIX** this release.
- Cat B1 (L10) remains **WATCH** (Cat Form L20+); ladders start at L25 for cat.
