# NEVER-Strategy Triage — SoD Era Close-Out (2026-08-14)

The Season-of-Discovery era (all 20 `_sod.lua` spec files — druid
balance/feral/restoration/tank, hunter dps_hunter, mage dps_mage, paladin
protection/retribution, priest healing/shadow, rogue combat/tank, shaman
elemental/enhancement/restoration/warden, warlock dps/tank, warrior
dps_warrior/tank_warrior) joined the behavioral battery. The initial honest
run surfaced **37 never-firing lanes**; this wave cleared **every** lane to
the era's terminal **0** — strict like WotLK, so any future never-lane is a
hard CI failure until pinned.

Companion docs: `never_strategy_triage_dps_2026-08-07.md` /
`never_strategy_triage_non_dps_2026-08-07.md` (original 304 → 100 triage),
`never_strategy_triage_tbc_2026-08-10.md` (TBC era, pinned at 16),
`never_strategy_triage_wotlk_2026-08-09.md` (WotLK era, pinned at 0),
`never_strategy_triage_vanilla_2026-08-13.md` (Vanilla era, pinned at 13).
The TBC (16), WotLK (0) and Vanilla (13) never counts were verified
**lane-for-lane unchanged** after every W4.3 change (diffed against the
pre-wave never lists: identical lane sets; the `_meta` mock-fidelity fix is
additive — flat `.ids` readers unchanged).

## How to reproduce

```bash
lua EaxRotations/tests/behavioral_audit.lua sod       # 20 specs, 0 never, 0 load failures
lua EaxRotations/tests/run_verify_all.lua             # pins "behavioral battery (sod)": 20/20, never == 0
```

## Pre/post never counts per category

| Metric | Initial run (2026-08-14) | Post-wave |
|---|---|---|
| Battery coverage | 0 / 20 specs | **20 / 20 specs** |
| Total never-firing lanes | 37 | **0** |
| (a) opt-in setting | — | **0** |
| (b) correctly-silent | — | **0** |
| (c) mock limitation | — | **0** |
| (d) dead | — | **0** |

The era is STRICT: with 0 never lanes there are no pins to classify. Every
one of the 170 strategies across the 20 files fires in at least one battery
scenario.

## Campaign mechanics

The W4.1 audit wave (production-side) had already found and fixed the
era's producer defects (committed `025f1195`): `NS.get_sod_runes` was
mock-only (rune-gated SoD actions dead in production), the
`define_sod_action_for_class` unwrap for rich class-table entries,
`ctx.injured_count` alias, LavaLash's mock-only `offhand_imbue` gate,
BerserkerRage stance normalization, and the weakened-soul/totem wiring in
`shared/sod_context_sylvanas.lua`. The W4.3 battery work built the era's
observability on top of those real producers. All changes are harness-side
except the spec_kit `_meta` unwrap already shipped in W4.2 — **zero
spec-file matcher edits** were needed for the 37 → 0 close-out.

1. **Manifest + era plumbing**: `M.SPEC_FILES_SOD` (all 20 files),
   `M.ERA_MANIFESTS.sod`, CLI/run_all era acceptance, `ns.is_sod` as an
   era-conditional callable (every `_sod.lua` guards its load with
   `type(NS.is_sod) == "function" and not NS.is_sod()`), SoD context
   defaults in `build_context_for` (`is_sod = true`, `sod_phase = 8` —
   the engine's `SOD_DEFAULT_PHASE`), and `sod_runes`/`sod_phase`
   whitelist keys (real engine fields, additive-safe: no other era's
   scenario uses those names). `check_manifest_drift` is maximal-strict
   for the sod era — **no** `non_spec` prefix exclusions, because
   `priest/healing_sod.lua` IS a spec (unlike the shared-module
   `healing_sylvanas.lua` the `healing_` exclusion exists for).

2. **The run-killer — mock spell_action `_meta` fidelity**: the battery's
   `ns.spell_action` emitted only a flat `.ids` field; the live engine's
   factory (core_sylvanas.lua:1361) emits `_meta.id/_meta.ids/_meta.label`.
   `spec_kit.define_sod_action_for_class`'s W4.2 unwrap resolves source ids
   via `_meta.ids`, so every class-table-backed SoD action (shaman
   FlameShock/LightningBolt/ChainLightning, druid/rogue/warrior fields)
   resolved nil in the battery and its lanes reported never-firing while
   firing fine in production — a 37-lane false positive cluster (warden
   9/10, shaman elemental 3/7, enhancement 5/10, rogue tank 2/7...).
   The mock factory now also emits `_meta` (additive — every flat-`.ids`
   reader keeps working), restoring live fidelity. This is the W3.4
   "mock-only members" doctrine applied to the mock's own object shape.

3. **The real sod_context enrich runs in the battery**: `run_spec`
   applies `M.apply_sod_enrich` (era == "sod") after the state bank, so
   the REAL `shared/sod_context_sylvanas.lua` enrich populates
   `in_cat_form`/`in_bear_form` (from `form`), `metamorphosis_active`
   (from `buff_remains_map`), `flame_shock_remains`/`serpent_sting_remains`/
   DoT remains (from `debuff_remains_map`), poison/sunder stacks (from the
   id-scoped stacks bank), `injured_count` (from `party_injured_count`),
   `fire/water_totem_active` (from the `get_totem_info` bank), and the
   heal-target fields (Riptide/Lifebloom/Weakened Soul on `ctx.lowest_unit`
   — mirrored from the friendly-target entry). `package.loaded` refresh per
   load_spec keeps each spec's enrich bound to its own mock NS.

4. **Scenario battery** (`M.SCENARIOS_SOD` = shared set + 14 SoD shapes):
   `sod_meta` (warlock-tank Metamorphosis superset: enemy 3 + target_hp 20
   + pet_hp 25 → ShadowCleave/DrainLife/HealthFunnel), `sod_bear_form`
   (bear form + Lacerate refresh window), `sod_poison` (deadly-poison
   stacks + energy/combo), `sod_flame_shock`, `sod_maelstrom` (stacks 5 +
   rockbiter + enemy 3), `sod_maelstrom_single` (warden single-target
   bolt), `sod_molten` (enemy 5 — the shared aoe caps at 4 — + rockbiter),
   `sod_berserker` (stance 3 + rage 20), `sod_tank_aoe` (defensive stance
   + 3 enemies), `sod_tank_rage_low` (defensive + rage 15), `sod_serpent`,
   `sod_sunder`, `sod_totem_heal`, `sod_weakened_soul`, and the
   `pet_dismissed` context state (OOC + no pet + NOT dead — the shared
   `no_pet` scenarios present a dead pet for RevivePet's lane, which
   blocked Call Pet's `not pet_dead` gate).

## Why 0 pins (and why that is safe)

Unlike TBC (16) and Vanilla (13), the SoD era's 20 files were written in
the current DSL-era style (2026 SoD specs): every strategy gates on real
engine/`sod_context` fields that the battery now produces through the real
producers, so there are no correctly-silent (b) lanes (no TBC-style
pre-pull conjure/mounted families), no mock-limitation (c) lanes (the
enrich + scenario battery can present every state the files read), and no
dead (d) lanes (W4.1/W4.2 eliminated the mock-only reads). The strict
`never == 0` pin makes any future regression fail loudly in CI.
