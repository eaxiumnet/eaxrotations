# AoE Logic vs Spell Hit Range Audit (all EaxRotations)

**Date:** 2026-07-16  
**Scope:** **All** `EaxRotations/` rotation paths that gate/prioritize multi-target **damage** — `*_sylvanas.lua` (TBC Anniversary 2.5.5), `*_vanilla.lua` (Classic Era), `*_wotlk.lua` + `classes/deathknight/**` (WotLK), plus `main_sylvanas.lua` / `core_sylvanas.lua` / shared consumers those paths use.  
**Status:** Analysis + **hit-volume fixes shipped** (2026-07-16) — see `shared/aoe_hit_volume_sylvanas.lua`, `NS.aoe_self_meets` / `NS.aoe_target_meets`  
**Authoritative data:**
- **TBC / shared Classic ranks:** `wowheadScrape/dbc_extract/wowsims.db` (client **2.5.5** extract) `SpellEffect` → `SpellRadius`, descriptions
- **WotLK-only spell IDs** (Howling Blast, Fan of Knives, Divine Storm, D&D ranks, etc.): **absent from this DBC** — radii labeled **Community/WotLK** or from partial overlapping ids (e.g. D&D base 43265 in extract if present); never invented as DBC
- Hardcodes next to casts (`get_aoe_cast_position(..., 8, 35)`)

**File inventory (classes/):** ~76 `*_sylvanas.lua`, ~40 `*_vanilla.lua`, ~41 `*_wotlk.lua` (includes DK).

---

## Method

1. **Global count source** — traced `context.enemy_count` / Auto-AoE from `main_sylvanas.lua` → `throttled_enemies()` (40yd). Same field feeds **all** expansions that copy `context.enemy_count` into `state`.
2. **Helpers** — `NS.GetEnemiesInRange(range)`, `NS.GetEnemiesCount(range)`, `NS.get_aoe_cast_position(...)`.
3. **Inventory** — grepped **all** of:
   - `EaxRotations/classes/**/*_sylvanas.lua`
   - `EaxRotations/classes/**/*_vanilla.lua`
   - `EaxRotations/classes/**/*_wotlk.lua`
   - `EaxRotations/classes/deathknight/**`
   - `main_sylvanas.lua`, `core_sylvanas.lua`, relevant `shared/*`
   for `enemy_count` / `GetEnemiesInRange` / `get_aoe_cast_position` and named multi-target damage spells (incl. WotLK: Howling Blast, Death and Decay, Blood Boil, Fan of Knives, Divine Storm, Hammer of the Righteous, Pestilence; Classic/TBC set as before).
4. **Per-path** — count gate, cast path, hit volume + confidence, mismatch severity.
5. **Prior art** — `plans/_archive/range-verification-audit-2026-07-06.md` is **cast-range OOR stall**, not multi-hit geometry.
6. **Healing AoE** — noted only when damage rotations reuse helpers incorrectly; not scored for heal quality.

### Confidence labels for radii

| Label | Meaning |
|-------|---------|
| **DBC** | `SpellEffect.EffectRadiusIndex` → `SpellRadius.Radius` in **2.5.5** wowsims.db |
| **DBC-effect** | Triggered effect spell id in same DBC |
| **Hardcode** | Literal yards in rotation / helper args |
| **Community** | Jump/cleave distance not cleanly on spell row |
| **Community/WotLK** | Spell id **not in** TBC DBC extract; radius from WotLK tooltips/sim community tables — **not DBC-verified here** |

`RangeIndex` has **no** linked `SpellRange` table in this extract; cast ranges use description + RI clusters (1≈self, 2≈melee, 4≈~30yd, 35/114≈hunter).

---

## Global context facts

### `context.enemy_count` / Auto-AoE

| Item | Value | Source |
|------|-------|--------|
| Scan range | **40 yards** | `main_sylvanas.lua` `throttled_enemies()` → `target_selector:get_targets(40)` / `unit_helper.get_enemy_list_around(..., 40)` / `NS.GetEnemiesInRange(40)` |
| Throttle | ~100 ms | `now - _cached_enemies_time > 100` |
| Count field | `_context.enemy_count` | `#enemies` / `enemies.n` |
| Smoothed | `enemy_count_smoothed` | `enemy_count_hysteresis_sylvanas` (opt-in) |
| Auto-AoE default threshold | **3** | `get_auto_aoe_threshold()`; setting `auto_aoe_enabled` |
| Auto-AoE debounce | 0.5 s stable | `resolve_auto_aoe_playstyle` |

**Implication:** Any strategy that gates solely on `context.enemy_count` / `state.enemy_count` (copied from context) is counting enemies in a **40yd sphere around the player**, not in the spell’s hit volume. That is intentional for playstyle switching; it is a **geometry mismatch** when the same field is the only multi-target gate for short-radius spells.

### `NS.GetEnemiesInRange(range)`

- Player-centered; `range` defaults to **40** if non-numeric.
- Merges `me:get_enemies_in_range`, `izi.enemies`, `unit_get_enemies_around`, visible units.
- Per-tick cache keyed by range.

### `NS.get_aoe_cast_position(spell_id, target, radius, max_range, min_hits)`

- Defaults: **radius=8**, **max_range=35**, `min_hits=1`, geometry `CIRCLE`, prediction `MOST_HITS`.
- If `spell_prediction` API missing: falls back to **target position**, hit_count=1 (no multi-hit validation).
- Used by: Fire/Frost Blizzard, Affliction/Demo/Destro Rain of Fire, Survival/BM Volley (and leveling Blizzard). **Hurricane / Flamestrike / Consecration** do **not** consistently use it for cast position.

---

## Spell geometry reference (TBC max ranks where available)

| Spell | Maxrank id (ex.) | Cast shape | Hit volume | Source |
|-------|------------------|------------|------------|--------|
| Whirlwind | 1680 | Self | **8 yd** circle | DBC |
| Thunder Clap | 25264 | Self | **8 yd** | DBC |
| Piercing Howl | 12323 | Self | **10 yd** | DBC |
| Cleave | 25231 | Melee (RI=2) | Primary + **1** nearest ally (chain 2) | DBC chain; jump ~melee of primary (Community ~5–8 yd of target) |
| Sweeping Strikes | 12328 | Self buff | Cleaves next melee hits | Buff, not area spell |
| Swipe (Bear) | 26997 | Melee | Up to **3** nearby (chain 3) | DBC |
| Demo / Challenging Roar | 26998 / 5209 | Self | **10 yd** | DBC |
| Hurricane | 27012 | Ground ~30 yd (RI=4) | **8 yd** circle | DBC; hardcode often 8/35 |
| Arcane Explosion | 27082 | Self | **10 yd** | DBC |
| Blast Wave | 33933 | Self | **10 yd** | DBC |
| Cone of Cold / Dragon’s Breath | 27087 / 33043 | Self frontal cone | **10 yd** cone | DBC radius + frontal ImplicitTarget |
| Frost Nova | 27088 | Self | **10 yd** | DBC |
| Flamestrike | 27086 | Ground ~30 yd | **5 yd** circle | DBC (not 8) |
| Blizzard | 27085 | Ground ~30 yd | **8 yd** | DBC; hardcode 8/35 |
| Consecration | 27173 | Self | **8 yd** under feet | DBC |
| Holy Wrath | 27139 | Self-ish undead/demon | Short PBAoE (undead/demon filter) | Spec-gated by creature type |
| Holy Nova | 25331 | Self | **10 yd** | DBC |
| Rain of Fire | 27212 | Ground ~30 yd | **8 yd** | DBC; hardcode 8/35 |
| Hellfire | 27213 | Self channel | **10 yd** via Hellfire Effect **5857** | DBC-effect |
| Seed of Corruption | 27243 | Unit ~30 yd | DoT on target; detonation **15 yd** (27285) | DBC-effect |
| Shadowfury | 30414 | Ground ~30 yd | **8 yd** | DBC |
| Howl of Terror | 17928 | Self | **10 yd** | DBC |
| Multi-Shot | 27021 | Ranged (RI=114 ~35) | Target + up to **2** nearby (chain 3) | DBC chain; jump Community ~8 yd of target |
| Volley | 27022 | Ground ~35 | **8 yd** | DBC; hardcode 8/35 |
| Explosive Trap Effect | 13812+ | Trap | **10 yd** on trigger | DBC |
| Chain Lightning | 25442 | Unit ~30 | Target + jumps (chain 3) | DBC; jump Community ~10–12 yd |
| Magma Totem pulse | 8187+ | Totem feet | **8 yd** | DBC |
| Fire Nova (totem explosion) | 25537 row / totem ranks | Totem | **~10 yd** from totem | DBC on nova effect |
| Blade Flurry | 13877 | Self buff | Extra melee on **1** nearby | Buff; Community melee |

---

## Inventory by class / spec

Legend for **Count gate**:  
- `ctx40` = `context.enemy_count` / state copy of same (40yd)  
- `local(N)` = `GetEnemiesInRange(N)` / `GetEnemiesCount(N)`  
- `melee-target` = requires hostile target in melee for cast, but count still often ctx40  
- `pos(R,M)` = `get_aoe_cast_position(..., R, M)`

### Core / main (shared)

| Path | Role | Count / range | Spell geometry | Notes |
|------|------|---------------|----------------|-------|
| `throttled_enemies` | Global ST/AoE density | 40yd | N/A | Feeds Auto-AoE + almost all `enemy_count` |
| `action.enemy_count` in evaluate | Generic action min count | ctx40 | Per-action | `core_sylvanas` ~5957 |
| `get_aoe_cast_position` | Ground placement | radius/max_range args | CIRCLE MOST_HITS | Defaults 8 / 35 |

### Warrior

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Arms / Fury / Prot / Kebab | Whirlwind | ctx40 ≥2 (or rage dump) | 8 yd self | **Mismatch** if packs not stacked on player |
| Arms / Fury / Prot / Kebab | Cleave | ctx40 ≥2 | Melee + 1 ally near **target** | Soft: needs secondary near target, not near player at 40yd |
| Arms / Fury / Prot | Thunder Clap | often debuff/ST; multi uses ctx40 | 8 yd self | Soft–clear when gated on ctx40 only |
| Arms | Piercing Howl | ctx40 ≥2–3 | 10 yd self | Soft |
| Arms / Fury | Sweeping Strikes | ctx40 ≥ min_count | Buff | Soft: SS useful only if second target in melee of primary |
| Leveling | same family | ctx40 | same | Same |

### Druid

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Bear | SwipeAoE / Swipe | ctx40 ≥ aoe_threshold (3) / ≥2 | Melee cone, up to 3 | Soft–clear: count 40yd vs melee front |
| Bear | Demo Roar etc. | ctx40 | 10 yd | Soft |
| Balance | HurricaneAoE | ctx40 ≥ setting (def 3) | Ground 8 yd @ ~30 cast | Soft: count not cluster; **no** `get_aoe_cast_position` on cast (target-only) |
| Balance | multi-DoT helpers | GetEnemies ~30 + multidot filter | DoT range | Better than ctx40 for spread; not ground-AoE |
| Cat | `should_aoe` | ctx40 ≥ threshold | No TBC cat swipe AoE damage spell | Mode only |
| Leveling | SwipeBear / Hurricane | enemy_count style | melee / 8 ground | Same family |
| Resto | GetEnemies 40 | utility / not DPS AoE | N/A | N/A damage |

### Mage

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Fire | ArcaneExplosion | ctx40 ≥3 | **10 yd self** | **Clear bug** risk (false AoE at range) |
| Fire | Flamestrike | ctx40 ≥3, not moving | Ground **5 yd** | Soft (count) + hardcode mismatch if assumed 8 |
| Fire | Blizzard | ctx40 ≥4; `pos(8,35)` | Ground 8 | Soft count; position helper OK |
| Fire | BlastWave / DragonsBreath | ctx40 ≥2 | 10 yd PBAoE / cone | **Clear** if used while kiting at 20–30yd |
| Frost | ArcaneExplosion | ctx40 ≥3 | 10 yd self | **Clear** same as Fire |
| Frost | Blizzard | ctx40 ≥3; `pos(8,35)` | 8 ground | Soft count; pos OK |
| Frost | ConeOfCold | target dist ≤10 + frozen **or** ctx40 ≥2 | 10 yd cone | **Partial**: dist gate on primary only; multi uses ctx40 not local cone |
| Arcane | FrostNova | peel / utility | 10 yd self | Utility |
| Leveling | Blizzard / CoC / FN | similar | same | same |

### Warlock

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Affliction | SeedOfCorruption | ctx40 ≥3 (setting) | Unit DoT; explode **15 yd** of target | Soft: far adds counted but not in blast |
| Affliction | RainOfFire | ctx40 ≥3; `pos(8,35)` | 8 ground | Soft count; pos OK |
| Demo | Seed / RoF / Hellfire | ctx40 ≥3 / ≥3 / ≥4 | 15 det / 8 ground / **10 self** | Hellfire **clear** if not stacked on player |
| Destro | Seed / RoF / Hellfire via `aoe_matches` | action.enemy_count vs ctx40 | same | Hellfire self **clear** |
| Destro | Shadowfury | ctx40 ≥2 (or PvP) | 8 ground | Soft |
| Demo | HowlOfTerror | ctx40 ≥3 | 10 self | Soft–clear |

### Hunter

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| BM / MM / SV / Leveling | MultiShot | ctx40 ≥ multishot_mode (def 2) | Chain 3 near **target** | Soft: secondaries must be near target |
| BM / SV | Volley | ctx40 ≥ aoe_threshold / ≥4; `pos(8,35)` | 8 ground | Soft count; pos OK |
| SV | ExplosiveTrap / ImmolationTrap | ctx40 ≥3 / ≥2 | Trap 10 yd on trigger / single burn | Soft: trap at feet; pack may be ranged |
| Middleware | MultiShot gate | ctx40 ≥2 | chain near target | Soft |

### Paladin

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Protection | Consecration | ctx40 vs min_targets (def 3) | **8 yd under feet** | Soft–clear when tanking from range or spread pack |
| Retribution | Consecration | ctx40 ≥ min_targets (def 3) | 8 self | Soft–clear (melee ret usually OK) |
| Ret | HolyWrath | ctx40 ≥2 + undead/demon | short PBAoE filtered | Soft |
| Holy | ConsecrationSoloAoE | ctx40 ≥2 | 8 self | Soft |
| Leveling | Consecration | readiness-focused | 8 self | Soft |

### Priest

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Shadow | HolyNovaAoE | combat_mode aoe + ctx40 ≥3 | **10 yd self** | **Clear** when shadowing at 25–36yd |
| Shadow | multi-DoT | GetEnemies(multidot_range≈30) + filters | spell range | Better than pure ctx40 for DoTs |
| Smite | HolyNova | ctx40 ≥3 | 10 self | **Clear** at caster range |
| Disc / Holy | GetEnemies 8/10/20 | heal/threat | heal-centric | N/A damage inventory (noted) |

### Shaman

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Elemental | ChainLightning | target_count from ctx40 ≥ min (def 3) | chain near target | Soft |
| Elemental | FireNova / Magma totems | ctx40 ≥ aoe_threshold (def 4) | ~10 / 8 from **totem at feet** | Soft–clear if casters stand back |
| Enhancement | ChainLightning | mode + ctx40 | chain | Soft |
| Enhancement | Magma / Fire Nova weaving | fire totem logic + distance const **8** for Magma | 8 from totem | Better awareness for Magma distance; still uses global density for mode |
| Restoration | enemy_count gates | often ≥1 utility | N/A DPS | N/A |

### Rogue

| Spec | Strategy / spell | Count gate | Hit volume | Align? |
|------|------------------|-------------|------------|--------|
| Combat | BladeFlurry | target_count (ctx40) ≥ setting (default **1**) | Extra melee hit on nearby | Default 1 = intentional ST CD; multi at setting>1 still uses 40yd |
| Leveling | BladeFlurry | enemies ≥3 | melee nearby | Soft |

### Death Knight / WotLK / Vanilla

See dedicated sections below (full-repo coverage).

---

## Vanilla (`*_vanilla.lua`) inventory

Same **40yd** `context.enemy_count` pipeline. Spell radii for shared Classic ranks match TBC DBC rows (e.g. AE 1449 = 10yd, Blizzard 10 = 8yd, WW 1680 = 8yd).

| Class / file | AoE / multi strategies | Count gate | Hit volume | Align? |
|--------------|------------------------|------------|------------|--------|
| Mage fire/frost/leveling | AE, Flamestrike, Blizzard, CoC/FN | ctx40 ≥3–4 | AE 10 self; FS ~5; Bliz 8 ground (`pos(8,35)` on Bliz) | **Clear** AE; soft FS/Bliz |
| Warrior arms/fury/prot/kebab/leveling | WW, Cleave, TC, SS | ctx40 / target_count ≥2 | WW/TC 8 self; Cleave near target | Soft–clear |
| Druid balance/bear/leveling | Hurricane, Swipe | ctx40 ≥2–3 | 8 ground / melee | Soft |
| Hunter BM/MM/SV/leveling | Multi-Shot, Volley | ctx40 ≥2–4 | chain near target / 8 ground | Soft (SV Volley often **no** `get_aoe_cast_position`) |
| Paladin ret/prot/holy/leveling | Consecration, Holy Wrath | ctx40 ≥ min_targets | 8 feet | Soft–clear |
| Warlock destro | RoF, Hellfire | action.enemy_count vs ctx40 ≥4 | 8 ground / 10 self | Hellfire **clear** |
| Warlock aff/demo | curse mode uses ≥3 | ctx40 | SoC not always present pre-TBC | Soft |
| Shaman ele/enh/resto/leveling | CL, (totems where present) | ctx40 / target_count | chain / totem feet | Soft |
| Rogue combat/leveling | Blade Flurry | ctx40 / enemies ≥ | nearby melee | Soft |
| Priest shadow/smite/disc | multi-DoT / Holy Nova patterns | ctx40 or local 8–10 (disc) | 10 self / DoT range | Clear if Holy Nova on 40yd |
| Disc vanilla | `GetEnemiesCount(10)` / InRange(8) | **local** | ~10 | Aligned pattern |

**Vanilla-specific note:** Many files are ports of Sylvanas TBC logic; **same systemic 40yd-vs-hit-volume bug class** applies. Frost/Fire Blizzard still hardcodes `8, 35` where present.

---

## WotLK (`*_wotlk.lua` + Death Knight) inventory

All live WotLK specs copy `state.enemy_count = context.enemy_count` (40yd). Many WotLK trees are **stubs** that only store `enemy_count` without AoE strategies yet — still listed for completeness.

### WotLK spell geometry (ids not in TBC DBC → Community/WotLK)

| Spell | Example id | Cast / hit (Community/WotLK) | Notes |
|-------|------------|------------------------------|-------|
| Howling Blast | 49184 / 51411 | ~20 yd cast; damages target + enemies near target (~10 yd of target) | **Not in** 2.5.5 DBC |
| Death and Decay | 43265 / 49938 | Ground ~30; **~10 yd** circle | Base 43265 may appear in extract with radius 10; rank 49938 missing |
| Blood Boil | 48721 / 49941 | Self **~10 yd** | Not in TBC DBC |
| Pestilence | 50842 | Melee; spreads diseases **~10 yd** of target | Not in TBC DBC |
| Heart Strike | 55050 | Melee; cleaves extra target near primary | Chain-like |
| Fan of Knives | 51723 | Self **~8 yd** | Not in TBC DBC |
| Divine Storm | 53385 | Melee weapon AoE **~8 yd** | Not in TBC DBC |
| Hammer of the Righteous | 53595 | Melee + nearby | Not in TBC DBC |
| Mind Sear | 48045 | Channel on target; hits around target | **No** WotLK shadow strategy using it yet in inventory greps |
| Arcane Explosion / Blizzard ranks | 42921 / 42940 | Same geometry as TBC (10 self / 8 ground) | Rank ids missing from TBC DBC; geometry inherited |

### Death Knight

| Spec / file | Strategy | Count gate | Hit volume | Align? |
|-------------|----------|------------|------------|--------|
| frost_wotlk | HowlingBlast | Rime free **or** ctx40 ≥3 + FF | HB near-target AoE (Community/WotLK) | Soft–clear: 40yd density vs ~10yd of target |
| unholy_wotlk | DeathAndDecay | ctx40 ≥2 | Ground ~10 | Soft |
| unholy_wotlk | Pestilence | ctx40 ≥2 + disease refresh | Spread ~10 of target | Soft |
| leveling_wotlk | Pestilence / D&D / BloodBoil / HowlingBlast | ctx40 ≥2–3 | 10 self / 10 ground / HB | BB **clear** if gated only on 40yd while not stacked |
| blood_wotlk | Pestilence / HeartStrike | disease logic; HS filler | spread / cleave near target | Soft (HS not hard-gated on count) |

### WotLK non-DK (active AoE strategies)

| Spec / file | Strategy | Count gate | Hit volume | Align? |
|-------------|----------|------------|------------|--------|
| mage/leveling_wotlk | ArcaneExplosion | ctx40 ≥3 | 10 self | **Clear** |
| mage/leveling_wotlk | Blizzard | ctx40 ≥4 | 8 ground | Soft; **no** `get_aoe_cast_position` (cast_safe on target) |
| rogue/leveling_wotlk | FanOfKnives | ctx40 ≥3 | ~8 self | **Clear** if not melee-stacked |
| rogue/combat_wotlk | BladeFlurry | ctx40 ≥2 | nearby melee | Soft |
| paladin/retribution_wotlk | Consecration | ctx40 ≥2 | 8 feet | Soft |
| paladin/retribution_wotlk | DivineStorm | CD only (no min count) | ~8 self | Soft undercount risk if used ST intentionally |
| paladin/leveling_wotlk | DS / Consecration | ctx40 ≥2 | 8 | Soft |
| paladin/protection_wotlk | HotR / Consecration | readiness | melee / 8 feet | Soft |
| warrior/leveling_wotlk | Cleave / WW / TC | ctx40 ≥2 | melee / 8 self | Soft–clear |
| warrior/fury_wotlk | Whirlwind | (check matches) | 8 self | Soft |
| warrior/arms_wotlk | multi gates ≥2 | ctx40 | WW/cleave family | Soft |
| hunter/leveling_wotlk | MultiShot / Volley | ctx40 ≥2 / ≥3 | chain / 8 ground | Soft; no pos helper |
| warlock/leveling_wotlk | SoC / RoF | ctx40 ≥3 | 15 det / 8 ground | Soft; no pos helper on RoF |
| shaman/elemental_wotlk | ChainLightning | ctx40 ≥2 | chain | Soft |
| shaman/leveling_wotlk | Magma / CL | ctx40 ≥2–3 | totem 8 / chain | Soft |
| druid/bear_wotlk + leveling | Swipe | ctx40 ≥2 | melee | Soft |
| druid/balance_wotlk | (AoE gate ≥2 where present) | ctx40 | Hurricane/Starfall stubs | Soft / incomplete |
| Spec stubs (many fire/frost/aff/demo/etc. wotlk) | `enemy_count` stored only | N/A strategy | N/A | **N/A** — no damage AoE strategy yet; inventory notes field wired to 40yd for future |

---

## Mismatch / Risk list (consolidated)

Severity:

- **Clear** — rotation can select the spell because N enemies exist within 40yd while **few/none** sit in the spell’s hit volume (false multi-target).
- **Soft** — same pattern but mitigated by melee playstyle, stance/target requirements, high thresholds, or prediction helper; still wrong in spread packs / kiting.
- **Aligned** — count range ≈ hit volume, or local scan / prediction used, or spell is single-target with chain near target already in melee of primary.

| # | Severity | File | Strategy / function | Count range used | Spell | Correct hit range | Notes |
|---|----------|------|---------------------|------------------|-------|-------------------|-------|
| 1 | **Clear** | `mage/fire_sylvanas.lua` | `arcane_explosion_matches_fn` | ctx40 ≥3 | Arcane Explosion 27082 | 10 yd self | Classic false AoE while nuking at 30yd |
| 2 | **Clear** | `mage/frost_sylvanas.lua` | `arcane_explosion_matches` | ctx40 ≥3 | Arcane Explosion | 10 yd self | Same |
| 3 | **Clear** | `mage/fire_sylvanas.lua` | `blast_wave` / `dragons_breath` | ctx40 ≥2 | BW / DB | 10 yd self / cone | Can fire without being in melee cone |
| 4 | **Clear** | `warlock/demonology_sylvanas.lua` | `hellfire_matches` | ctx40 ≥4 | Hellfire | 10 yd self (effect 5857) | Channel while pack at range wastes HP |
| 5 | **Clear** | `warlock/destruction_sylvanas.lua` | `aoe_matches` Hellfire | ctx40 ≥4 | Hellfire | 10 yd self | Same |
| 6 | **Clear** | `priest/shadow_sylvanas.lua` | `holy_nova_aoe_matches` | ctx40 ≥3 + aoe mode | Holy Nova 25331 | 10 yd self | Shadow rarely stands in melee |
| 7 | **Clear** | `priest/smite_sylvanas.lua` | Holy Nova strategy | ctx40 ≥3 | Holy Nova | 10 yd self | Same class of bug |
| 8 | Soft–Clear | `warrior/*` Whirlwind / TC | ctx40 ≥2 | WW / TC | 8 yd self | Fine on stacked melee packs; bad on spread |
| 9 | Soft–Clear | `paladin/protection|retribution_sylvanas.lua` Consecration | ctx40 ≥ min_targets | Consecration | 8 yd feet | Melee usually OK; fails if kiting / ranged pulls |
| 10 | Soft | `druid/bear_sylvanas.lua` Swipe | ctx40 ≥2/3 | Swipe | Melee front ≤3 | Need mobs in front of bear |
| 11 | Soft | `druid/balance_sylvanas.lua` Hurricane | ctx40 ≥3 | Hurricane | 8 yd ground | No cluster check; cast on target only |
| 12 | Soft | `mage/*` Blizzard / Flamestrike | ctx40 ≥3–4 | Bliz 8 / FS **5** | Ground | Pos helper helps Blizzard; FS radius 5 vs any 8 assumption |
| 13 | Soft | `warlock/*` Seed / RoF | ctx40 ≥3 | SoC 15 det / RoF 8 | Unit/ground | RoF has `pos(8,35)`; Seed blast needs clump around **target** |
| 14 | Soft | `hunter/*` MultiShot | ctx40 ≥2 | Multi-Shot | chain near **target** | Far loose pack: MS hits 1 |
| 15 | Soft | `hunter/*` Volley / ExplosiveTrap | ctx40 ≥3–4 | Volley 8 / trap 10 | Ground / feet | Trap especially: at player feet |
| 16 | Soft | `shaman/elemental_sylvanas.lua` FireNova/Magma | ctx40 ≥4 | ~10 / 8 from totem | Soft if elemental stands 25yd+ from pack |
| 17 | Soft | `shaman/*` ChainLightning | ctx40 ≥ min | CL jumps | Soft if targets not near each other |
| 18 | Soft | Frost `cone_of_cold_matches` | primary ≤10 **or** ctx40≥2 | CoC cone 10 | Multi branch does not scan cone |
| 19 | Soft | `rogue/combat` BladeFlurry | ctx40 (default min 1) | nearby melee | Default intentional ST; multi setting still 40yd |
| 20 | Aligned control | Disc Holy Nova-ish local | `GetEnemiesCount(8)` / InRange(8) in middleware | Holy Nova ~10 | local ~8–10 | Good pattern for damage ports |
| 21 | Aligned control | Blizzard/Volley/RoF execute | `get_aoe_cast_position(..., 8, 35)` | 8 / ~30–35 cast | Matches DBC 8 | Still gated by ctx40 for *whether* to cast |
| 22 | Aligned control | Enhancement Magma distance | `TOTEM_CALL_MAGMA_DISTANCE = 8` | Magma 8 | Matches DBC | Mode still density-based |
| 23 | **Clear** | `mage/*_vanilla.lua` (fire/frost) | ArcaneExplosion | ctx40 ≥3 | AE 10 self (DBC 1449) | Same class as TBC Sylvanas |
| 24 | **Clear** | `warlock/destruction_vanilla.lua` | Hellfire aoe_matches | ctx40 ≥4 | 10 self | Same as TBC |
| 25 | **Clear** | `mage/leveling_wotlk.lua` | ArcaneExplosion | ctx40 ≥3 | 10 self (Community/WotLK rank; geometry=TBC) | Leveling false AoE at range |
| 26 | **Clear** | `rogue/leveling_wotlk.lua` | FanOfKnives | ctx40 ≥3 | ~8 self (Community/WotLK; **not in TBC DBC**) | FoK while not stacked |
| 27 | Soft–Clear | `deathknight/*_wotlk.lua` | BloodBoil / HowlingBlast / D&D | ctx40 ≥2–3 | ~10 self / near-target / ground (Community/WotLK) | 40yd density vs short DK AoE |
| 28 | Soft | `paladin/retribution_wotlk.lua` | Consecration | ctx40 ≥2 | 8 feet (DBC on TBC ranks; WotLK rank missing from extract) | Same as TBC ret |
| 29 | Soft | `hunter/*_vanilla.lua` Volley | ctx40 ≥3–4 | 8 ground | Often missing `get_aoe_cast_position` vs Sylvanas SV/BM |
| 30 | Soft | All `*_vanilla` / `*_wotlk` that only set `state.enemy_count = context.enemy_count` | future/existing gates | 40yd | Same systemic risk when strategies added |

---

## Cross-check (verification sample)

Recorded in `{SCRATCH}/aoe_range_crosscheck.txt`.

| Case | Category | Report claim | In-repo verification |
|------|----------|--------------|----------------------|
| Arcane Explosion 27082 / 1449 | Self PBAoE (TBC+Vanilla) | 10 yd | DBC radius 13 → 10.0; gates on `enemy_count` (40yd) in fire/frost sylvanas **and** vanilla |
| Blizzard 27085 | Ground circle | 8 yd / cast ~30 | DBC radius 14 → 8.0; code `get_aoe_cast_position(..., 8, 35)` on TBC/vanilla frost/fire |
| Cone of Cold 27087 | Cone / frontal | 10 yd cone | DBC radius 13 → 10.0; frost match `get_distance` ≤10 on primary |
| Chain Lightning 25442 | Chained jump | RI=4; chain 3 | DBC `EffectChainTargets=3`; gate `target_count`←ctx40 |
| Seed detonation 27285 | Explosion | 15 yd | DBC radius 18 → 15.0 |
| Howling Blast 51411 | WotLK PBAoE near target | Community/WotLK ~10 of target | **Absent from** wowsims.db 2.5.5 — stated, not invented as DBC |
| Fan of Knives 51723 | WotLK self AoE | Community/WotLK ~8 | **Absent from** DBC extract; leveling_wotlk gates ctx40 ≥3 |
| main throttled_enemies | Global density | 40 yd | `GetEnemiesInRange(40)` / `get_targets(40)` in main_sylvanas.lua |

**Absence of DBC radius:** Cleave / Multi-Shot / Blade Flurry secondaries use **chain counts**. All WotLK-only ids missing from the 2.5.5 extract are labeled **Community/WotLK**, never as DBC.

---

## Optional fix recommendations (not implemented)

1. **Local hit-volume counts** for self PBAoE: gate AE / Holy Nova / Hellfire / WW / TC / Consecration / Blast Wave on `GetEnemiesCount(hit_radius)` (8–10) instead of (or in addition to) ctx40.
2. **Target-centered counts** for Cleave / Multi-Shot / Seed: count enemies within ~8–15 yd of **current target**, not player 40yd.
3. **Keep ctx40** only for Auto-AoE playstyle switch and “many enemies in fight” heuristics; document that separation in comments/settings.
4. **Flamestrike**: use radius **5** in any prediction call (DBC), not 8.
5. **Hurricane**: use `get_aoe_cast_position(id, target, 8, 35)` like Blizzard.
6. **Cone of Cold multi**: replace ctx40 branch with enemies in front cone ≤10 (or `GetEnemiesInRange(10)` as lower bound).
7. **Structural test**: `tests/test_aoe_range_audit_contracts.lua` pins 40yd global + 8/35 ground helper call sites + high-severity PBAoE gates across expansions (this goal).

---

## Inventory completeness (high-signal grep)

Evidence: `{SCRATCH}/aoe_inventory_grep.txt`, `{SCRATCH}/aoe_inventory_wotlk_vanilla_grep.txt`.

| Signal | Coverage in report |
|--------|-------------------|
| `enemy_count` | Global + **all** `*_sylvanas` / `*_vanilla` / `*_wotlk` damage paths (121 wotlk lines, 130 vanilla lines grepped) |
| `GetEnemiesInRange` / `GetEnemiesCount` | Core, main, multi-DoT, heal local 8/10/20, middleware, disc vanilla |
| `get_aoe_cast_position` | Production call sites (TBC + vanilla Blizzard/RoF/Volley where present) |
| Whirlwind / Cleave / TC | Warrior sylvanas + vanilla + wotlk leveling/fury |
| Blizzard / AE / Flamestrike / CoC / DB / BW | Mage all expansions |
| Consecration / Divine Storm / HotR | Paladin all expansions |
| Swipe / Hurricane | Druid sylvanas + vanilla + wotlk bear/leveling |
| RoF / Hellfire / SoC / Shadowfury | Warlock all expansions |
| CL / Fire Nova / Magma | Shaman all expansions |
| Multi-Shot / Volley / traps | Hunter all expansions |
| Blade Flurry / Fan of Knives | Rogue combat + wotlk leveling FoK |
| Holy Nova | Priest Shadow / Smite (TBC/vanilla patterns) |
| Howling Blast / D&D / Blood Boil / Pestilence | Death Knight frost/unholy/blood/leveling |
| Mind Sear | **N/A damage path** — no strategy match found under `*_wotlk` greps (spell not wired) |
| Heal-only PoH / CoH / Chain Heal | **N/A** damage inventory |
| WotLK stubs (enemy_count only, no AoE strategy) | Explicitly marked **N/A** future-risk in WotLK section |

---

## Prior related work (not this problem)

| Plan | What it solved | Gap vs this audit |
|------|----------------|-------------------|
| `plans/_archive/range-verification-audit-2026-07-06.md` | Single-target cast range / OOR stall (`is_spell_in_range`, `evaluate_cast`) | Does not validate multi-target **count vs AoE radius** |
| `plans/_archive/targeted-skip-range-followup-2026-07-06.md` | Follow-up OOR / skip_range | Same |

---

## Summary

The dominant systemic issue is **one global 40-yard enemy density** (`main_sylvanas.lua` → `context.enemy_count`) reused across **TBC Sylvanas, Classic Vanilla, and WotLK** as the multi-target gate for spells whose real hit volumes are **~5–15 yards** (self, frontal, ground, or target-centered). Ground spells that call `get_aoe_cast_position(..., 8, 35)` place better once cast is chosen; many Vanilla/WotLK ports **omit** that helper and still gate on 40yd.

**Highest-severity false AoE risks (all expansions where present):** Arcane Explosion, Hellfire, Holy Nova, Blast Wave / Dragon’s Breath, WotLK Fan of Knives, DK Blood Boil (when gated only on density).

**High-frequency soft risks:** Whirlwind, Thunder Clap, Consecration, Divine Storm, Swipe, Multi-Shot, Seed, Howling Blast, Death and Decay, Volley without prediction.

**WotLK DBC gap:** wowsims.db is **2.5.5**; WotLK-only spell rows are missing — radii labeled **Community/WotLK**, not fabricated as DBC.

**Deliverable complete for full-repo analysis; no production rotation logic fixes applied.**
