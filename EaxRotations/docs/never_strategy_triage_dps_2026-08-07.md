# NEVER-Strategy Triage — DPS Specs (2026-08-07)

Classification of the original **117 never-firing strategies** across the 13
DPS specs (mage ×3, warlock ×3, warrior ×4, rogue ×3), produced from the
behavioral battery (135 scenarios, 31 specs). Battery upgrades have since
unblocked **104** of them — current DPS never-firing:
**13** (all-spec **100**). "Never" means the strategy's `matches()` returned `true` in **zero** scenarios — it is either gated behind an opt-in
setting, only reachable in a live-game situation the battery cannot model, or
a genuine dead lane caused by a missing `build_state` assignment.

## Classification legend

| Tag | Meaning | Action |
|-----|---------|--------|
| **(a) opt-in setting** | Strategy is disabled by default (`setting` default `false`/`"none"`/`0`). Works in live play once the user enables it. | none (maybe surface in UI) |
| **(b) PvP / stealth / OOC-only** | Only reachable in a live situation the battery has no scenario for: threat, snare, `melee_on_you`, enemy caster flags, target classification, stealth-buff + PvP, group/ally state. Correctly silent in PvE. | none |
| **(c) battery limitation** | The battery mock/scenarios can't express the state: `spell_ready`/`spell_exists`/`is_spell_learned` always true, `debuff_stacks` hardwired 0, `hit_rating`/weapons not modeled, missing `WarriorConstants.BUFF_ID`, missing scenario *combinations* (e.g. burst + potions, defensive stance + low HP). Works in live play. | battery upgrade (recommendations below) |
| **(d) likely dead lane** | `build_state` never assigns a field the match reads, so the lane can never fire **in live play either**. | fix the spec |

**Original classification (117 DPS lanes):** (a) 31 · (b) 30 · (c) 51 ·
(d) 5 — the 5 (d) lanes are **FIXED** and 24 (c) lanes were unblocked by
battery upgrades (DamagePotion/poison/stance-distance/on_cd scenarios);
current DPS never-firing is **13** (all-spec **100**)

**Post-upgrade status (2026-08-07):** the battery upgrades below were applied;
never-firing across all 31 specs dropped **304 → 277** (27 lanes unblocked,
0 regressions). DPS specs: 113 → 93 (mage 21→20, warlock 33→31, warrior
36→24, rogue 23→18). All 27 were category (c) battery limitations; (c) now
holds 24 remaining entries. **Healer battery upgrades** (PLAYER_UNIT hp stub +
`mana_critical` scenario, `undead_target` scenario, and the three (d)
dead-lane fixes — healer section below) then dropped the all-spec total to
**254** (23 more lanes cleared/fixed, 0 regressions; non-DPS 184 → 161).
**Per-class `on_cd` scenarios** then dropped the all-spec total to **249**
(5 more lanes cleared, 0 regressions): DPS 93 → 88 (mage 20→18 — arcane +
frost `ColdSnap`; warrior 24→21 — prot `Devastate`/`Rend`/`HeroicStrike`).
**Heal-scan + affliction stubs** (healer section below) then dropped the
all-spec total to **224** (25 more lanes cleared, 0 regressions): non-DPS
161 → 136 (priest 28 · paladin 38 · druid 36 · shaman 19 · hunter 15).
**PreHeal/Preemptive `pushback` + `state.entries` fixes** then dropped the
all-spec total to **219** (5 more lanes cleared/fixed, 0 regressions):
non-DPS 136 → 131 (priest 24 · paladin 38 · druid 36 · shaman 18 · hunter
15) — the 3 `Preemptive*` lanes were reclassified (c)→(d) (specs never
stored `state.entries`, so they were dead in live play too).
**Heal-scan deficit fix** (ranked #1) then dropped the all-spec total to
**218** (1 more lane cleared, 0 regressions): non-DPS 131 → 130 (paladin
38 → 37 — holy `LightGraceBuild`). **Per-buff state scenario** (ranked #2)
then dropped the all-spec total to **217** (1 more lane cleared, 0
regressions): non-DPS 130 → 129 (paladin 37 → 36 — holy `LightGraceChain`
via the `lights_grace` scenario / `buff_remains_map`).
**`party_members` wiring** (ranked #3) then dropped the all-spec total to
**216** (1 more lane cleared, 0 regressions): non-DPS 129 → 128 (priest
24 → 23 — holy `MassDispel`). **Friend class-id scan** (ranked #4) then
dropped the all-spec total to **215** (1 more lane cleared, 0 regressions):
non-DPS 128 → 127 (druid 36 → 35 — resto `InnervateHealer` via
`friend_class = 11` + the `safe_field` (obj, key) fix).
**Seal-state scenarios** (ranked #5) then dropped the all-spec total to
**213** (2 lanes, 0 regressions). **`FsrManager` stub** (ranked #6) then
dropped it to **207** (5 lanes + 1 incidental, 0 regressions).
**Settings-modeling fixture** (ranked #7) then dropped it to **194**
(13 lanes, 0 regressions). **Multi-target DoT model** (ranked #1) then
dropped it to **183** (11 lanes — warlock ×5 + shadow ×4 shared + balance ×2
shared, 0 regressions). **Wand/AB-stack/BladeFlurry scenarios** (ranked
#3/#4/#5) then dropped it to **180** (3 lanes, 0 regressions). **Arcane
burn-phase model** (ranked #2) then dropped it to **176** (4 lanes, 0
regressions). **Defensive-casting scenario + target `is_casting_spell` mock**
(warrior/rogue focused triage, 2026-08-08) then dropped it to **133**
(6 lanes cleared, 0 regressions): prot `Pummel` + `SpellReflection` (prot
build_state derives `state.target_is_casting` from `target:is_casting_spell()`,
now wired — arms read ctx), arms `Disarm` + `SpellReflection` (is_pvp +
defensive-stance combo), combat/subtlety `Blind` (is_pvp + hp 15). **PvP-combo
scenarios** (pvp_stealth_opener `{ is_pvp, buff_remains_map [1784] }` +
pvp_gap_close `{ is_pvp, target_distance = 15 }`) then dropped it to **130**
(3 lanes cleared, 0 regressions): assassination `PvP_CheapShotOpen` +
`PvP_SprintGapClose`, plus druid/cat `Dash` (non-DPS bonus). **Opt-in (a)
fixture scenarios** (focused-triage follow-up) then dropped it to **125**
(5 lanes cleared, 0 regressions): fury `Overpower` + `SwingDesync`, kebab
`SunderMaintain`, assn `ColdBloodEnvenom` + `ThistleTea` — each previously
needed a setting flip AND battery state the default context can't express.
**Stat/weapon mocks** (focused-triage (c) cluster) then dropped it to **118**
(7 lanes cleared, 0 regressions): the `hit_rating` ctx key (hit_cap_deficit
scenario, rating 50 vs the 142 cap → deficit 92 > 30) cleared `HitCapPriority`
×6 — combat/arms/fury (the triage targets) + the identical shared-matcher
copies in hunter/BM, mage/fire, paladin/retri — and the `equipped_daggers`
mock (mutilate_daggers scenario; get_equipped_item_id returns dagger 776 for
both hands → has_daggers) cleared assn `Mutilate`. DPS 43 → 25.

---

## (d) — LIKELY DEAD LANES: ~~fix these first~~ **FIXED (2026-08-07)**

✅ **All five dead lanes are fixed.** `build_state` now assigns the missing
fields, verified by `test_mage_dead_lane_regression.lua` (registered in
`run_rotation_tests.lua`): direct state + matcher assertions for each lane
plus an end-to-end check that the battery no longer reports any of the five
as never-firing. Battery never-counts after the fix: fire 3 (Polymorph /
HitCapPriority / ManaGemConjure — all (b)/(c)), arcane 9, frost 6 (ColdSnap
now fires via `cold_snap_cd`) — no fixed lane remains. Rotation suite: 429/434 pass (5 pre-existing env/data
gaps, unchanged); leveling 31/31.

All five are the same bug class previously fixed for hunters (`hp_pct`) — the
match reads a state field that `build_state` never populates, so it silently
evaluates against the schema default forever.

| Spec | Strategy | Field never assigned | Evidence |
|------|----------|----------------------|----------|
| mage/fire | `Healthstone` | `hp_pct` | match: `(state.hp_pct or 100) > 28` → always 100; `build_state` sets `mana_pct` but **no** `hp_pct` |
| mage/fire | `IceBarrier` | `hp_pct` | DSL `state.hp_pct <= 60` → always fails |
| mage/fire | `ManaShield` | `hp_pct` | DSL `state.hp_pct <= 40` → always fails |
| mage/arcane | `Healthstone` | `healthstone_ready` | match: `(state.healthstone_ready or 0) > 0`; schema default 0, **never assigned** (unlike fire/frost which call `first_ready_item`) |
| mage/frost | `ManaGem` | `mana_gem_available` | match: `not s.mana_gem_available → false`; schema default `false`, **never assigned** (only `use_mana_gem()` calls the scanner) |

**Applied fixes** (mirror the hunter fix + sibling specs):

```lua
-- fire_sylvanas.lua build_state (after mana_pct):
fire_state.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100

-- arcane_sylvanas.lua build_state (cooldown-availability block, BEFORE the
-- emergency early-return so the field is set even in PHASE_EMERGENCY):
s.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)

-- frost_sylvanas.lua build_state (before safe_state return):
frost_state.mana_gem_available = first_ready_mana_gem() ~= nil
```

Note: frost/fire/arcane already compute the item id via `first_ready_item()` /
`first_ready_mana_gem()` in `execute` — only the state field was missing, so
the execute path is proven to work.

> **Battery side effect:** the frost fix flips `ManaGemConjure` (frost) to
> never-firing in the battery — the mock's `is_item_ready` always returns
> `true`, so a gem is always "available" and conjure is correctly suppressed.
> That is correct live behavior, **not** a new dead lane; do not re-triage it.

---

## (a) — OPT-IN SETTINGS (31)

| Spec | Strategy | Gate (default) |
|------|----------|----------------|
| mage/frost | `FireBlast` | `frost_use_fire_blast == true` (off) |
| mage/frost | `Scorch` | `frost_use_scorch == true` (off) |
| mage/frost | `ArcaneMissiles` | `frost_use_arcane_missiles == true` (off) |
| warlock/affliction | `CurseOfElements` | `select_curse` → auto→agony/doom; needs `warlock_curse_mode="elements"` or group assignment |
| warlock/affliction | `CurseOfRecklessness` | `select_curse` → mode="recklessness" |
| warlock/affliction | `CurseOfWeakness` | `select_curse` → mode="weakness" |
| warlock/demonology | `CurseOfElements` | same `select_curse` gate |
| warlock/demonology | `CurseOfRecklessness` | same |
| warlock/demonology | `CurseOfWeakness` | same |
| warlock/destruction | `CurseOfElements` | same |
| warlock/destruction | `CurseOfRecklessness` | same |
| warlock/destruction | `CurseOfWeakness` | same |
| warlock ×3 | `Healthstone` | shared helper: `healthstone_hp` default **0** → `threshold <= 0 → false` |
| warlock/destruction | `SummonFelguard` | `destro_pet_preference` auto→imp; Felguard only on explicit pref |
| warlock/destruction | `SummonFelhunter` | explicit pref only |
| warlock/destruction | `SummonSuccubus` | auto→imp (Incinerate "learned"); succubus only for shadow builds / explicit pref |
| warlock/destruction | `SummonVoidwalker` | explicit pref only |
| warrior/arms | `CommandingShout` | `use_commanding_shout` default **false** |
| warrior/arms | `SunderArmor` | `use_sunder_armor` default **false** |
| warrior/fury | `Overpower` | `fury_overpower_weave` default **false** |
| warrior/fury | `SunderArmor` | `sunder_mode` default **"off"** |
| warrior/fury | `SwingDesync` | `fury_swing_desync` default **false** |
| warrior/kebab | `SunderMaintain` | `sunder_armor_mode` default **"none"** |
| warrior/protection | `CommandingShout` | `use_commanding_shout` default **false** |
| rogue/assassination | `ThistleTea` | `assassin_thistle_tea` default **false** |
| rogue/assassination | `ColdBloodEnvenom` | `assassin_cold_blood_auto` default **false** |
| rogue/combat | `ExposeArmor` | `expose_assigned` (assignment setting) |
| rogue/subtlety | `ExposeArmor` | `subtlety_expose_assigned` default **false** |

---

## (b) — PvP / STEALTH / OOC / SITUATIONAL-CONTEXT ONLY (30)

Correctly silent in the battery because the triggering live state (threat,
snare, enemy-caster flags, elite classification, group members, stealth+pvp
openers) has no scenario — and is correct to never fire in ordinary PvE.

**Warlock (affliction)** — `CC_HowlOfTerror` (is_pvp + `melee_on_you`),
`PvP_CurseExhaustion` (is_pvp + `melee_on_you`), `PvP_CurseTongues` (is_pvp +
`enemy_caster`), `ShadowWard` (is_pvp + `enemy_shadow_caster`), `Soulshatter`
(`threat_pct >= 80` / `has_aggro`).

**Warlock (demonology)** — `ShadowWard`, `Soulshatter` (same gates).

**Mage** — `Blink` (arcane + frost): snare/root escape (`self_rooted_snared` /
snare debuff).

**Warrior** — arms `Disarm` + `SpellReflection` (pvp + defensive-stance
defensive lanes); protection `Taunt`/`TauntSecondary`/`MockingBlow`/
`ChallengingShout` (`target_classification >= 1` — battery targets are normal
mobs that already attack you, so taunt is correctly suppressed),
`Pummel` (interrupt: defensive stance + casting), `Intervene` (group + ally
below HP), `IntimidatingShout` (pvp/group + enemies).

**Rogue** — `VanishReopen`, `Feint`/`FeintAoE` (threat ≥ 90),
~~`PvP_CheapShotOpen`~~ (pvp stealth opener — cleared 2026-08-08 by the
`pvp_stealth_opener` scenario, `buff_remains_map [1784]` + is_pvp),
~~`PvP_SprintGapClose`~~ (gap-close — cleared 2026-08-08 by `pvp_gap_close`,
is_pvp + dist 15), ~~`Blind` ×2~~ (pvp CC — cleared 2026-08-08 via
`defensive_casting`; see the Correctly-silent table).

---

## (c) — BATTERY LIMITATIONS (46)

Works in live play; the battery cannot express the state. Root causes, with
the strategies they mask:

1. ~~**`burst` scenario lacks `has_potions`**~~ **APPLIED 2026-08-07** — burst
   now carries `has_potions = true`; all 9 `DamagePotion` lanes fire.
2. ~~**`spell_ready` always true**~~ **APPLIED 2026-08-07** — warrior
   `ACTION` ids now resolve (battery seeds `WarriorSpells.ShieldSlam`/
   `Revenge` with the real rank tables, mirroring `class_sylvanas.lua`)   and new per-class `on_cd` scenarios exist: `prot_filler_cd` (ShieldSlam 30356
   + Revenge 30357 on cd, defensive stance, rage 100) and `cold_snap_cd`
   (IceBlock 45438 on cd + hp 15). Cleared prot `Rend`, `Devastate`,
   `HeroicStrike` (gated `ss_ready == false and revenge_ready == false`) and
   arcane/frost `ColdSnap` (`not spell_ready(IceBlock)` branch). Note: the
   scenario keys use the **top-rank** ids (`ids[1]` = 30356/30357) — the
   low-rank 23922/6572 are never read by `cooldown_remains`.
3. **`spell_exists`/`is_spell_learned` always true** → low-level fallbacks
   never fire: arcane `FireballLeveling`/`FrostboltLeveling` (AB "exists"),
   frost `FrostArmor` (MageArmor "learned"), demonology `SummonImp` — all
   four cleared by the `low_level` scenario + not_learned mock (ranked #9)
   (Felguard "learned"). Destruction `SummonSuccubus` auto-pref biases to imp
   for the same reason.
4. ~~**`debuff_stacks` hardwired 0**~~ **APPLIED 2026-08-07** — scenario-driven
   `debuff_stacks`/`get_debuff_stacks` (id-scoped via `debuff_aura_ids`) +
   `poison_stacks` scenario: combat `Envenom` + assassination
   `EnvenomFinisher` now fire.
5. ~~**`hit_rating` / weapons never modeled**~~ **APPLIED 2026-08-08** —
   `ctx.hit_rating` (hit_cap_deficit scenario, rating 50) cleared
   `HitCapPriority` ×6 (combat/arms/fury + hunter/BM, mage/fire, paladin/retri
   shared-matcher copies); the `equipped_daggers` mock (get_equipped_item_id
   returns dagger 776 for both hands) cleared assassination `Mutilate`.
6. ~~**Scenario combinations missing**~~ **APPLIED 2026-08-07** —
   `me:get_distance`/`get_player_stance` now read `ctx`; scenarios added:
   `berserker_execute` (arms `Recklessness`), `defensive_low_self` (arms
   `ShieldWall`), `rage_capped` (prot `RageDumpSafetyNet`), `berserker_long`
   (fury `Recklessness` — TTD gate needs combat_time≥60, not execute),
   `berserker_aoe` (fury `BattleStance`), `target_melee` (mage `Slow`;
   FrostNova/ConeOfCold stay covered).
7. **`buffs_up` sets ALL buffs at once** → self-replacing CDs never fire:
   mage arcane `ArcanePower`/`PresenceOfMind`/`IcyVeins`/`ColdSnapIVReset`
   (phase/CD-window + AP-buff self-block), combat `BladeFlurry`
   (SnD-needed vs already-active self-block).
   *Fix:* split `buffs_up` into per-buff scenario flags.
8. ~~**Stealth buff never modeled for rogues**~~ **APPLIED 2026-08-07** —
   scenario-driven `stealth_helper` stub (the real module cached the
   first-loaded spec's NS → rogue stealth reads were stale/order-dependent)
   + `stealth_opener` scenario (`buff_remains_map [1784]` + casting target
   + `opener_preference = cheap_shot`); combat `Garrote` + subtlety
   `CheapShot` cleared.
9. ~~**`WarriorConstants` mock missing `BUFF_ID` / `StanceManager.should_switch`**~~
   **APPLIED 2026-08-07** — `BUFF_ID = { SWEEPING_STRIKES = 12328 }` seeded
   (kebab `SweepingStrikes` fires) and `StanceManager` gained
   `should_switch` + `get_optimal_stance` (prot `StanceSwitch` fires).
10. **Multi-target DoT spread not modelable** → affliction
    `CorruptionSpread`/`ImmolateSpread`/`SiphonLifeSpread`/
    `UnstableAfflictionSpread`/`CurseOfAgonySpread` (`find_dot_target` needs a
    second DoT'd unit via TSHelper DPS list); kebab `DemoShout`/`SweepingStrikes`
    partially (battery-fidelity quirk — see note).
11. **Misc context never set** → `Wand` (affliction; needs mana<30 AND hp below
    Life-Tap safety — no combo scenario), `ManaGemConjure` (fire + frost; gem
    always "available" in the mock — see (d) side-effect note), `Seduction`
    (succubus pet not modelable), arcane `Polymorph` + fire `Polymorph`
    (`cc_target` never set).

> **kebab `DemoShout`/`SweepingStrikes` note — RESOLVED 2026-08-07:**
> `SweepingStrikes` errored on `Constants.BUFF_ID.SWEEPING_STRIKES` (nil in
> the mock) — fixed by seeding `WarriorConstants.BUFF_ID`. `DemoShout` failed
> on `context.in_melee_range` — kebab's build_state derives it from
> `target:is_in_melee_range()`, which the battery target lacked; fixed by
> binding it to `ctx.target_distance <= 5`. Both now fire.

---

## Battery upgrades — APPLIED 2026-08-07 (304 → 277 never-firing, 27 unblocked)

| # | Upgrade | Result |
|---|---------|--------|
| 1 | `burst` scenario: `has_potions = true` | **9 `DamagePotion` lanes** fire (hunter ×3, warlock ×2, warrior ×4, paladin retribution, rogue subtlety/combat) |
| 2 | `_scenario_me`: bind `me:get_distance → ctx.target_distance`, `get_player_stance/get_stance → ctx.stance` | mage arcane `Slow` unblocked; `target_melee` scenario (dist 5 + enemy 3) added so FrostNova/ConeOfCold stay reachable |
| 3 | Seed `WarriorConstants.BUFF_ID = { SWEEPING_STRIKES = 12328 }` + `StanceManager.should_switch`/`get_optimal_stance` | kebab `SweepingStrikes` + prot `StanceSwitch` unblocked |
| 4 | Scenario-driven `debuff_stacks`/`get_debuff_stacks` (id-scoped via `debuff_aura_ids`) + `poison_stacks` scenario | combat `Envenom` (≥5 stacks) + assassination `EnvenomFinisher` (≥3) unblocked; id-scoping keeps mage AB/Winter's-Chill stacks at 0 |
| 6 | Scenario combinations: `berserker_execute`, `defensive_low_self`, `rage_capped`, `berserker_long`, `berserker_aoe`, `target_melee` | arms `Recklessness`/`ShieldWall`, fury `Recklessness`/`BattleStance`, prot `RageDumpSafetyNet` unblocked |
| 9 | `target:is_in_melee_range()` bound to `ctx.target_distance <= 5` | kebab `DemoShout` unblocked (kebab derives `context.in_melee_range` from the target) |
| 10 | Per-class `on_cd` scenarios + `WarriorSpells` seed (spell_action-shaped ShieldSlam/Revenge): `prot_filler_cd` (ShieldSlam 30356/Revenge 30357 on cd, defensive stance, rage 100), `cold_snap_cd` (IceBlock 45438 on cd + low HP) | prot `Devastate`/`Rend`/`HeroicStrike` + arcane/frost `ColdSnap` unblocked (5 lanes) |

### Still open (3 items, lower ROI)

5. `target_classification = 2` scenario → the four prot taunt lanes
   (`get_classification` is still 0 in the mock).
7. Split `buffs_up` into per-buff flags so "CD while buff absent" and "buff
   already active" are distinguishable (arcane AP/PoM/IV, combat BladeFlurry).
8. Rogue stealth-buff modeling for `CheapShot`/`Garrote`-style openers
   (`has_player_buff` keys only off `buffs_up`).

---

# Non-DPS / Healer Triage (2026-08-07) — 136 strategies

Same battery, same classification legend. The 18 non-DPS specs
(priest ×4, paladin ×3, shaman ×3, druid ×5, hunter ×3) hold **136
never-firing strategies** (final chain: 184 → 136 → **93** — after the
PLAYER_UNIT + `mana_critical` + `undead_target` battery upgrades, the
heal-scan/affliction stubs, and the (d) fixes):
priest 13, paladin 25, shaman 17, druid 29, hunter 9.

**Category counts (current, live battery 2026-08-08):** (a) 0 · (b) 35 · (c) 58 · (d) 0 (of 93) —
all (a) opt-ins and all (d) lanes are now CLEARED (final all-spec chain
304 → **100** = DPS 13 + non-DPS 87)
(original 184 = (a) 10 · (b) 36 · (c) 132 · (d) 6).

Healer-heavy specs skew (c): their lanes gate on `FriendlyTarget`,
heal-scan `lowest`/`tank` entries, prediction/overheal modules, and
affliction flags — none of which the battery models. A large (b) bucket is
expectable: Fade / TremorTotem / TurnEvil / HolyWrath / snare-roots /
OOC-buff lanes are correctly silent against a normal PvE target.

## (d) — LIKELY DEAD LANES (6: 3 original + 3 reclassified) — ✅ ALL FIXED (2026-08-07)

Same bug class as the mage/hunter fixes: the match reads a state field
`build_state` never populates, so it evaluates against the schema default
forever. Two were live-play dead; the third was hardcoded dead code. All
three are fixed and pinned by `test_healer_dead_lane_regression.lua`
(registered in `run_rotation_tests.lua`); battery 257 → 254 all-spec.

Three more lanes were reclassified (c)→(d) in the PreHeal/Preemptive turn
(2026-08-07): `PreemptiveHeal.match` reads `state.entries`/`state.count`,
which disc/holy/resto `build_state` never stored (druid/resto +
paladin/holy already do) — dead in live play too. Fixed by storing the heal
scan on state; pinned by `tests/test_preemptive_lane_regression.lua`
(see the non-DPS report for details).

| Spec | Strategy | Root cause | Evidence | Live-dead? |
|------|----------|-----------|----------|------------|
| priest/holy | `ManaPotion` | `state.mana_pct` **never assigned** in `holy_sylvanas.lua` build_state | probe: ctx.mana_pct=10 (low_mana) but `state.mana_pct=100` (schema default wins); gate `state.mana_pct or context.mana_pct` → 100 → `100 < 20` false. Sibling specs (smite line 169, discipline line 333) all assign it | ✅ **FIXED** — `holy_state.mana_pct` assigned (mirrors discipline) |
| druid/resto | `Healthstone` | `state.healthstone_ready` **never assigned** in `resto_sylvanas.lua` build_state | gate `(state.healthstone_ready or 0) > 0`; schema has no default so it stays `nil` → `(nil or 0) > 0` false. `first_ready_item(HEALTHSTONE_IDS)` exists (used in execute) but is never wired into state. Probe: low_self → `healthstone_ready=nil` while `ctx.hp=15` reads fine (not a battery artifact) | ✅ **FIXED** — `resto_state.healthstone_ready` via `first_ready_item` |
| hunter/marksmanship | `BestialWrath` | `bestial_wrath_matches` is hardcoded `return false` (line 480) | not DSL-substituted (not in MM's DSL_DEFS); execute still casts on pet. Bestial Wrath is a Beast-Mastery-tree talent, so a stub here is semi-intentional — but hardcoding `false` instead of gating on `spell_exists(ACTION.BestialWrath)` makes the lane dead even for mixed builds | ✅ **FIXED** — gates on `NS.spell_exists(ACTION.BestialWrath)` |

**Applied fixes** (same pattern as the mage fix; pinned by
`tests/test_healer_dead_lane_regression.lua`, registered in
`run_rotation_tests.lua`):

```lua
-- priest/holy_sylvanas.lua build_state (with the other resource reads):
holy_state.mana_pct = context.mana_pct or (player and NS.mana_pct and NS.mana_pct(player)) or 100

-- druid/resto_sylvanas.lua build_state (near resto_state.mana_pct):
resto_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0

-- hunter/marksmanship_sylvanas.lua (replace hardcoded false):
local function bestial_wrath_matches(context, s)
    return spell_exists(ACTION.BestialWrath)
end
```

> **New (d) finding — destruction pet summons (2026-08-07): ✅ FIXED (ranked
> #10)** — the warlock focused-triage turn found **3 more dead lanes** the
> original pass misclassified as (a): `SummonFelguard`/`SummonFelhunter`/
> `SummonVoidwalker` in `destruction_sylvanas.lua`. `summon_pet_matches`
> honored the `destro_pet_preference` only for `SummonImp`/`SummonSuccubus`;
> the other three fell through to the unconditional `return false` despite
> the comment claiming "only if explicitly preferred". Live symptom: a user
> who sets `destro_pet_preference = "felguard"` got **no pet at all** (even
> the auto-Imp was suppressed). **FIXED** by adding the three missing pref
> branches + three OOC no-pet battery scenarios (`destro_pet_felhunter` /
> `destro_pet_voidwalker` / `destro_pet_felguard`); all 3 lanes cleared
> (destro 8 → 5, 0 regressions, auto-Imp path verified intact). Pinned by
> `tests/test_destro_pet_pref_regression.lua`.

## Notable (c) battery gaps specific to healers

1. ~~**`NS.PLAYER_UNIT = {}` empty-stub clobber**~~ **APPLIED 2026-08-07** —
   smite line 140 and holy line 265 both do `context.hp = health_pct(NS.PLAYER_UNIT)`.
   `PLAYER_UNIT` now carries a `get_health_percentage` that reads the state
   bank (→ `ctx.hp`), so the low_self override survives: holy
   `Healthstone`/`DesperatePrayer`/`BindingHeal` + smite
   `Healthstone`/`SoloPowerWordShield` fire (5 of the ~6 lanes; `SoloRenew`
   still gated on other state).
2. ~~**Heal-scan + prediction modules not mocked**~~ **APPLIED 2026-08-07**
   — the per-class `Healing` modules now expose a state-bank-driven
   `scan_healing_targets` (entries from `friends_hp`, tank = entry[2], player
   self-entry), real `NS.healing_*` rankers, `select_heal`/`get_cleanse_target`/
   `all_members_above_hp`, and `group_*`/`tank_low`/`mana_tide_window`
   scenarios — cleared 17 heal-scan lanes (holy CoH/Lightwell/RenewTank, disc
   BH/GH/PoH/EmergencyPWS, paladin DivineFavorHolyShockCombo, druid
   Swiftmend/Tranq/NS/NSHealingTouch/LeaveTree, shaman ChainHeal/SmartHeal/
   Bloodlust/NaturesSwiftness). `PreHeal`/`Preemptive*` then cleared via the
   `pushback` scenario (`GetEnemiesInRange` stub → `_check_pushback` true) +
   `state.entries`/`count` stored in disc/holy/resto build_state (a live-play
   (d) fix — never assigned, so `PreemptiveHeal.match` could not fire
   in-game either).
3. ~~**`FSRPause` (×5 specs)**~~ **APPLIED 2026-08-07** — scenario-driven
   `FsrManager` stub + `fsr_pause` scenario (ranked #6); all 5 lanes cleared.
4. ~~**Affliction flags**~~ **APPLIED 2026-08-07** — per-debuff-type
   `afflicted` table (poison/disease/curse/magic) drives entry flags +
   `Healing.has_disease/has_poison/has_curse/has_magic/`
   `has_dangerous_dispel`; `friends_afflicted` now carries all four types.
   holy `CureDisease`/`AbolishDisease`/`DispelMagic`, shaman
   `CureDisease`/`CurePoison`/`DiseaseCleansingTotem`/`PoisonCleansingTotem`,
   paladin `PurifySelf` clear (8 lanes). `MassDispel` then cleared via the
   `party_members` wiring (ranked #3). (`RemoveCurse` cleared via the
   `auto_dispel` opt-in fixture, ranked #7.)
5. ~~**`ManaEmergencyWand` (×3 shaman) + holy `ManaBelow5Wand`**~~ **APPLIED
   2026-08-07** — new `mana_critical` scenario sets `mana_pct = 4` (the
   gates are strict `< 5`, so 5 would NOT have tripped elemental/restoration/
   holy; enhancement's floor is 10). All 4 wand lanes fire, plus hunter
   `AspectOfTheViper` ×2 (correct low-mana Viper switch).
6. **Multi-target DoT spread** — shadow `MultiDot*`/`*Spread`/`SWPSpread`,
   balance `InsectSwarmSpread`/`MoonfireSpread` need ≥2 debuffable targets
   (battery `enemies` list is empty; `debuff_stacks` is id-scoped to poisons).
7. **`is_behind` hardwired true** — cat `MangleFiller` is always pre-empted
   by Shred (correct live when behind, but the battery can't test the filler
   lane); `RipTrick`/`ShredTrick` are (a) opt-in settings.
8. ~~**Creature-type scenarios missing**~~ **APPLIED 2026-08-07** — new
   `undead_target` scenario (`target_creature_type = 6`, enemy_count 2):
   `ShackleUndead` ×4, `TurnEvil` ×2, prot `Exorcism`/`HolyWrath`, ret
   `Ret_HolyWrath_AoE` fire (9 lanes). Correction: undead is creature-type
   **6**, not classification 3 (3 is DEMON); retribution `Exorcism` is
   opt-in (`use_exorcism` default false) and later cleared via that opt-in
   in this scenario (ranked #7).
   `JudgementOfLightBoss`/`JudgementOfWisdomBoss` still need a boss flag.
9. **`spell_ready` always true** — kills leveling fallbacks
   (`InCombatAimedShot`, `ClawFallback` — the mock says Mangle is always
   learned, so the fallback correctly never fires; live it exists for low
   levels), and `Readiness` (needs `rapid_fire_cd >= 60` — the mock reports 0).
10. **AoE helper absent for bear** — `Swipe` calls `NS.aoe_target_meets`
    which is `nil` for druid (the real `aoe_hit_volume` module doesn't
    install), so the AoE gate short-circuits. `HurricaneAoE`/`Volley`/
    `Consecration` similar. (`Volley`/`ExplosiveTrap` later cleared via the
    `use_volley`/`use_explosive_trap` opt-ins + 4-enemy `hunter_toggles`
    scenario, ranked #7.)

## Per-spec notes (heaviest clusters — historical snapshot, superseded)

> Snapshot from the seal-state round. Current authoritative counts: all-spec
> **145** (DPS 48, non-DPS 97) — see Status above and the non-DPS report's
> per-spec classification tables (updated through ranked items #1/#2/#3/#4/#5/#7).

- **priest (28)**: holy 10 — 6 heal-scan/affliction lanes cleared
  (CoH/Lightwell/RenewTank + AbolishDisease/CureDisease/DispelMagic);
  PreHeal/Preemptive/Clearcasting/Surge (c), Fade·EncounterReactions·
  MountedProtection (b). discipline 5 — BH/GH/PoH/EmergencyPWS/PainSuppression/
  PWSTank cleared (heal-scan + `tank_low`); PreHeal/Preemptive (c), Fade (b).
  shadow 8 — ShackleUndead cleared (`undead_target`); multi-DoT spread (c) /
  Fade·SWDCCBreak (b). smite 5 — Healthstone + SoloPowerWordShield +
  ShackleUndead cleared; SoloRenew/InnerFocus/SoloPsychicScream (c),
  DevouringPlague/Starshards (b).
- **paladin (36)**: retribution 16 — TurnEvil + Ret_HolyWrath_AoE cleared
  (`undead_target`); SealTwistBlood + SealTwistPrepCommand cleared
  (seal-state scenarios); 5 (b) OOC-buff/snare, rest (c)
  seal-state/AoE/hit-rating. protection 8 — Exorcism + HolyWrath + TurnEvil
  cleared (`undead_target`); ally-buff (b) + seal-state (c) remain. holy 12 —
  PurifySelf + DivineFavorHolyShockCombo cleared (affliction + `group_emergency`);
  LightGrace buff-chain / FSRPause / FriendlyTarget (c), snare+ally-protect (b).
- **druid (36)**: resto 9 — `Healthstone` (d) **fixed**; SwiftmendEmergency /
  TranquilityEmergency / NaturesSwiftness / NSHealingTouch / LeaveTree cleared
  (heal-scan); Lifebloom/FSR (c), melee-pressure/PvP (b).
  cat 10 — 2 (a) trick settings, 2 (b) OOC, 6 (c) mock (is_behind / unlearned
  fallback / snapshots). bear 8 — taunts/pulls (b) + AoE helper (c). balance 9
  — PvP CC (b) + multi-DoT (c).
- **shaman (19)**: restoration 6 — ChainHeal/SmartHeal/Bloodlust/ManaTide/
  NaturesSwiftness + 4 cleanse/totem lanes cleared (heal-scan + affliction);
  PreemptiveChainHeal/ChainLightning/LightningShield (c), TremorTotem (b).
  enhancement 7 — twist setting (a) + totem/CC (c), TremorTotem (b);
  ManaEmergencyWand cleared. elemental 6 — moving shocks (c), TremorTotem (b);
  ManaEmergencyWand cleared.
- **hunter (15)**: BM 9 — AdaptiveRotation (a), threat-drop (b), trap/AoE/
  debuff (c). MM 3 — (d) `BestialWrath` **fixed** (spell_exists gate);
  Readiness/AimedShot (c); AspectOfTheViper cleared. Survival 3 — Readiness /
  SerpentStingRefresh (c); AspectOfTheViper cleared.

## Highest-ROI battery upgrades (healer set)

1. ✅ **APPLIED** — `NS.PLAYER_UNIT` gains `get_health_percentage` → `ctx.hp`
   (state bank). Cleared holy `Healthstone`/`DesperatePrayer`/`BindingHeal` +
   smite `Healthstone`/`SoloPowerWordShield` (5 lanes; `SoloRenew` still gated).
2. ✅ **APPLIED** — `mana_critical` scenario (`mana_pct = 4` — strict `< 5`
   gates). Cleared `ManaEmergencyWand` ×3 + holy `ManaBelow5Wand` + hunter
   `AspectOfTheViper` ×2.
3. ✅ **APPLIED** — state-bank heal-scan stub (`scan_healing_targets` from
   `friends_hp`, tank = entry[2], player self-entry, real `NS.healing_*`
   rankers) + `group_*`/`tank_low`/`mana_tide_window`/`group_emergency`
   scenarios. Cleared 17 heal-scan lanes: holy CoH/Lightwell/RenewTank, disc
   BH/GH/PoH/EmergencyPWS, paladin DivineFavorHolyShockCombo, druid
   Swiftmend/Tranq/NS/NSHealingTouch/LeaveTree, shaman ChainHeal/SmartHeal/
   Bloodlust/NaturesSwiftness (+8 affliction lanes, item 5 = 25 total; the 3
   stub-regressions disc PainSuppression/PWSTank + shaman ManaTideTotem were
   restored via `tank_low`/`mana_tide_window`, net 0).
4. ✅ **APPLIED** — `undead_target` scenario (`target_creature_type = 6`,
   enemy_count 2). Cleared `ShackleUndead` ×4, `TurnEvil` ×2, prot
   `Exorcism` + `HolyWrath`, ret `Ret_HolyWrath_AoE` (9 lanes).
5. ✅ **APPLIED** — per-debuff-type `afflicted` flags (poison/disease/curse/
   magic) → entry flags + `Healing.has_disease/has_poison/has_curse`/
   `has_dangerous_dispel`; `friends_afflicted` carries all four types. Cleared
   holy CureDisease/AbolishDisease/DispelMagic, shaman CureDisease/CurePoison/
   both cleansing totems, paladin PurifySelf (8 lanes).
6. `is_behind` scenario toggle → cat `MangleFiller`/`ShredFiller` lanes.

## Focused follow-up triage — DPS (c)/(b) next-up (2026-08-07)

Re-verified every named lane from the open lists against the live battery
(37 DPS never-firing — mage 10 · warlock 6 · rogue 8 · warrior 13, 115
scenarios; ranked #1/#2/#3/#4/#5 since applied, see Status). Every blocker below was re-derived from the live matchers and
confirmed by direct matcher probes (load the real spec, build the scenario
context, evaluate the strategy). **Corrections first:** frost
`FireBlast`/`Scorch`/`ArcaneMissiles` are **(a) opt-in**, not (c) — with
`frost_use_fire_blast`/`_scorch`/`_arcane_missiles = true` all three match in
the standard scenario (probe-verified). **`ManaGemConjure` (fire + frost) is
the documented (d)-side-effect, correctly suppressed** — the mock's
`is_item_ready` always returns true, so a gem is always "available"; do not
re-triage it. **Warlock `Wand` needs only a scenario combo** (mana < 30 AND
hp < 35 — Life-Tap-unsafe), not a new mock: `{ mana_pct = 4, hp = 15 }`
matches, `{ hp = 100 }` correctly stays blocked (probe-verified). **The
arcane CD cluster is ONE root cause, not four**: the battery
`_me_unit.get_max_power` returns **100**, so `s.max_mana = 100` →
`mtte_burn ≈ 0.3 < 5` → `should_conserve` is always true → `phase` can never
become `"burn"` (probe showed `phase = conserve` while `can_burn = true`), and
every AP/PoM/IV/ColdSnapIVReset gate requires burn or a CD window.

### Deserve a battery scenario (ranked in Status below)

| Lane | Specs | Blocker (probe-verified) | Class |
|------|-------|--------------------------|-------|
| ~~`CorruptionSpread`/`ImmolateSpread`/`SiphonLifeSpread`/`UnstableAfflictionSpread`/`CurseOfAgonySpread`~~ ✅ CLEARED | warlock/affliction | **APPLIED (ranked #1)** — `TSHelper.get_dps_targets` stub (bank-backed → `ctx.enemies`) + unit-aware `debuff_up`/`debuff_remains` (`debuff_remains_map` marks the primary dotted, peers clean) + `multidot` scenario (ttd 30 → auto-agony); all 5 **MATCH** | (c)→fixed |
| ~~`MultiDotSWP`/`MultiDotVT`/`SWPSpread`/`VTSpread`~~ ✅ CLEARED | priest/shadow (shared with non-DPS report) | **APPLIED (ranked #1)** — same TSHelper stub + `shadow_multidot` (`mode=2`, 2 enemies) / `shadow_cleave` (`cleave`, 3 enemies) scenarios via the settings fixture; all 4 **MATCH**. Note: SWPSpread/VTSpread ALSO fire in `target_melee` — shadow's `combat_mode` AUTO-DETECTS cleave at 3+ enemies (realistic, not a leak) | (a) opt-in + (c)→fixed |
| ~~`ArcanePower`/`PresenceOfMind`/`IcyVeins`/`ColdSnapIVReset`~~ ✅ CLEARED | mage/arcane | **APPLIED (ranked #2)** — battery `_scenario_me.get_max_power` bank-driven (15000 default; was 100 → `mtte_burn = 0.3 < 5` → phase never "burn") + `burn_ready` (player_mana 45000, ttd 60, `on_cd[12042]` → AP/PoM/IV **MATCH**) + `burn_coldsnap` (+ `on_cd[12472]` → ColdSnapIVReset **MATCH**). All 4 **MATCH**, 0 regressions | (c)→fixed |
| ~~`FrostboltConserve`~~ ✅ CLEARED | mage/arcane | **APPLIED (ranked #4)** — `ab_stack_conserve` scenario: `buffs_up` + `debuff_stacks 4` + AB aura ids {36032, 36033, 36034}; phase conserve + ab_stacks 4 + ab_remains 20 > cast_time: **MATCH** | (c)→fixed |
| ~~`Wand`~~ ✅ CLEARED | warlock/affliction | **APPLIED (ranked #3)** — `wand_low_mana` scenario combines mana < 30 + hp < 35 (Life-Tap-unsafe) + in_combat: `{ mana_pct = 4, hp = 15 }` **MATCH**; hp 100 correctly stays blocked | (c)→fixed |
| ~~`BladeFlurry`~~ ✅ CLEARED | rogue/combat | **APPLIED (ranked #5)** — `ns.buff_up` map-aware (reads `buff_remains_map` first, mirror `has_player_buff`) + `battle_ready` scenario (SnD {6774, 5171} = 20 up, 3 enemies): `has_snd = true`, `has_blade_flurry = false` **MATCH** | (c)→fixed |
| ~~`Taunt`/`TauntSecondary`~~ ✅ CLEARED | warrior/protection | `elite_target`/`elite_taunt_cd` scenarios (ranked #6-7): classification 1 + un-tanked target (`target_get_target = false`) + visible-enemies threat scan + `on_cd { [355] = 6 }`; Taunt fires ONLY in elite_target, TauntSecondary ONLY in elite_taunt_cd | (c→fired) |
| ~~`CheapShot`/`Garrote`~~ ✅ CLEARED | rogue/subtlety+combat | `stealth_opener` scenario (ranked #7): stealth map `[1784]` + casting target + `opener_preference = cheap_shot`; combat `Garrote` + subtlety `CheapShot` fire ONLY there (probe + exclusivity-verified) | (c→fired) |
| ~~`Preparation`~~ ✅ CLEARED | rogue/subtlety | `prep_ready` scenario (ranked #8): hp 15 ≤ 40 + Vanish on CD (`on_cd { [1856] = 60 }`; `get_spell_cd` now bank-aware → `vanish_cd > 0`); fires ONLY in prep_ready | (c→fired) |
| ~~`FireballLeveling`/`FrostboltLeveling`/`FrostArmor`/`SummonImp`~~ ✅ CLEARED | arcane ×2, frost, demo | `low_level` scenario (ranked #9): level 20 + OOC + no pet + `not_learned` map (ArcaneBlast 30451, MageArmor 27125/6117, SummonFelguard 30146) → `spell_exists`/`is_spell_learned` mock scenario-aware; each lane fires ONLY in low_level | (c→fired) |

### Correctly silent (no scenario worth building)

| Lane | Specs | Reason |
|------|-------|--------|
| `Polymorph` | arcane, fire | `cc_target` never set — (b) PvP CC |
| `Blink` | arcane, frost | needs `self_rooted_snared` / snare debuff — (b) snare escape |
| `ManaGemConjure` | fire, frost | (d)-side-effect — correctly suppressed (gem always available); do not re-triage |
| ~~`HitCapPriority` ×6~~ ✅ **CLEARED (2026-08-08)** | fire, arms, fury, combat, hunter/BM, retri | `hit_rating` ctx key (hit_cap_deficit) — 142 cap − 50 rating = 92 deficit > 30 gate |
| ~~`Mutilate`~~ ✅ **CLEARED (2026-08-08)** | rogue/assn | `equipped_daggers` mock (mutilate_daggers) — dagger 776 in both hands → has_daggers |
| ~~`Feint`/`FeintAoE`~~ ✅ **CLEARED (2026-08-08)** | combat, assn | threat reduction — fires via `threat_high` (`threat_pct 95` + has_aggro); rogue now 0 never-firing |
| ~~`Blind`~~ ✅ **CLEARED (2026-08-08)** | combat, subtlety | CC — fires via `defensive_casting` (is_pvp + hp 15) / `pvp_low_hp` |
| ~~`Soulshatter`~~ ✅ **CLEARED (ranked #12)** | affl, demo | threat dump — (b)→**observable**: `threat_high` scenario (`threat_pct 95` + `has_aggro`) fires it; probe-verified exclusive to threat_high |
| ~~`ShadowWard`~~ ✅ **CLEARED (2026-08-08)** | affl, demo | PvP defensive vs shadow casters — `shadow_caster` scenario (is_pvp + `target_class` 9 + hp 50) reuses the pvp_disarm `get_class` mechanism; fires ONLY there (exclusivity-pinned) |
| `Seduction` | demo | succubus pet + PvP CC — (b) (needs `pet_type_succubus` state + `is_pvp`) |
| `CC_HowlOfTerror` + `PvP_CurseExhaustion`/`PvP_CurseTongues` | affl | PvP CC/curse — (b) (probe: all three fire with `is_pvp`+`melee_on_you`+`enemy_caster`) |
| ~~`CurseOfElements`/`Recklessness`/`Weakness`~~ ✅ **CLEARED (ranked #11)** | ×9 warlock | `select_curse`/`warlock_curse_mode` opt-ins — (a) → **observable** via `curse_mode_*` scenarios (each fires ONLY in its own mode; pinned) |
| ~~`Healthstone`~~ ✅ **CLEARED (ranked #11)** | affl, demo, destro | `healthstone_hp` default 0 — (a) → **observable** via `low_self_healthstone` (fires only there; pinned) |
| ~~`SummonSuccubus`~~ ✅ **CLEARED** | destro | pet-preference opt-in — (a) → **observable** via `destro_pet_succubus` scenario (final (a) fixture); fires only there (probe-verified) |
| ~~`SummonImp`~~ ✅ CLEARED | demo | `low_level` scenario (ranked #9) — OOC + no pet + `not_learned` marks 30146 unlearned (Imp 688 still learned); fires ONLY in low_level | (c→fired) |
| ~~`SummonFelguard`/`Felhunter`/`Voidwalker`~~ ✅ **FIXED (ranked #10)** | destro | **was (d) DEAD CODE** (originally mislabeled (a)) — `summon_pet_matches` returned `false` unconditionally for these three even with the pref set; **fixed** by adding the 3 pref branches + OOC no-pet scenarios, pinned in `test_destro_pet_pref_regression.lua` |
| ~~`CommandingShout` ×2, `SunderArmor` ×4~~ ✅ **CLEARED (2026-08-08)** | warrior | opt-in toggles — (a) → **observable** via `arms_sunder`/`fury_sunder`/`commanding_shout`/`expose_armor` scenarios (all 6 fire exclusively; pinned) |
| ~~`Overpower`, `SwingDesync`, kebab `SunderMaintain`~~ ✅ **CLEARED (2026-08-08)** | warrior | fixture scenarios + supporting state — see focused triage |
| ~~`ColdBloodEnvenom`, `ThistleTea`~~ ✅ **CLEARED (2026-08-08)** | assn | fixture scenarios + supporting state — see focused triage |
| ~~`ExposeArmor`~~ ✅ **CLEARED (2026-08-08)** | combat, subtlety | assignment settings — (a) → **observable** via `expose_armor` scenario (both fire exclusively; pinned) |
| ~~`Disarm` (arms)~~ ✅ **CLEARED (2026-08-08)** · `Disarm` (prot) | warrior | arms: PvP + defensive stance — fires via `defensive_casting`; prot: (b) `requires_pvp` + `disarm_pvp_only` + mock `get_class` |
| ~~`SpellReflection` (arms)~~ ✅ **CLEARED (2026-08-08)** | warrior/arms | is_pvp + casting + defensive stance — fires via `defensive_casting` |
| ~~`SpellReflection` (prot)~~ ✅ **CLEARED (2026-08-08)** | warrior/prot | `is_casting_spell` mock + `defensive_casting` scenario — see focused triage |
| ~~`Intervene`~~ ✅ **CLEARED (2026-08-08)** | warrior/prot | PvP-by-default + group/ally-low — `group_ally_low` scenario + matcher truncation fix, see close-out triage |
| ~~`Blind`~~ ✅ **CLEARED (2026-08-08)** | combat, subtlety | PvP/group CC — (b); `defensive_casting` supplies is_pvp + hp 15 |
| ~~`PvP_CheapShotOpen`~~ ✅ **CLEARED (2026-08-08)** | assn | `pvp_stealth_opener` scenario — buff_remains_map {1784} feeds `has_player_buff(STEALTH_BUFF)` → stealth_active + is_pvp |
| ~~`PvP_SprintGapClose`~~ ✅ **CLEARED (2026-08-08)** | assn | `pvp_gap_close` scenario — is_pvp + target_distance 15 ≥ 15 |

### Focused follow-up triage — warlock (2026-08-07)

Re-verified every one of the **25** warlock never-firing lanes (affliction 9 ·
demonology 8 · destruction 8 — the 5 spreads + `Wand` cleared in earlier
turns) against the live battery with direct matcher probes. **Corrections
first:** the original pass classified the destro pet summons as **(a)**
opt-ins — **that was wrong for three of them**. `summon_pet_matches`
(destruction_sylvanas.lua:393) only returns from the pref for `SummonImp`
and `SummonSuccubus`; `SummonFelhunter`/`SummonVoidwalker`/`SummonFelguard`
fall through to the unconditional `return false` at line 414 — despite the
comment claiming "only if explicitly preferred (not in auto mode)". That
makes them **(d) dead code**, and it has a live symptom beyond the battery:
`destro_pet_preference = "felguard"` suppresses **all four** summons (the
pref short-circuit kills even the auto-Imp), so a Felguard user gets NO pet.

| Lane | Spec | Class | Probe evidence |
|------|------|-------|---------------|
| ~~`CurseOfElements`/`CurseOfRecklessness`/`CurseOfWeakness` (×3 each)~~ ✅ **CLEARED (ranked #11)** | affl, demo, destro | **(a)→observable** — `curse_mode_elements`/`recklessness`/`weakness` scenarios (setting_overrides `warlock_curse_mode`); all 9 fire, each ONLY in its own mode scenario (probe-verified) |
| ~~`Healthstone` (×3)~~ ✅ **CLEARED (ranked #11)** | affl, demo, destro | **(a)→observable** — `low_self_healthstone` scenario (`hp 25` + `healthstone_hp 40`); all 3 fire, only there (probe-verified) |
| ~~`SummonSuccubus`~~ ✅ **CLEARED** | destro | **(a)→observable** — `destro_pet_succubus` scenario (final (a) fixture); fires only there (probe-verified). **Warlock is now fully clean (affl 4 · demo 3 · destro 0)** |
| `CC_HowlOfTerror` | affl | **(b)** PvP/group CC | fires with `is_pvp`+`melee_on_you` (probe); needs `is_pvp` or (group_aware + is_group) |
| `PvP_CurseExhaustion` | affl | **(b)** PvP kite | fires with `is_pvp`+`melee_on_you` (probe) |
| `PvP_CurseTongues` | affl | **(b)** PvP | fires with `is_pvp`+`enemy_caster` (probe) |
| ~~`ShadowWard`~~ ✅ **CLEARED (2026-08-08)** | affl, demo | **(b)→fired** | needs `is_pvp`/group + shadow-caster class + hp ≤ 70 — `shadow_caster` scenario (is_pvp + `target_class` 9 + hp 50) clears both; fires ONLY there |
| ~~`Soulshatter`~~ ✅ **CLEARED (ranked #12)** | affl, demo | **(b)→observable** — `threat_high` scenario (`threat_pct 95`, `threat_status 3`, `has_aggro`): fires ONLY in threat_high (probe-verified). The same scenario also cleared priest `Fade` ×3 + rogue `Feint` ×2 + assn `VanishReopen`/`FeintAoE` (same threat-drop family, realistic — see non-DPS report) |
| `Seduction` | demo | **(b)** PvP CC | needs succubus pet state + `is_pvp` (probe: `pet_type_succubus` state always false in battery) |
| ~~`SummonImp`~~ ✅ CLEARED | demo | `low_level` scenario (ranked #9) — OOC + no pet + 30146 unlearned via the not_learned mock; fires ONLY there | (c→fired) |
| ~~`SummonFelguard`~~ ✅ **FIXED (ranked #10)** | destro | **(d)→fixed** — 3 pref branches added to `summon_pet_matches`; fires only in `destro_pet_felguard` (probe-verified exclusive) |
| ~~`SummonFelhunter`~~ ✅ **FIXED (ranked #10)** | destro | **(d)→fixed** — fires only in `destro_pet_felhunter` (exclusive) |
| ~~`SummonVoidwalker`~~ ✅ **FIXED (ranked #10)** | destro | **(d)→fixed** — fires only in `destro_pet_voidwalker` (exclusive) |

**Buckets: (a) 13 · (b) 8 · (c) 1 · (d) 3 = 25 — all three (d) lanes now
FIXED (ranked #10, warlock 25 → 22).** No other lane is (a)-misclassified:
every (a) lane above is a genuine user-facing setting that the fixture can
model (see ranked #11 below), and the (b)/(c) lanes are correctly silent
against a normal PvE target or are mock/OOC limitations.

### Focused follow-up triage — warrior/rogue (2026-08-08)

Re-verified all **27** remaining warrior (17) + rogue (10) never-firing lanes
against the live battery (all-spec 140 / DPS 43, 114 scenarios at triage
time — now 133 / 37 / 115 after the defensive-casting upgrade below) with direct
matcher probes: load the real spec, build each scenario context, evaluate the
strategy, plus a state-field dump of protection `build_state` across 10
scenarios (every `*_ready` flag is `true` — the blockers are metadata guards
and unit-mock gaps, not readiness). **Zero (d) dead lanes — no spec fixes
needed in this pass.**

**Corrections to prior classifications:** protection `SunderArmor` is **(c)**
(Devastate-ready gate), **not** (a) — `use_sunder_armor` is the ARMS gate
(prot `sunder_matches_fn` has no setting; the removed (a) row above was wrong).
Protection `SpellReflection` is **(b)+(c)**: the ACTIONS table marks it
`requires_pvp = true` AND prot `build_state` derives `target_is_casting` from
`target:is_casting_spell()` (protection:310), which the `_target` mock lacks
(it only has `is_casting` → false). Arms reads `ctx.target_is_casting` —
that's why arms/fury `Pummel` fire in `berserker_interrupt` but prot `Pummel`
cannot. `Intervene`/`Pummel`/`IntimidatingShout`/`ChallengingShout`/
`MockingBlow` also carry ACTIONS metadata (`requires_pvp`/`min_enemies`)
that the raw matcher text alone doesn't show.

| Lane | Spec | Class | Probe evidence |
|------|------|-------|---------------|
| ~~`CommandingShout`~~ ✅ **CLEARED** | arms, prot | **(a)→fired** | `commanding_shout` scenario — `use_commanding_shout` merged into ctx.settings; arms matcher + prot DSL `{ type = "setting" }` branch both read it (prot:601); fires ONLY there (exclusivity-pinned) |
| ~~`SunderArmor`~~ ✅ **CLEARED** | arms, fury | **(a)→fired** | arms `arms_sunder` scenario (`use_sunder_armor` + stance 2 — build_action requires DEFENSIVE); fury `fury_sunder` (`sunder_mode "maintain"`); fires ONLY in their scenario (exclusivity-pinned) |
| ~~`SunderMaintain`~~ ✅ **CLEARED** | kebab | **(a)→fired** | `kebab_sunder` scenario — `sunder_armor_mode "maintain"` merged into ctx.settings (kebab reads it DIRECTLY via settings_for) + stance 2 (matcher requires DEFENSIVE); fires ONLY there (exclusivity-pinned) |
| ~~`SunderArmor`~~ (prot) ✅ **CLEARED (2026-08-08)** | **(c)→fired** | gate `state.dev_ready` (Devastate always "ready") → never. Live: pre-Devastate fallback. **Not (a)** — `use_sunder_armor` is the arms gate. **Correction: the `not_learned` fix WON'T work** — `not_learned` only feeds `spell_exists`/`is_spell_learned`, NOT `spell_ready` (cooldown only). **APPLIED:** the REAL blocker was the missing `WarriorSpells.Devastate` seed (audit:793) — without it `define("Devastate")` fell back to `spell_action(nil)` → empty ids → `cooldown_remains` couldn't resolve an on_cd key. Seeded ids {30022,30016,20243} (class:171) + `sunder_fallback` scenario ({ stance 2, rage 100, on_cd { [30022]=6, [30356]=6, [30357]=5 } }) → dev_ready/ss_ready/revenge_ready false → filler branch fires |
| ~~`Disarm` (arms)~~ ✅ **CLEARED** · `Disarm` (prot) | arms, prot | **(b)** PvP-only, mock gap | arms:646: is_pvp + melee/player target + defensive stance — cleared via `defensive_casting` (fires ONLY there). prot: `requires_pvp` (ACTIONS:961) + `disarm_pvp_only` true + `disarm_trigger` "on_burst" (needs `disarm_burst_name`). **Close-out probe (2026-08-08):** `is_player` is PvP-driven (audit:1640 → true in defensive_casting ✓), but `disarm_class_ok` (prot:358 `pcall(target:get_class())`) stays **false everywhere — the target mock lacks `get_class`** (probe: 7 scenarios all `disarm_ok=false`; `Disarm@defensive_casting match=false`). Fix: add `target:get_class()` (melee id → `DISARM_CLASS_IDS` {1,2,4,7}, prot:163) + `enemy_buffed` (OffensiveDispelDB stub returns `(target, 10, "Bloodlust")` → burst name) → `{ is_pvp = true, enemy_buffed = true }` scenario |
| `Intervene` | prot | **(b)** PvP-by-default, mock gap | matcher (prot:754-770): `intervene_ready` true ✓, `in_combat` true ✓, rage 70 ≥ 10 ✓ — but **`is_group` false in every scenario** (ctx default) and **`lowest_allied`/`tank` nil** (party scan gated on is_group; `get_party_members` stub returns {}), plus `warrior_intervene_pvp_only` → needs is_pvp. **Close-out probe:** `lowest=nil tank=nil is_group=false` across all 7 scenarios. Fix (biggest): `is_group` ctx key + friend mock gains `get_position` (me already has it, audit:95) + `effective_hp 30` → `lowest_allied` wiring + `{ is_group = true, is_pvp = true }` scenario (ally ≤ 60 threshold, range fine) |
| ~~`IntimidatingShout`~~ ✅ **CLEARED** | prot | **(c)→fired** | `elite_low_self` scenario ({ target_classification = 1, hp = 15, enemy_count = 3 }) — base guard min_enemies 3 (protection:505, s.enemy_count = ctx.enemy_count) + matcher hp ≤ 50 (protection:825, s.hp = ctx.hp); fires ONLY there (exclusivity-pinned; enemies-only and hp-only scenarios both block) |
| ~~`Pummel`~~ ✅ **CLEARED** | prot | **(c)→fixed** | `is_casting_spell` wired in build_scenario_target + `defensive_casting` scenario → fires in all casting scenarios (probe: fires(8) incl. defensive_casting); pinned |
| ~~`SpellReflection`~~ ✅ **CLEARED** | arms | **(b)→fired** | is_pvp + casting + defensive-stance build_action — fires ONLY in `defensive_casting` (only is_pvp + stance-2 scenario); exclusivity-pinned |
| ~~`SpellReflection`~~ ✅ **CLEARED** | prot | **(b)+(c)→fired** | `is_casting_spell` mock + `defensive_casting` (is_pvp satisfies the ACTIONS `requires_pvp` guard) → fires in the is_pvp casting scenarios; pinned |
| ~~`Blind`~~ ✅ **CLEARED** | combat, subtlety | **(b)→fired** | `defensive_casting` supplies the `{ is_pvp = true, hp = 15 }` combo — both fire ONLY there (exclusivity-pinned) |
| ~~`ExposeArmor`~~ ✅ **CLEARED** | combat, subtlety | **(a)→fired** | `expose_armor` scenario — `combat_expose_assigned`/`subtlety_expose_assigned` merged into ctx.settings (combat:340; subtlety:518); combat `expose_armor_ready` true + subtlety combo 5 ≥ 4 / ttd 60 ≥ 20 gates pass; fires ONLY there (exclusivity-pinned) |
| ~~`HitCapPriority`~~ ✅ **CLEARED** | combat, arms, fury | **(c)→fired** | `hit_cap_deficit` scenario — `ctx.hit_rating = 50` vs the 142 cap → deficit 92 > 30; fires ONLY there (exclusivity-pinned) |
| ~~`Mutilate`~~ ✅ **CLEARED** | assn | **(c)→fired** | `mutilate_daggers` scenario — `equipped_daggers` makes get_equipped_item_id return dagger 776 for MAIN_HAND/OFF_HAND → `state.has_daggers` true (assn:234-240); fires ONLY there (exclusivity-pinned) |
| ~~`PvP_CheapShotOpen`~~ ✅ **CLEARED** | assn | **(b)→fired** | `pvp_stealth_opener` scenario ({ is_pvp, buff_remains_map [1784] = 10 } — the map-aware `has_player_buff(STEALTH_BUFF)`/`buff_up` reads the 1784 entry; `stealth_active` flips true) → fires ONLY there (exclusivity-pinned) |
| ~~`PvP_SprintGapClose`~~ ✅ **CLEARED** | assn | **(b)→fired** | `pvp_gap_close` scenario ({ is_pvp, target_distance = 15 }) → fires ONLY there; gap_close (dist 15, not pvp) and pvp (is_pvp, dist 5) both block it (exclusivity-pinned) |

**Buckets (27 lanes at triage): (a) 7 · (b) 9 · (c) 7 · (d) 0 — no dead
lanes.** **APPLIED 2026-08-08 (defensive-casting upgrade): 6 lanes cleared**
(prot Pummel + SpellReflection, arms Disarm + SpellReflection, Blind ×2) —
warrior 17 → 13, rogue 10 → 8, DPS 43 → 37, all-spec 140 → 133, 0
regressions. **APPLIED 2026-08-08 (pvp-combo upgrade): 2 DPS lanes cleared**
(assassination `PvP_CheapShotOpen` + `PvP_SprintGapClose` via the
`pvp_stealth_opener`/`pvp_gap_close` scenarios; druid/cat `Dash` cleared in
the non-DPS report as a same-gate bonus) — rogue 8 → 6, DPS 37 → 35,
all-spec 133 → 130, 0 regressions. **APPLIED 2026-08-08 (opt-in fixture
scenarios): 5 lanes cleared** — fury `Overpower` (`fury_overpower`,
setting + BT/WW on_cd), fury `SwingDesync` (`fury_swing_desync`,
setting + swing_until 2.0 ≥ 1.6 window), kebab `SunderMaintain`
(`kebab_sunder`, mode maintain + stance 2), assn `ColdBloodEnvenom`
(`cold_blood`, auto setting + SnD map + poison stacks) + `ThistleTea`
(`thistle_tea`, setting + low energy/combo) — fury 4 → 2, kebab 1 → 0,
assassination 3 → 1, DPS 35 → 30, all-spec 130 → 125, 0 regressions.
**APPLIED 2026-08-08 (stat/weapon mocks): 7 lanes cleared** — the
`hit_rating` ctx key (`hit_cap_deficit`, rating 50 vs the 142 cap) cleared
`HitCapPriority` ×6 (combat/arms/fury + hunter/BM, mage/fire, paladin/retri
shared-matcher copies) and the `equipped_daggers` mock (`mutilate_daggers`)
cleared assn `Mutilate` — combat 2 → 1, arms 3 → 2, fury 2 → 1,
assassination 1 → 0, hunter/BM 6 → 5, mage/fire 3 → 2, retri 9 → 8,
DPS 30 → 25, all-spec 125 → 118, 0 regressions.
**APPLIED 2026-08-08 (opt-in close-out): 6 lanes cleared** — the final (a)
lane family. 4 scenario pins via the settings fixture: `arms_sunder`
(`use_sunder_armor` + stance 2 — its build_action requires DEFENSIVE),
`fury_sunder` (`sunder_mode "maintain"`), `commanding_shout`
(`use_commanding_shout` — arms + prot, DSL setting branch), and
`expose_armor` (`combat_expose_assigned`/`subtlety_expose_assigned`) —
arms 3 → 2, fury 2 → 1, prot 5 → 4, combat 1 → 0, subtlety 1 → 0;
arms/fury/combat/subtlety now at **0 never-firing**.
DPS 25 → 19, all-spec 118 → 112, 0 regressions.
**APPLIED 2026-08-08 (last (c) item): 1 lane cleared** — the
`elite_low_self` combo scenario ({ target_classification = 1, hp = 15,
enemy_count = 3, enemies_count = 3 }) — prot IntimidatingShout needs
min_enemies 3 AND hp ≤ 50; elite_target had the enemies but hp 100,
low_self had hp 15 but 1 enemy — fires ONLY there. prot 4 → 3,
DPS 19 → 18, all-spec 112 → 111, 0 regressions.
Remaining **0 DPS lanes — the close-out list is exhausted** (all 117 original lanes are now either observable or correctly silent).
The triage's (c) `HitCapPriority` ×3, `Mutilate`, `IntimidatingShout`, prot `Disarm`, prot `Intervene`,
and prot `SunderArmor` are all cleared.
**Close-out triage (2026-08-08): all three probed with live matcher evidence — ranked #1-#3 ALL APPLIED.**

## Status

All planned upgrades + (d) fixes are applied. Non-DPS never-firing is
down to **87** (all-spec **100**; DPS **13**). **Close-out triage
(2026-08-08)**: the last 3 DPS lanes (prot `Disarm` (b), `Intervene` (b),
`SunderArmor` (c)) probed with live matcher evidence — **the probe claimed
zero (d) dead lanes and then immediately found ONE: the Intervene matcher's
`local dx, dy = me.get_position and me:get_position()` truncates the
multi-value return to a single value (dy/ay always nil → the range gate
always failed) — dead even against the real API, reclassified (b)→(d)**.
**Ranked #2 (prot Disarm) APPLIED 2026-08-08**: `target:get_class()` mock +
`pvp_disarm` scenario — 111 → 110, prot 3 → 2, 0 regressions.
**Ranked #3 (prot Intervene) APPLIED 2026-08-08**: `is_group` +
`party_low_ally`/`friend_hp` ctx keys, me/friend `get_position` multi-value
mocks, `group_ally_low` scenario, AND the matcher truncation fix — 110 →
109, prot 2 → 1, 0 regressions.
**Ranked #1 (prot SunderArmor) APPLIED 2026-08-08**: the real blocker was
NOT a mock-gate but a missing `WarriorSpells.Devastate` seed — without it
the spec's `define("Devastate")` fell back to `spell_action(nil)` → empty
ids → `cooldown_remains` could never resolve an on_cd key → `dev_ready`
true in every scenario (the `not_learned` map can't help: it only gates
`spell_exists`/`is_spell_learned`, not the cooldown-only `spell_ready`).
Seeded Devastate ids {30022,30016,20243} + added the `sunder_fallback`
scenario (Devastate + ShieldSlam + Revenge on CD) — 109 → 108, prot 1 → 0,
0 regressions, Devastate itself unpinned (still fires in prot_filler_cd +
cd_pressure). The 6 (a) gates re-verified green.
**Fidelity note:** in the real game this lane is the *unlearned* Devastate
fallback (low-level warriors); the battery models it via on-CD because the
`spell_ready` mock is cooldown-only. The `leveling`/`low_level` scenarios
could express the true unlearned case if prot's `dev_ready` ever consulted
`spell_exists`/`is_spell_learned` — a future-fidelity option, not needed
for observability.
Focused follow-up triage of
the remaining healer (c)/(b) lanes is in the non-DPS report, and the DPS
(c)/(b) lanes are in the **Focused follow-up triage — DPS** section above
(probe-verified classifications; the DPS ranked list follows the healer
items here); the healer-ranked next-up list (items 1-7 APPLIED):

1. ~~**Fix the heal-scan `deficit` bug**~~ **APPLIED 2026-08-07** —
   `LightGraceBuild` cleared (219 → 218, 0 regressions).
2. ~~**Per-buff state scenario**~~ **APPLIED 2026-08-07** — `buff_remains_map`
   override + `lights_grace` scenario; `LightGraceChain` cleared (218 → 217,
   0 regressions). Generalizes to clearcasting/Surge/InnerFocus/Lifebloom
   lanes.
3. ~~**`party_members` wiring**~~ **APPLIED 2026-08-07** — holy `MassDispel`
   cleared (217 → 216, 0 regressions).
4. ~~**Friend class-id scan**~~ **APPLIED 2026-08-07** — druid/resto
   `InnervateHealer` cleared (216 → 215, 0 regressions).
5. ~~**Seal-state scenario**~~ **APPLIED 2026-08-07** —
   `setting_overrides` drives the scenario-aware `get_any_setting` stub
   (`can_twist` on only in-scenario), plus `seal_twist_blood` (Command 27170,
   swing 0.4) / `seal_twist_prep` (Blood 31892, swing 0.9, Judgement 20271 on
   CD) scenarios → `SealTwistBlood`, `SealTwistPrepCommand` cleared
   (215 → 213, 0 regressions; each fires ONLY in its own scenario). Pinned by
   `tests/test_seal_twist_lane_regression.lua`. (`Ret_SealCommand_Primary`
   later cleared via the `seal_preference = "command"` fixture, ranked #7.)
6. ~~**`FsrManager` stub**~~ **APPLIED 2026-08-07** — scenario-driven
   stub for `shared/fsr_manager_sylvanas` + `fsr_pause` scenario →
   `FSRPause` ×5 cleared (213 → 207, 0 regressions; each fires ONLY in
   `fsr_pause`) + retri `Ret_JudgementWisdom_LowMana` (incidental). Also
   fixed `ns.get_setting` (scenario-aware) + added `ns.buff_stacks`. Pinned
   by `tests/test_fsr_lane_regression.lua`.
7. ~~**Settings modeling**~~ **APPLIED 2026-08-07** — `setting_overrides`
   merges into `ctx.settings` (one fixture covering direct reads,
   `spec_kit.setting`, and DSL setting conditions), plus `context.enemies`
   and truthy matcher-dispatch fixes → 13 opt-in lanes observable
   (`RemoveCurse` ×2, `BlessingOfKings` ×2, AdaptiveRotation ×3,
   ExplosiveTrap, Volley, Exorcism, `Ret_HotC_Opener_Judge`,
   `Ret_JudgeSecondary_CommandCleave`, `Ret_SealCommand_Primary`;
   207 → 194, 0 regressions). Pinned by
   `tests/test_settings_fixture_lane_regression.lua`.

### Ranked next-up — DPS specs (from the focused triage above)

1. ~~**Multi-target DoT spread model**~~ **APPLIED 2026-08-07** — preloaded
   a `shared/ts_helper_sylvanas` stub whose `get_dps_targets` returns
   `ctx.enemies` + per-target `debuff_remains_map` (unit-aware
   `debuff_up`/`debuff_remains`: primary dotted, peers undotted) +
   `multidot`/`shadow_multidot`/`shadow_cleave` scenarios. Cleared **11
   lanes** (9 DPS-shared, all probe-verified MATCH): affliction
   `CorruptionSpread`/`ImmolateSpread`/`SiphonLifeSpread`/
   `UnstableAfflictionSpread`/`CurseOfAgonySpread` (ttd 30 → auto-agony) +
   shadow `MultiDotSWP`/`MultiDotVT` (`shadow_multidot_mode = 2`) +
   `SWPSpread`/`VTSpread` (`shadow_combat_mode = "cleave"`, enemy_count 3)
   + balance `InsectSwarmSpread`/`MoonfireSpread` (shared with non-DPS).
2. ~~**Arcane burn-phase model**~~ **APPLIED 2026-08-07** —
   `_scenario_me.get_max_power` bank-driven (15000 default via `max_mana`;
   was 100 → `mtte_burn = 0.3 < 5` → phase never "burn") + `burn_ready`
   scenario (player_mana 45000, ttd 60, `on_cd[12042] = 180`) +
   `burn_coldsnap` (+ `on_cd[12472] = 180`). Cleared **4 lanes**
   `ArcanePower`/`PresenceOfMind`/`IcyVeins`/`ColdSnapIVReset` (MATCH;
   all pinned by `tests/test_arcane_burn_regression.lua`).
3. ~~**`Wand` combo scenario**~~ **APPLIED 2026-08-07** — `wand_low_mana`
   (`mana_pct = 4, hp = 15`, in_combat). Cleared **1 lane**
   (`Wand`; probe-verified MATCH).
4. ~~**`FrostboltConserve` AB-stack scenario**~~ **APPLIED 2026-08-07** —
   `buffs_up` + `debuff_stacks 4` + AB aura ids {36032, 36033, 36034}
   (`ab_stack_conserve`). Cleared **1 lane** (`FrostboltConserve`;
   probe-verified MATCH).
5. ~~**Per-buff `buff_up` map-awareness**~~ **APPLIED 2026-08-07** —
   `ns.buff_up` reads `buff_remains_map` first (mirror `has_player_buff`) →
   `battle_ready` scenario (SnD {6774, 5171} up, 3 enemies). Cleared **1
   lane** (`BladeFlurry`; probe-verified MATCH) and generalizes to future
   self-block lanes.
6. ~~**`target_classification` scenario**~~ **APPLIED 2026-08-07** —
   `target_classification`/`target_get_target` passthrough + `elite_target` /
   `elite_taunt_cd` scenarios (classification 1, un-tanked target,
   `visible_enemies` for the threat scan, `on_cd { [355] = 6 }`;
   WarriorSpells.Taunt seeded). Cleared **4 lanes** — `Taunt`,
   `TauntSecondary`, plus bonus `MockingBlow` + `ChallengingShout` (same
   elite gates); pinned by `tests/test_opener_elite_regression.lua`.
7. ~~**Stealth-opener combo**~~ **APPLIED 2026-08-07** — scenario-driven
   `stealth_helper` stub (killed the stale first-loaded-NS capture) +
   `stealth_opener` scenario (stealth map `[1784]` + casting target +
   `opener_preference = cheap_shot`). Cleared **2 lanes** — combat
   `Garrote`, subtlety `CheapShot` (each fires ONLY in stealth_opener).
8. ~~**`Preparation` combo**~~ **APPLIED 2026-08-07** — `prep_ready`
   scenario (hp 15 + `on_cd { [1856] = 60 }`) + `get_spell_cd` made
   bank-aware (scans all rank ids; only subtlety consumes it). Cleared **1
   lane** (`Preparation`; fires ONLY in prep_ready). Pinned in
   `tests/test_opener_elite_regression.lua`.
9. ~~**`spell_exists` blocklist**~~ **APPLIED 2026-08-07** — `low_level`
   scenario (level 20, is_leveling, OOC, no pet) + a scenario-aware
   `spell_exists`/`is_spell_learned` mock driven by the `not_learned` map
   (ArcaneBlast 30451, MageArmor 27125/6117, SummonFelguard 30146). Cleared
   **4 lanes** — `FireballLeveling`, `FrostboltLeveling`, `FrostArmor`,
   `SummonImp` (each fires ONLY in low_level). Pinned by
   `tests/test_low_level_lane_regression.lua`.
10. ~~**(d) destruction pet-summon dead branches**~~ **APPLIED 2026-08-07** —
    added the three missing `pref` branches to `summon_pet_matches`
    (`SummonFelhunter`/`SummonVoidwalker`/`SummonFelguard` →
    `return pref == "<pet>"`) + three OOC no-pet battery scenarios
    (`destro_pet_felhunter`/`destro_pet_voidwalker`/`destro_pet_felguard`).
    Cleared **3 lanes** (176 → 173, 0 regressions; each fires ONLY in its own
    scenario, auto-Imp path intact). Pinned by
    `tests/test_destro_pet_pref_regression.lua`. Fixes a live no-pet-at-all
    symptom for `pref = "felguard"` users.
11. ~~**Warlock opt-in fixture scenarios**~~ **APPLIED 2026-08-07** —
    `curse_mode_elements`/`curse_mode_recklessness`/`curse_mode_weakness`
    (`warlock_curse_mode` via setting_overrides) + `low_self_healthstone`
    (`hp 25` + `healthstone_hp 40`). Cleared **12 lanes** (173 → 161, 0
    regressions; each fires ONLY in its own scenario, probe-verified).
    Pinned by `tests/test_warlock_opt_in_regression.lua`. Pure fixture, no
    code change (mirrors the `auto_dispel` fixture).
12. ~~**Threat-context scenario**~~ **APPLIED 2026-08-07** — `threat_pct` /
    `threat_status` / `has_aggro` override passthrough + `threat_high`
    scenario (`threat_pct 95`, `threat_status 3`, `has_aggro true`).
    Cleared **9 lanes** (161 → 152, 0 regressions): warlock `Soulshatter` ×2
    (each fires ONLY in threat_high) + priest `Fade` ×3 + rogue `Feint` ×2 +
    assn `VanishReopen`/`FeintAoE` — the same threat-drop family, realistic
    high-aggro clears. hunter `FeignDeath` correctly stays silent (reads
    `state.threat_level` via hunter_core, not ctx threat_pct). Pinned by
    `tests/test_threat_context_regression.lua`.

Ranked items #1/#2/#3/#4/#5 are APPLIED (struck above) — #1 cleared the 5
warlock spreads (+4 shadow +2 balance shared with the non-DPS report; 194 →
183), #3/#4/#5 cleared Wand + FrostboltConserve + BladeFlurry (183 → 180,
0 regressions, 3 new scenarios: wand_low_mana, ab_stack_conserve,
battle_ready), #2 cleared ArcanePower/PoM/IcyVeins/ColdSnapIVReset (180 →
176, 0 regressions, 2 new scenarios: burn_ready, burn_coldsnap). If the
item #9 was applied: **47 → 43 DPS lanes** — the DPS ranked list is now
**fully applied**. The remaining ~43 are the (b) correctly-silent
PvP/defensive lanes, the stat-gated (c) cluster, and the two correctly-
suppressed ManaGemConjure lanes (see the Correctly-silent table). The
warlock focused triage (2026-08-07) corrected the buckets: warlock 25 =
(a) 13 · (b) 8 · (c) 1 · (d) 3; **ranked #10 APPLIED** (all three (d) destro
summon lanes fixed, 176 → 173, warlock 25 → 22), **ranked #11 APPLIED** (12
(a) warlock opt-in lanes, 173 → 161, warlock 22 → 10), **ranked #12 APPLIED**
(threat_high scenario, 161 → 152: Soulshatter ×2 + priest Fade ×3 + rogue
Feint ×2 + assn VanishReopen/FeintAoE), the **final (a) fixture**
(`destro_pet_succubus` scenario, 152 → 151 — SummonSuccubus; **warlock is
now fully clean**), **ranked #6-7 APPLIED** (151 → 145: `elite_target`
/`elite_taunt_cd` + `stealth_opener` scenarios + a scenario-driven
`stealth_helper` stub that killed the stale first-loaded-NS capture — cleared
`Taunt`/`TauntSecondary` + bonus `MockingBlow`/`ChallengingShout` + combat
`Garrote` + subtlety `CheapShot`, all exclusivity-pinned), and **ranked #8
APPLIED** (145 → 144: `prep_ready` scenario + bank-aware `get_spell_cd` —
subtlety `Preparation` cleared, fires ONLY there), and **ranked #9 APPLIED**
(144 → 140: `low_level` scenario + scenario-aware `spell_exists`/
`is_spell_learned` `not_learned` mock — arcane `FireballLeveling`/
`FrostboltLeveling`, frost `FrostArmor`, demo `SummonImp` cleared, each
fires ONLY in low_level). **Warrior/rogue focused-triage top item APPLIED
(2026-08-08, 140 → 133):** the `defensive_casting` scenario ({ stance = 2,
target_is_casting = true, hp = 15, is_pvp = true }) + a scenario-target
`is_casting_spell` method wired to ctx.target_is_casting (prot build_state
derives state.target_is_casting from it) — prot `Pummel` + `SpellReflection`,
arms `Disarm` + `SpellReflection`, combat/subtlety `Blind` cleared (6 lanes,
0 regressions; pinned by `tests/test_defensive_casting_regression.lua`).
**PvP-combo scenarios APPLIED (2026-08-08, 133 → 130):**
`pvp_stealth_opener` ({ is_pvp, buff_remains_map [1784] = 10 }) + `pvp_gap_close`
({ is_pvp, target_distance = 15 }) cleared assassination `PvP_CheapShotOpen`
+ `PvP_SprintGapClose` and druid/cat `Dash` (3 lanes, 0 regressions; pinned
by `tests/test_pvp_combo_lane_regression.lua`). **Opt-in (a) fixture
scenarios APPLIED (2026-08-08, 130 → 125):** `fury_overpower` (BT/WW on_cd
30335/1680 + setting), `fury_swing_desync` (swing_until 2.0 + setting),
`kebab_sunder` (mode maintain + stance 2), `cold_blood` (SnD map 6774/5171 +
poison stacks + auto setting), `thistle_tea` (energy 30/combo 0 + setting)
cleared Overpower, SwingDesync, SunderMaintain, ColdBloodEnvenom, ThistleTea
(5 lanes, 0 regressions; pinned by `tests/test_opt_in_lane_regression.lua`).
**Stat/weapon mocks APPLIED (2026-08-08, 125 → 118):** the `hit_rating` ctx
key + `hit_cap_deficit` scenario (rating 50 vs the 142 cap → deficit 92) and
the `equipped_daggers` mock + `mutilate_daggers` scenario (dagger 776 in both
hands → has_daggers) cleared `HitCapPriority` ×6 + `Mutilate` (7 lanes, 0
regressions; pinned by `tests/test_hitcap_dagger_regression.lua`).
The remaining ~25
are (b) correctly-silent
PvP/defensive and the two correctly-suppressed `ManaGemConjure` lanes.

### Close-out triage (2026-08-08) — the last 3 DPS lanes, probe-verified

Every remaining lane re-derived from the live matchers (direct probes: load
warrior/protection, build each scenario context, evaluate the strategy + a
7-scenario state dump). **Zero (d) dead lanes — all three are battery mock
gaps (b)/(c), each with a concrete fixture fix.** The 6 (a) close-out gates
re-verified: `test_optin_closeout_regression` + `test_opt_in_lane_regression`
+ `test_elite_low_self_regression` all PASS (arms/fury `SunderArmor`,
`CommandingShout` ×2, combat/subtlety `ExposeArmor` all still fire
exclusively in their scenarios).

| Lane | Class | Blocker (probe evidence) | Fix |
|------|-------|--------------------------|-----|
| `SunderArmor` (prot) | **(c)** | `state.dev_ready` — Devastate {30022,30016,20243} always "ready" (spell_ready stub → cooldown only; `not_learned` does NOT feed it) → matcher:531 returns false | `on_cd` scenario: `{ on_cd = { [30022] = 6, [30356] = 6, [30357] = 5 } }` → dev_ready false → filler branch fires (ss_ready/revenge_ready false, stacks 0 < 5) — one fixture, no mock change. **Note:** Devastate on CD also silences the Devastate lane in that scenario (harmless for the never-list, but don't pin Devastate to it) |
| ~~`Disarm` (prot)~~ ✅ **CLEARED (2026-08-08)** | **(b)→fired** | `disarm_class_ok` false everywhere — target mock lacked `get_class()` (prot:358 pcall → nil); `is_player` PvP-driven ✓. **APPLIED:** conditional `target:get_class()` (only when `ctx.target_class` set — mirrors friend_class, so warlock ShadowWard {5,9} + hunter ViperSting middleware untouched) + `pvp_disarm` scenario ({ is_pvp, target_class 1, `disarm_trigger = "always"` via setting_overrides — skips the on_burst burst-name gate, so NO enemy_buffed purge-lane collateral) | (b)→fired |
| ~~`Intervene` (prot)~~ ✅ **CLEARED (2026-08-08)** | **(b)→(d)→fired** | Mock gaps: `is_group` false everywhere, `lowest_allied`/`tank` nil (party scan gated on is_group; stub returned {}), `warrior_intervene_pvp_only` → needs is_pvp. **PLUS a real matcher bug:** `local dx, dy = me.get_position and me:get_position()` truncates the multi-value return to ONE value → dy/ay always nil → range gate always failed → dead even on the real API (reclassified (b)→(d)). **APPLIED:** `is_group`/`party_low_ally`/`friend_hp` ctx keys + `group_ally_low` scenario ({ is_group, is_pvp, party_low_ally, friend_hp 30 }) + me/friend `get_position` multi-value mocks + matcher now captures both values with an explicit nil guard (prot:767-776) |

**Ranked close-out list (final state — apply in order):**

1. ~~**prot `SunderArmor` (c)**~~ **APPLIED 2026-08-08** — the `on_cd`
   fixture (Devastate + ShieldSlam + Revenge on CD) PLUS the real blocker it
   exposed: the battery's `WarriorSpells` seed had no `Devastate` entry, so
   `define("Devastate")` fell back to empty ids and `cooldown_remains`
   could never resolve `[30022]`. Seeded Devastate ids {30022,30016,20243}
   (mirrors class:171) + added the `sunder_fallback` scenario. Devastate
   itself is silenced ONLY in that scenario (dev_ready false) — harmless, it
   fires in prot_filler_cd + cd_pressure. Pinned by
   `tests/test_sunder_fallback_regression.lua`.
   **Corrects the earlier `not_learned` suggestion** — that map only gates
   `spell_exists`/`is_spell_learned`, not `spell_ready`.
2. ~~**prot `Disarm` (b)**~~ **APPLIED 2026-08-08** — conditional
   `target:get_class()` (only when `ctx.target_class` set) + `pvp_disarm`
   scenario ({ is_pvp, target_class 1, `disarm_trigger = "always"` }). The
   `disarm_trigger` override skips the on_burst burst-name gate, so
   `enemy_buffed` is NOT needed — purge-buffed lanes keep their exclusivity
   (verified: all 28 battery suites green). Pinned by
   `tests/test_pvp_disarm_regression.lua`.
3. ~~**prot `Intervene` (b)**~~ **APPLIED 2026-08-08** — `is_group` ctx key,
   friend-mock `get_position`/`effective_hp`, `lowest_allied` population,
   and a `group_ally_low` scenario. **Bonus find during wiring: the matcher
   itself was a real (d) dead lane** — `local dx, dy = me.get_position and
   me:get_position()` truncates multi-value returns to one, so dy/ay were
   always nil and Intervene could never fire even on the real API; the
   matcher now captures both values with an explicit nil guard. Pinned by
   `tests/test_intervene_lane_regression.lua`.
   (The `target_class` mechanism generalizes — **now proven in practice**:
   the `shadow_caster` scenario (ranked-(b) #1, 2026-08-08) reused it with
   `target_class = 9` to clear warlock `ShadowWard` ×2 with zero new wiring.)

After #1 + #3 + ShadowWard: DPS → **13**, all-spec → **100** (the `totem_far`
scenario then cleared shaman/enh `TotemicCall`, non-DPS 93 → 92; the
`friendly_target` scenario then cleared the 5 healer `FriendlyTarget` lanes
(disc + holy priest, holy paladin, resto druid + shaman), non-DPS 92 → 87),
warrior/protection → **0 never-firing** (the last DPS spec with remaining lanes).
**Contract correction (2026-08-08):** the TotemicCall follow-up probe verified
`get_position` returns ONE vec3 table `{x,y,z}` (auto_loot/targeting/EaxESP/
object_scanner all read `.x/.y/.z`), so the table-form reads were CORRECT —
the multi-value capture in prot's party scan + this matcher was the live-dead
side. Both now read the table fields (protection:426-448, 767-780) and the
battery me/friend mocks return the vec3 table with [1]/[2] aliases; the
`totem_far` scenario + `ns.core` stubs make the enh recall scan observable.
Pinned by `tests/test_totemic_call_lane_regression.lua` and the updated
`tests/test_intervene_lane_regression.lua`.

Correctly silent, no action: `FriendlyTarget` ×4, `MountedProtection`,
`EncounterReactions`, PvP/snare/ally/CC lanes, `DevouringPlague`/`Starshards`/
`SoloPsychicScream` (racial/CC state).

---

## What is NOT in this report

- 5 pre-existing test-suite failures (generated JSON / `.omo` evidence data
  gaps) are unrelated.
- Leveling suites and `.vanilla`/`.wotlk` era files are out of scope.

---

## Campaign summary (2026-08-08)

Final state of the triage-to-clear campaign (behavioral battery, 31 specs, **135 scenarios**, 0 load failures).

- **Never-firing chain:** 304 → **100** (DPS 13 + non-DPS 87). Every category-(d) dead lane found and FIXED — including the prot `Intervene` truncation bug, reclassified (b)→(d) live during the sweep. Zero (a) opt-in and zero (d) lanes remain.
- **Current classification of the 100:** **(b) 38 · (c) 62 · (a) 0 · (d) 0.** (b) = PvP/stealth/OOC/situational — correctly silent vs the PvE-shaped scenario set; (c) = mock limitations that work in live play; none are dead code.

**Per-spec buckets (never-firing / of which (b)):**

| Spec | Never | (b) | Spec | Never | (b) |
|---|---|---|---|---|---|
| druid balance | 6 | 3 | paladin holy | 8 | 2 |
| druid bear | 8 | 4 | paladin protection | 8 | 2 |
| druid caster | 0 | — | paladin retribution | 8 | 3 |
| druid cat | 8 | 2 | priest discipline | 0 | — |
| druid resto | 6 | 4 | priest holy | 4 | 2 |
| hunter beast_mastery | 5 | 2 | priest shadow | 3 | 1 |
| hunter marksmanship | 2 | 0 | priest smite | 4 | 2 |
| hunter survival | 2 | 0 | shaman elemental | 6 | 1 |
| mage arcane | 2 | 2 | shaman enhancement | 6 | 1 |
| mage fire | 2 | 2 | shaman restoration | 3 | 1 |
| mage frost | 5 | 2 | warlock affliction | 3 | 3 |
| rogue ×3 | 0 | — | warlock demonology | 1 | 1 |
| warrior ×4 | 0 | — | warlock destruction | 0 | — |

**Validation:** 466 rotation suites / 461 pass (5 pre-existing env/data-file gaps); 33 battery regression suites pin the unblocked lane families.

**Ranked remaining-(b) lanes** (all correctly silent vs the scenario set; ranked by cost-to-clear):

1. ~~warlock `ShadowWard` ×2~~ ✅ **APPLIED 2026-08-08** — the `shadow_caster` scenario (is_pvp + `target_class` 9 + hp 50) reuses the `pvp_disarm` `get_class` mechanism; pinned by `tests/test_shadowward_lane_regression.lua`.
2. ~~`FriendlyTarget` ×5~~ ✅ **APPLIED 2026-08-08** — the `friendly_target` scenario (`friendly_target_hp` 60, keyed on the hp alone — deliberately no boolean, which would collide with `healing_sylvanas.lua:454` reading `context.friendly_target` as a unit) makes `ns.get_friendly_target_entry` scenario-aware (real contract: `core/units.lua:129` — `{ unit, hp_pct, effective_hp, is_player }`); cleared disc + holy priest, holy paladin, resto druid + shaman. Pinned by `tests/test_friendly_target_lane_regression.lua`. (The report's ×4 count predates the paladin/holy row; all 5 lanes cleared.)
3. mage `Blink` ×2 (arcane, frost) — a `self_rooted_snared` state key.
4. mage `Polymorph` ×2 (arcane, fire) — a `cc_target`/humanoid `target_class = 6` scenario.
5. warlock `Seduction` (demo) — `pet_type_succubus` + `is_pvp` (partial: `destro_pet_succubus` exists).
6. affliction `PvP_CurseExhaustion`/`PvP_CurseTongues`/`CC_HowlOfTerror` — `is_pvp` + `melee_on_you` + `enemy_caster` combo (one scenario, 3 lanes).
7. druid PvP/melee-snare family (`PvP_Cyclone`/`PvP_EntanglingRoots`/`PvP_NaturesGrasp`, `EntanglingRootsMelee`/`NaturesGraspMelee`, `BearFormFocusedByMelee`, `CycloneEnemyHealer`) — PvP/snare CC state.
8. paladin snare/ally family (`BlessingOfFreedomSnare`, `BlessingOfProtectionFocusedAlly`, `BlessingOfProtectionAlly`, `RighteousDefense`, `Ret_BlessingFreedom` ×2, `Ret_HammerWrath_FleeingPvP`) — snare/ally-target state.
9. shaman `TremorTotem` ×3 — fear-CC state.
10. priest situational (`MountedProtection`, `EncounterReactions`, `SWDCCBreak`, `DevouringPlague`, `Starshards`) — mounted/boss-ID/fear/undead-race/night-elf racial.
11. druid OOC pulls/taunts/travel (`FaerieFirePull`, `FeralChargePull`, `PrePullEnrage`, `Growl`, `TrackHumanoids`, `TravelForm`) + hunter BM `FeignDeath`/`Misdirection` — OOC/threat state.
12. mage `ManaGemConjure` ×2 — correctly suppressed (gem always available); **do not re-triage**.

**Stale-content corrections (2026-08-08):** the older "Category counts (current)" paragraphs in both reports (and the embedded per-class counts) were intermediate snapshots and are superseded here; the DPS focused-triage rows for `Feint`/`FeintAoE`/`Blind` (cleared via `threat_high`/`defensive_casting`) and the non-DPS per-spec `FriendlyTarget` (c) tags (unified to (b) — requires manual party-frame selection) were stale and are corrected above.

**DPS (c) inventory — closed (2026-08-08):** the follow-up (c) sweep found **0 open (c) rows** in this report (all 5 were cleared/reclassified earlier). The full remaining-(c) ranked next-up list (20 fixtures, ~30-32 lanes) lives in the non-DPS report's `Focused follow-up triage — remaining (c) mock-limitation lanes (2026-08-08)` section; nothing here is actionable.
