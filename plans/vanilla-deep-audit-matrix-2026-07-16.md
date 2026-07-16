# Classic Vanilla Deep Audit Matrix (1–60 + content modes)

**Date:** 2026-07-16  
**Version:** **2.9.2** (Phase 2 per-class settings + group overwrite)  
**Scope:** 40 Vanilla ships (31 combat + 9 leveling)  
**Evidence suite:** `test_vanilla_spell_ladders.lua` (**236** cases) + `vanilla_ladder_helper.lua` LEARN map  
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
| **Warrior** | HS/Rend/Sunder L10; BT blocked L25 | WW/Cleave mid | BT L40+ | BT before HS; Execute before HS | rage fillers | **sunder_armor_mode / maintain_demo_shout** on fury+kebab | Cleave **matches true** multi | wowsims dps fury order | settings tests + Cleave + prio | **OK** |
| **Warlock** | SB/Corr/Imm L10; Conflag blocked L25 | mid dots | Conflag L40 | Shadowburn before SB | wand/LifeTap | **warlock_curse_mode / assigned_curse** block CoE/Agony | Rain/Hellfire when multi (WATCH soft) | destro_fire Shadowburn>SB | curse overwrite tests + prio | **OK** |
| **Mage** | Fireball L10 Scorch unlearned | Scorch 22+ | Combustion talent | Scorch before Fireball | Fireball solo | use_interrupt / use_scorch | Flamestrike path WATCH | fire p1 Scorch>Fireball | 5+ fire settings + prio | **OK** |
| **Rogue** | SS/Evis L10 | SnD/Rupture | AR/BF talents | SnD before Evis | energy builders | use_cooldowns / blade_flurry_count | Fan/AoE WATCH | swords SnD>Evis | combat settings + prio | **OK** |
| **Shaman** | LB/EarthShock L10; SS blocked L25 | Flame/Frost | SS L40+ | CL before LB | shocks solo | restoration_manage_totems off | multi shocks WATCH | elemental CL>LB | totem/EM settings + prio | **OK** |
| **Priest** | Smite/SW:P L10; SW:D/SF blocked L60 | MB/MF | disc shields | MB before MF | IdleSmite solo | holy_use_pws / PI / MB off | PoH WATCH | shadow MB>MF | healer settings + TBC stubs | **OK** |
| **Paladin** | Judge/HL L10; HS blocked L25 | Consecrate 20 | HolyShield 40 | seal/judge | FoL/HL solo | **prot_seal / sanctity / blessings** | Consecration **required** multi | ret seal order + HolyShield<Cons + HL<Smart | seals+prio tests | **OK** |
| **Druid** | Bear/caster L10; **Cat B1 WATCH** (form L20) | Cat L25+ no Mangle | mid | Moonfire before Starfire | self-heal/Hot | bear_demo_roar / resto group idle | Swipe AoE WATCH | balance dots before Starfire | demo+idle settings + prio | **OK** / Cat B1 **WATCH** |

## Settings spot-checks (shipped matches) — ≥3–5 keys per class
| Class | Keys proven (test_vanilla_spell_ladders) |
|-------|------------------------------------------|
| Hunter | use_cooldowns, multishot_mode, use_volley, use_melee, use_explosive_trap |
| Warrior | sunder_armor_mode, use_sunder_armor, maintain_demo_shout (fury+kebab) |
| Warlock | warlock_curse_mode, warlock_assigned_curse, aff_use_amplify_curse, use_auto_potions |
| Mage | use_scorch_debuff, use_cooldowns, use_interrupt, use_mana_gem, use_auto_potions |
| Rogue | use_cooldowns, combat_blade_flurry_count, use_auto_potions (combat+sub) |
| Shaman | elemental_use_elemental_mastery, elemental_use_fire_nova_aoe, restoration_manage_totems, use_ooc_buffs, use_cooldowns |
| Priest | holy_use_pws, holy_use_poh, shadow_use_inner_fire, discipline_use_power_infusion, smite_use_mb |
| Paladin | prot_consecration, prot_seal_of_righteousness, prot_holy_shield, prot_judgement, sanctity_aura_enabled, blessing_of_might_self |
| Druid | bear_demo_roar, balance_use_insect_swarm, balance_auto_dispel, resto_dps_when_idle, barkskin_hp, use_auto_potions |

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
| Ret | Ret_ApplyCrusaderSeal < Ret_SealCommand_Primary; Ret_JudgeCrusader < Ret_JudgeDamageSeal | classic ret |
| Prot | HolyShield < Consecration | tank priority |
| Holy | HolyLightEmergency < SmartHeal | triage |

## Production code this release train
| File | Change |
|------|--------|
| `tests/vanilla_ladder_helper.lua` | LEARN map; settings-aware spec_kit mock |
| `tests/test_vanilla_spell_ladders.lua` | 236 cases: ladders, AoE, per-class settings, group overwrite, raid prio |
| `classes/warrior/fury_vanilla.lua` | Sunder/Demo honor `sunder_armor_mode` / `maintain_demo_shout` |
| `classes/warlock/affliction_vanilla.lua` | `warlock_curse_mode` / `warlock_assigned_curse` gates CoE/Agony/Doom |
| `classes/druid/cat_vanilla.lua` | CP threshold `level or 60` |
