# wowsims APL fixtures — provenance manifest

Pinned reference APL JSONs used by `shared/apl_parser.lua`,
`tools/apl_status.lua` (the conformance manifest that auto-fills the
scorecard's APL_STATUS column), and `tests/test_apl_conformance.lua`
(Phase 2 APL conformance). Adding a conformant spec = one pinned fixture
here + one entry in `tools/apl_status.lua`'s `M.ENTRIES`.

| Local fixture | Upstream source | Commit |
|---|---|---|
| `fire_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/fire.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `affliction_wotlk.apl.json` | `wowsims/wotlk` `ui/warlock/apls/affliction.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `feralcat_wotlk.apl.json` | `wowsims/wotlk` `ui/feral_druid/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `arcane_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/arcane.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `frost_wotlk.apl.json` | `wowsims/wotlk` `ui/mage/apls/frost.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `combat_wotlk.apl.json` | `wowsims/wotlk` `ui/rogue/apls/combat.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `mutilate_wotlk.apl.json` | `wowsims/wotlk` `ui/rogue/apls/mutilate.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `elemental_wotlk.apl.json` | `wowsims/wotlk` `ui/elemental_shaman/apls/advanced.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `shadow_wotlk.apl.json` | `wowsims/wotlk` `ui/shadow_priest/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `disc_priest_wotlk.apl.json` | `wowsims/wotlk` `ui/healing_priest/apls/disc.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `holy_priest_wotlk.apl.json` | `wowsims/wotlk` `ui/healing_priest/apls/holy.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `dk_blood_wotlk.apl.json` | `wowsims/wotlk` `ui/deathknight/apls/blood_dps.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `dk_frost_wotlk.apl.json` | `wowsims/wotlk` `ui/deathknight/apls/frost_bl_pesti.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `dk_unholy_wotlk.apl.json` | `wowsims/wotlk` `ui/deathknight/apls/uh_2h_ss.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `druid_balance_wotlk.apl.json` | `wowsims/wotlk` `ui/balance_druid/apls/basic_p3.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `druid_bear_wotlk.apl.json` | `wowsims/wotlk` `ui/feral_tank_druid/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `hunter_bm_wotlk.apl.json` | `wowsims/wotlk` `ui/hunter/apls/bm.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `hunter_mm_wotlk.apl.json` | `wowsims/wotlk` `ui/hunter/apls/mm.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `hunter_sv_wotlk.apl.json` | `wowsims/wotlk` `ui/hunter/apls/sv.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `pal_prot_wotlk.apl.json` | `wowsims/wotlk` `ui/protection_paladin/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `pal_ret_wotlk.apl.json` | `wowsims/wotlk` `ui/retribution_paladin/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `sham_enh_wotlk.apl.json` | `wowsims/wotlk` `ui/enhancement_shaman/apls/default_wf.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `war_arms_wotlk.apl.json` | `wowsims/wotlk` `ui/warrior/apls/arms.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `war_fury_wotlk.apl.json` | `wowsims/wotlk` `ui/warrior/apls/fury.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `war_prot_wotlk.apl.json` | `wowsims/wotlk` `ui/protection_warrior/apls/default.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `wl_demo_wotlk.apl.json` | `wowsims/wotlk` `ui/warlock/apls/demo.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |
| `wl_destro_wotlk.apl.json` | `wowsims/wotlk` `ui/warlock/apls/destro.apl.json` | `563e4a08cb15729f1fdcbcf68e6d68224553bfef` |

- **Repo:** github.com/wowsims/wotlk, branch `master`.
- **Commit:** `563e4a08cb15729f1fdcbcf68e6d68224553bfef` (2025-12-22).
- **Fetched:** 2026-08-09 via the GitHub raw endpoint (healer fixtures: 2026-08-10,
  same commit — both `disc.apl.json` + `holy.apl.json` exist at `563e4a08`).
- **Format:** wowsims `TypeAPL` JSON (`priorityList` of actions).
- **Update policy:** re-fetch only on an intentional conformance re-baseline;
  update this table + the commit ref in `shared/apl_parser.lua` together.

## Healer fixtures (2026-08-10): the correction to the "no healer APL" claim

The scorecard/README previously stated no healer rotation simulator exists for
any classic era. **That is wrong for WotLK holy/disc priest.** `wowsims/wotlk`
has a real, executed healer sim:

- `sim/priest/healing/healing_priest.go` — agent engine (registers healing
  spells, Rapture, Hymn of Hope).
- `sim/priest/healing/healing_priest_test.go` — `TestDisc`/`TestHoly` run the
  full character test suite with `IsHealer: true` and
  `Rotation: core.GetAplRotation("../../../ui/healing_priest/apls", "disc"/"holy")`
  — the two APL JSONs below are the sim's ACTUAL rotation, executed in CI.
- `ui/healing_priest/apls/disc.apl.json` + `holy.apl.json` — TypeAPL JSON
  (`spellCpm` budget conditions + `castSpell`/`multidot`/`multishield` actions;
  `priority_ids` extracts them via `shared/apl_parser.lua`, which handles the
  `multishield` action form used by the disc PW:S entry).

`wowsims/classic` (SoD) carries the same two `ui/healing_priest/apls/*.apl.json`
files at master, but the pins below use the wotlk repo at the pinned commit.

**Claim boundaries (verified 2026-08-10 against the wotlk tree):**
- holy/disc **priest** — real sim + APL (pinned here).
- **holy paladin** — engine scaffolding exists (`sim/paladin/holy/holy.go`,
  `holy_test.go` with `IsHealer: true`) but `rotation.go` is a stub
  (`OnGCDReady` just waits 5s) and there is no `ui/holy_paladin/apls/` — no
  defensible rotation, stays `pending`.
- **resto druid / resto shaman** — agent scaffolding exists
  (`sim/{druid,shaman}/restoration/restoration.go`, `TestRestoration.results`)
  but neither file defines `OnGCDReady` (no rotation implemented) and their UI
  dirs have no `apls/` — stays `pending`.
- **TBC-era** (`wowsims/tbc`) — zero healer dirs at all; **vanilla-era** — no
  wowsims project (wowsims/classic is SoD, not vanilla) — both stay `pending`.
- The healer APLs are CPM-budget profiles ("keep X casts/minute"), not the
  full priority lists of the DPS APLs — the pins therefore enforce the ORDER of
  the spell actions in the list (e.g. holy: GreaterHeal before Renew before
  PrayerOfMending), which is the sim's evaluation order. Spells absent from our
  rotation (holy's Circle of Healing 48089; disc's filler GreaterHeal 48063)
  resolve to nil and impose no constraint, mirroring the TBC seed/AoE-branch
  exclusion policy.

## Why feralcat is special

`ui/feral_druid/apls/default.apl.json` delegates the rotation to the Go
`catOptimalRotationAction` black box — the JSON carries only prepull actions and
one `catOptimalRotationAction` node, no steady-state spell list. The reference
order for feral cat is therefore pinned **from the Go source** at the same
commit, `sim/druid/feral/rotation.go` → `doRotation()` dispatch order:

```
FaerieFireFeral  (ffNow)
SavageRoar       (roarNow)
Rip              (ripNow)
FerociousBite    (biteNow)
MangleCat        (mangleNow)
Rake             (rakeNow)
Shred            (filler)
```

(`Berserk` is a CD handled outside the loop; `Ravage` is a stealth opener only.)

The pin lives in `tests/test_apl_conformance.lua` with the Go dispatch-order
comment; the JSON fixture is still tracked so the loader path stays uniform.

## TBC era — pinned from Go dispatch (no TypeAPL JSON exists)

**wowsims/tbc has no TypeAPL JSON fixtures.** That format postdates the TBC
repo; rotations are imperative Go dispatch files (pre-TypeAPL era). TBC
conformance therefore pins `reference_names` lists extracted from the sim's
check-order at **wowsims/tbc `master`** (fetched 2026-08-09).

`check_name_order` only enforces the *relative order of names present in both
lists*, so the pins deliberately include only the sim's dispatch chain and
ignore: the warlock curse `switch` (mutually exclusive — one curse at a time),
Starshards (racial, `UseStarshards` opt-in), seed/AoE branches, and our own
extra strategies (potions/defensives/moving variants).

| Manifest key | Go source (wowsims/tbc `master`) | Reference order |
|---|---|---|
| `tbc/shadow` | `sim/priest/shadow/rotation.go` `tryUseGCD` | VampiricTouch → ShadowWordPain → DevouringPlague → MindBlast → MindFlay |
| `tbc/affliction` | `sim/warlock/rotations.go` `tryUseGCD` (after curse switch) | UnstableAffliction → Corruption → SiphonLife → Immolate → ShadowBolt |
| `tbc/combat` | `sim/rogue/rotation.go` `doPlan*` family | SliceAndDice → Eviscerate → SinisterStrike |
| `tbc/elemental` | `sim/shaman/elemental/rotation.go` (LB/CL-only sim) | ChainLightning → LightningBolt |
| `tbc/fire` | `sim/mage/rotations.go` `doFireRotation` | Scorch (5-stack) → Fireball |
| `tbc/frost` | `sim/mage/rotations.go` `doFrostRotation` | Frostbolt |
| `tbc/balance` | `sim/druid/balance/rotation.go` `actRotation` | FaerieFire → InsectSwarm → Moonfire → Starfire |
| `tbc/cat` | `sim/druid/feral/rotation.go` `doRotation` | FaerieFire → Rip → Mangle → FerociousBite → Shred |
| `tbc/beast_mastery` | `sim/hunter/rotation.go` `tryUsePrioGCD`/`lazyRotation` | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/marksmanship` | `sim/hunter/rotation.go` (same dispatch) | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/survival` | `sim/hunter/rotation.go` (same dispatch) | SerpentSting → MultiShot → ArcaneShot → SteadyShot |
| `tbc/arcane` | `sim/mage/rotations.go` `doArcaneRotation` | ArcaneBlast → Frostbolt(conserve) → ArcaneMissiles |
| `tbc/retribution` | `sim/paladin/retribution/rotation.go` `mainRotation` | Judge(Crusader) → ApplySeal → CrusaderStrike → SealOfBlood |
| `tbc/smite` | `sim/priest/smite/rotation.go` `tryUseGCD` | ShadowWordPain → Starshards → DevPlague → MindBlast → Smite |
| `tbc/enhancement` | `sim/shaman/enhancement/rotation.go` (schedule) | Stormstrike → FlameShock → EarthShock → FrostShock |
| `tbc/demonology` | `sim/warlock/rotations.go` `tryUseGCD` | Corruption → SiphonLife → Immolate → ShadowBolt |
| `tbc/destruction` | `sim/warlock/rotations.go` (Incinerate branch) | Corruption → Immolate → Incinerate |
| `tbc/arms` | `sim/warrior/dps/rotation.go` `normalRotation` | Execute → MortalStrike → Whirlwind → Overpower |
| `tbc/fury` | `sim/warrior/dps/rotation.go` `normalRotation` | Execute → Bloodthirst → Whirlwind → Overpower |
| `tbc/bear` | `sim/druid/tank/rotation.go` `doRotation` | FaerieFire → DemoralizingRoar → Mangle → Lacerate |
| `tbc/paladin/protection` | `sim/paladin/protection/rotation.go` `OnGCDReady` | HolyShield → Consecration → Judgement → Seal → Exorcism |
| `tbc/warrior/protection` | `sim/warrior/protection/rotation.go` `doRotation` | ShieldSlam → Revenge → Devastate → SunderArmor |
| `tbc/caster` | `sim/druid/balance/rotation.go` `doRotation` (damage-chain subset) | FaerieFire → Moonfire → Wrath |

Notes:
- **Bear**: Swipe is AoE/AP-gated and Maul is queued on-next-swing (both
  non-GCD branches), so they are excluded from the pin; FF-before-DemoRoar
  matches the Go dispatch's check order (previously reversed in our file).
- **Prot paladin**: the seal is applied on the Judgement branch of the Go
  dispatch; Avenger's Shield is a 30s CD outside the GCD chain and excluded.
- **Prot warrior**: pinned against the DEDICATED `sim/warrior/protection/rotation.go`
  (`doRotation`: ShieldSlam → Bloodthirst → MortalStrike → Revenge → Shout →
  ThunderClap → DemoShout → Devastate → SunderArmor). Revenge IS modeled (the
  earlier batch-3 note claiming otherwise was wrong — that pin cited the DPS
  dispatch file). Bloodthirst/MortalStrike are arms/fury talents absent from the
  prot rotation; Shout (Battle Shout) is a buff-maintenance lane our rotation
  places far below the sim's mid-chain check — excluded with that honest reason.
  The pin includes ThunderClap + DemoralizingShout: the dispatch checks ThunderClap
  BEFORE DemoShout, and our ACTIONS table was reversed (DemoShout first); it was
  reordered to match the sim as a pure order move (2026-08-09) so both are
  pinnable and the pin stays provably live.
- **Assassination / subtlety**: the wowsims/tbc tree has exactly ONE rogue
  rotation — `sim/rogue/rotation.go` — which is **combat-only**: its `Builder`
  is fixed to SinisterStrike (no Mutilate/Backstab/Envenom anywhere in the Go
  rotation or `sim/rogue/` tree) — no defensible dispatch exists, `pending`.
- **Caster**: NO `sim/druid/caster*` preset exists in the wowsims/tbc tree (only
  balance/feral/tank). The caster pin uses the damage-chain subset shared with
  the balance moonkin dispatch (FaerieFire → Moonfire → Wrath); Hurricane /
  InsectSwarm / Starfire raid branches and defensives are excluded.
- **Kebab** (custom DW-arms variant): no `sim/warrior/*` preset models a
  dual-wield arms build (tree has only dps + protection) — no defensible
  dispatch, `pending`.
- **Healers** (druid/resto, paladin/holy, priest/holy + discipline, shaman/
  restoration): the wowsims/tbc tree contains NO healer rotation directories —
  only balance/feral/tank, protection/retribution, shadow/smite, elemental/
  enhancement, dps — so they remain `pending` by absence of evidence.
- **FireBlast** is an *opt-in* weave (`WeaveFireBlast` defaults to `false` in
  `ui/mage/inputs.ts`), so it is deliberately NOT in the `tbc/fire` pin — our
  rotation keeps FireBlast as a movement/instant lane below Fireball, matching
  the default sim.
- **Elemental**: the TBC sim rotation is LB/CL-only (no FlameShock upkeep);
  FlameShock and the moving/totem strategies are our extras and ignored.
- **Healers** (holy/disc/resto/healing) have **no wowsims rotation at all** —
  they legitimately remain `pending` in the scorecard.
- Adding a TBC spec = add a `reference_names` entry to `tools/apl_status.lua`
  (`M.ENTRIES`) + a row here; no JSON fetch required.

## WotLK battery triage provenance (2026-08-09)

The WotLK never-firing inventory (149 lanes) was cleared to **0** in the Phase-1
triage — the result lives in `tests/behavioral_audit.lua`, not here. What changed
and why:

- **Resource/cooldown accessors** — `me:get_rage()/get_energy()/get_combo_points()/
  get_runic_power()` and `action:cooldown_remaining()` were absent from the battery
  unit/spell mocks; WotLK specs read them directly (`NS.me or NS.GetPlayer()`),
  so every resource-gated lane read 0/99. Added bank-driven accessors.
- **DK shared-manager stubs** — `rune_manager`, `presence_manager`,
  `interrupt_manager` were stubbed before `ns` was in scope (dead closures);
  rewired after `build_ns`, bank-driven. Cleared runic-power gates
  (DancingRuneWeapon/DeathCoil), EmpowerRuneWeapon (depleted-rune bank),
  Presence/FrostPresence (optimal_presence bank), MindFreeze ×3
  (target_is_casting-aware interrupt).
- **Scenario banks** — 17 new scenarios: `dk_runic/dk_boss/dk_disease/
  dk_runes_depleted/dk_presence`, `lvl_feral/lvl_bear/lvl_cat_form/lvl_bear_form`,
  `resto_swiftmend`, `surv_lockload`, `fire_scorch`, `ooc_low_mana`,
  `lvl_shadowform`, `shaman_ready`, `enh_procs`, `resto_triage`.
- **Note:** the DK leveling/unholy files install the real `aoe_hit_volume`
  (overrides the battery's always-true `aoe_target_meets`), so AoE-gated lanes
  need `enemy_count` in their scenario, not just a stub.
- All fixes were **battery-fixture only** — zero spec-file matcher/order edits
  (no (d) dead lanes existed; the discipline holds).
- Scorecard era "wotlk" flipped from LENIENT to STRICT (no untriaged backlog).

## TBC healer category-(c) close-out provenance (2026-08-09)

The non-DPS triage classified 13 healer never-lanes as (c) (battery-mock
limitation-but-modelable). A battery-fixture campaign cleared them, dropping
the TBC era never-count from **91 to 78** (c: 34 → 21) with zero spec-file
matcher/order edits — same discipline as the WotLK campaign. The clears are
pinned in `tests/test_healer_c_closeout_regression.lua`; scenario definitions
live in `tests/behavioral_audit.lua` `SCENARIOS` (holy_*/smite_*/shadow_*/
resto_* banks). What changed and why:

- **`buff_up` forwarding** — smite captures `buff_up` via `import_helpers`, but
  the battery capture table had no entry, so the catch-all `function() return
  true end` made `has_renew`/`has_inner_focus` always-true and SoloRenew /
  InnerFocus could never gate-fail (always masked). The captured `buff_up` now
  forwards to the live map-aware binding — lane firing became honest.
- **Heal-scan attachment** — `friends_hp` + a `lifebloom` bank (index/stacks/
  remains) feed the battery heal-scan so `state.lowest` (holy LayOnHandsLast
  Resort) and the `lifebloom_bloom` entry (druid LifebloomLetBloom, stacks ≥ 2,
  <1s left) become observable.
- **Scenario banks** — 12 new scenarios: `holy_last_resort`, `holy_jow_boss` /
  `holy_jol_boss` / `holy_solo_judge` (seal buff maps 20166/20165/20154),
  `holy_solo_execute`, `holy_solo_aoe`, `smite_solo_renew`, `shadow_holy_nova`
  (combat-mode aoe setting override), `resto_lightning_shield` (shield-type
  setting override), `resto_chain_lightning`, `resto_travel_reposition` (OOC +
  moving + range), `resto_lifebloom_bloom`.
- **Paladin/holy boss lanes** — JudgementOfLightBoss / JudgementOfWisdomBoss
  needed a seal buff map; the `holy_jol_boss`/`holy_jow_boss` scenarios carry
  Seal of Light (20165) / Seal of Wisdom (20166).
- **Shadow HolyNovaAoE** — gated on `shadow_combat_mode = "aoe"`; the scenario
  applies it via `setting_overrides`.
- All fixes were **battery-fixture only** — the 13 lanes were never (d); the
  triage classifications remain live in `tools/spec_scorecard.lua` `LANE_CLASS`
  (pins for these lanes removed as they cleared).

---

## TBC (c) batch-2 close-out (2026-08-09): 78 → 60

The scorecard's `LANE_CLASS` classified 21 remaining TBC category-(c) lanes as
battery-mock-limitation-but-modelable (never was 78: a=14 b=43 c=21 d=0). A
second battery-fixture campaign cleared **18**, dropping the TBC era never-count
from **78 to 60** (c: 21 → 3) with one genuine spec-file dead-lane fix. Clears
are pinned in `tests/test_c_batch2_closeout_regression.lua`; scenarios live in
`tests/behavioral_audit.lua` `SCENARIOS` (batch-2 banks). What changed and why:

- **druid/balance (2)** — `HurricaneAoE` needed DruidSpells.Hurricane resolvable
  (new battery stub) + aoe/mana/Barkskin-active bank (`hurricane_aoe`);
  `RebirthBattleRez` needed a dead player ally — new `find_dead_party_ally`
  stub fed by the `dead_ally` bank (`rebirth_dead_ally`).
- **druid/bear (2)** — `Swipe` needed form=1 (bear) + aoe + rage + short TTD so
  the Lacerate pre-stack gate passes (`bear_swipe_aoe`); `EnrageCombat` needed
  rage-starved single target (`bear_enrage`).
- **druid/cat (2)** — `ClawFallback` needed Mangle marked unlearned via the
  `not_learned` bank (`cat_claw_fallback`); `MangleFiller` needed
  `is_behind = false` so the Shred-preference gate passes (`cat_mangle_filler`).
- **hunter/BM Trinket (1)** — TWO changes: (a) battery now stubs
  `TrinketManager.get_equipped_trinkets` (has_trinket bank, `bm_trinket`); (b)
  **genuine dead-lane fix in the spec** — `beast_mastery_sylvanas.lua:78`
  `local is_item_ready` forward-declaration was shadowed by `:458`
  `local function is_item_ready(...)` (a second local), so build_state's
  `safe_any` received nil and `trinket_1_ready` was **always false in the live
  game too** — the lane could never fire anywhere. Changed :458 to an
  assignment so the line-78 local is populated.
- **hunter/MM InCombatAimedShot (1)** — fresh-combat opener (`combat_time 0.2`,
  `mm_aimed_opener`) so the Serpent-Sting setup gate is skipped.
- **paladin/protection (2)** — `AvengingWrath` needed use_cooldowns + ttd above
  the 15s expiry (`prot_cd_window`); `LayOnHands` needed self hp < 10%
  (`prot_low_self`).
- **paladin/retribution (3)** — cleanse/purify lanes were masked by the
  catch-all always-true `has_player_debuff`/`has_target_debuff`; both are now
  map-aware (`player_debuff_remains_map`, `ret_cleanse_self`) so the gates are
  honest.
- **shaman/elemental (3)** — `ChainHeal` needed a group-injured friend
  (`group_injured` bank, `elem_group_injured`); `ElementalMastery` needed burst
  + the per-CD setting (`elem_burst_cd`); `TotemicCall` needed moving + totems
  up (`has_totems` bank, `elem_totemic_call`).
- **shaman/enhancement (2)** — `EarthShock` needed the scenario target's
  `get_cast_pct` in the 40..80 kick window (new target stub, `enh_interrupt`);
  `ShamanisticRage` needed low mana + the `enhancement_cd_shamanistic_rage`
  toggle (DSL condition, `enh_low_mana`).
- **Genuinely unpinnable (3, remain (c))** — `RakeSnapshot` / `RipSnapshot`
  read the module-local `snapshot_state` (cat:247-254) populated only by
  `record_bleed_snapshot` on a real cast; `FireNovaReplacement` reads
  module-local `totem_state.fire_nova_active` (enhancement:135) populated only
  by the spec's totem-drop lifecycle. The battery never casts/drops totems, so
  these cannot be driven by fixtures — left classified (c) with the rationale
  in `LANE_CLASS`.
- All clears are battery-fixture + the one dead-lane fix; no matcher-logic or
  order changes. Remaining split: **a=14 b=43 c=3 d=0**.
- **(a) opt-in close-out (2026-08-10)** — the last 14 category-(a) lanes
  (opt-in settings the battery's `setting_overrides` merge can drive) cleared
  with ONE battery-fixture scenario each, dropping the TBC era never-count
  60 -> 46. ZERO spec-file edits.
  - **druid/balance (1)** — `MoonkinForm` (`moonkin_form_optin`):
    `balance_moonkin_auto` + OOC (DSL `in_combat invert`, balance:695).
  - **druid/bear (1)** — `Barkskin` (`bear_barkskin`): `bear_use_barkskin` +
    caster form (TBC breaks the form) + hp 40 in (15, 55].
  - **druid/cat (2)** — `RipTrick` (`cat_rip_trick`): setting + combo >= 1 +
    rip down + energy 35 in the [30,40) window + ttd 30; `ShredTrick`
    (`cat_shred_trick`): setting + behind + rip-up bleed + energy 80 +
    next_tick > 1.0 via the new scenario-overridable `energy_time_to_x` stub
    (mock hardwired 0.4, which sat under the gate) + combo 2.
  - **mage/frost (3)** — `FireBlast` / `Scorch` / `ArcaneMissiles`
    (`frost_*_optin`): pure setting toggles (frost:400/432/440).
  - **paladin/protection (4)** — `AvengerShield` (`prot_avenger_shield`):
    setting + in-combat mode; `HammerOfWrath` (`prot_hammer_wrath`): DSL
    setting + target_hp 15; `Judgement` (`prot_judgement`): setting + Seal of
    Righteousness 27155 up -> damage mode; `SealOfCommandAoE`
    (`prot_seal_command`): setting + 4 enemies + no seal up.
  - **paladin/retribution (2)** — `Consecration` (`ret_consecration`): setting
    + 4 enemies + mana 60; `Ret_Consecration_ManaDump` (`ret_consec_dump`):
    setting + mana 80.
  - **shaman/enhancement (1)** — `GraceOfAirTotemTwist` (`enh_goa_twist`): WF
    buff 25587 up > 2s + GoA 25359 expiring < 5s + mana 60. REQUIRED the
    battery's `buff_remains`/`buff_up`/`debuff_*` stubs to normalize
    spell_action objects (ACTION.* exposes `.ids`, not top-level numeric keys)
    via a shared `normalize_ids()` — the legacy iteration always missed the
    map, so the totem-aura gates could never pass.
  - **Remaining split: a=0 b=43 c=3 d=0** — every modelable TBC lane is now
    observable; the only pins left are correctly-silent (b) and the 3
    module-local-state (c) lanes. WotLK stays 0.

## TBC (b)-bucket close-out (2026-08-10) — never 46 → 19 (a=0 b=16 c=3 d=0)

The 43-lane (b) audit (PvP/OOC/situational) classified 28 as fixture-modelable;
this campaign cleared **27** with pure battery-fixture work — zero spec-file
edits, no matcher-logic or order changes. Fixtures added to
`EaxRotations/tests/behavioral_audit.lua`:

- **9 scenarios**: `pvp_melee` (is_pvp + melee_on_you + enemy_healer +
  enemy_caster + cc_target + target_fleeing + target_hp 15), `pvp_pressure_resto`
  (is_pvp + hp 30 + enemies_in_range {melee,healer}), `fear_nearby`,
  `snare_self` (self_rooted_snared + player_debuff_remains_map [122] +
  snared_friend), `shadow_cc_break` (player Polymorph 118),
  `bm_misdirection` (combat_time 2 + use_misdirection), `bear_challenging_roar`
  (form 1 + 4 enemies + bear_use_challenging_roar), `enh_autoattack`
  (is_auto_attacking false), `pvp_succubus` (has_pet + pet_spells 27274).
- **Stub surface**: scenario-driven `GetEnemiesInRange` (+ `_battery_enemy`
  factory) for resto scan_pvp_pressure; `is_auto_attacking` stub now
  bank-driven with default true (battery artifact only — the live client's
  is_auto_attacking is false at combat start, so enh AutoAttack fires in-game);
  `OffensiveDispelDB.is_breakable_cc_active` delegates to `debuff_up` over the
  damage-breakable CC ids; `debuff_up`/`debuff_remains` gain a player-map
  branch (unit == ns.me → player_debuff_remains_map); `NS.GetPlayer()` now
  returns the scenario me unit once published (shadow resolves the player via
  GetPlayer, so the player-map branch matches); `_scenario_me.has_pet/get_pet`
  + `ns.core.spell_book.get_pet_spells` for demo pet classification;
  `snared_friend` marks the lowest heal-scan ally `is_snared` (holy freedom);
  `cc_target` resolves to a real unit (a boolean crashed the poly matcher);
  `RACE_OVERRIDES = { smite = 4 }` (require-time race binding → Starshards).
- **Lanes cleared (27)**: balance PvP_Cyclone/EntanglingRoots/NaturesGrasp;
  bear ChallengingRoar (re-bucketed from (b) to (a)-shape); resto
  BearFormFocusedByMelee/NaturesGraspMelee/CycloneEnemyHealer/EntanglingRootsMelee;
  BM Misdirection; arcane Blink+Polymorph; fire Polymorph; frost Blink; holy
  BlessingOfFreedomSnare; ret Ret_BlessingFreedom_Self/_Ally +
  Ret_HammerWrath_FleeingPvP; shadow SWDCCBreak; smite Starshards; shaman
  TremorTotem ×3 + enh AutoAttack; warlock CC_HowlOfTerror + PvP_CurseExhaustion
  + PvP_CurseTongues + demo Seduction.
- **Kept (16 b + 3 c)**: 9 correctly-silent OOC/disabled (PrePullEnrage,
  FaerieFirePull, FeralChargePull, TrackHumanoids, TravelForm, MountedProtection,
  ManaGemConjure ×2, DispelMagic); 5 threat-family deferred (Growl,
  RighteousDefense, FeignDeath, BlessingOfProtectionAlly/FocusedAlly);
  EncounterReactions (declined — vacuous without boss data); DevouringPlague
  (require-time race binding needs a second race-5 load); c = RakeSnapshot,
  RipSnapshot, FireNovaReplacement (module-local state, unpinnable).
- **Pinned**: `test_b_bucket_closeout_regression.lua` (27 lanes), verify_all
  battery pin 46 → 19, badges 475/475, scorecard regenerated.

## Threat-family + race close-out (2026-08-10) — TBC never 19 → 13

- **Cleared (6, all battery-fixture; zero spec-file edits)**:
  - druid/bear **Growl** — `bear_growl` scenario: `target_get_target` presents a
    healer target-of-target unit (via `_friend(…, { role = "healer" })` feeding
    `get_group_role` → `target_target_is_healer`), `form = 1`, `now = 1000`
    (> TAUNT_COOLDOWN_WINDOW 8 so the throttle passes; state.now defaulted 0 →
    always throttled).
  - paladin/prot **RighteousDefense** + **BlessingOfProtectionAlly** —
    `prot_party_peel` scenario: one `ctx.party_members` ally that is BOTH
    low-HP (≤ 35 → low_hp_ally, BoP) AND threatened (threat_status ≥ 2 →
    ally_threatened, RighteousDefense); `target_classification = 1` feeds
    RighteousDefense's elite gate.
  - paladin/holy **BlessingOfProtectionFocusedAlly** — `holy_bop_focused`
    scenario: heal-scan entry hp ≤ 38 + new `friendly_target_threat` bank key
    → `entry_needs_protection` (holy:326) sets protection_target.
  - hunter/BM **FeignDeath** — `bm_feign_death` scenario: `threat_level = 2`
    (state.threat_level = ctx.threat_level, BM:325) + `fd_mode = "high_threat"`
    setting override → `should_feign_death(2, "high_threat")` true. The (b)
    audit's "needs a threat model" was already satisfied by ctx.threat_level.
  - priest/smite **DevouringPlague** — **RACE_VARIANTS** mechanism:
    `M.RACE_VARIANTS = { smite = { 5 } }` loads smite a second time as undead
    (race 5; base load stays night elf 4 via RACE_OVERRIDES) and `run_all`
    merges the never lists (a lane is never only if never under ANY variant
    race). Smite binds `_player_race = load_player:get_race_id()` at require
    time (smite:30-32) — the require-time binding is confirmed working
    per-spec. Shadow's own DevouringPlague was NOT race-gated: `_engaged_with_player`
    (shadow:743-754) needs `target_hp < 100`, cleared by the
    `shadow_devouring_plague` scenario — the (b) audit's "shadow race binding"
    claim was wrong (that binding is smite's, already noted above).
- **New battery surface**: `_friend(hp, dist, class_id, opts)` opts
  (role → get_group_role, threat_status, has_aggro); `_heal_entries` entry
  `threat_status` (bank-driven, default nil); `run_spec`/`load_spec`
  `race_override` param; `run_all` race-variant never merge; whitelist adds
  `now`, `party_members`, `group_members`, `friendly_target_threat`.
- **Kept (10 b + 3 c)**: 9 correctly-silent OOC/disabled (PrePullEnrage,
  FaerieFirePull, FeralChargePull, TrackHumanoids, TravelForm, MountedProtection,
  ManaGemConjure ×2, DispelMagic); EncounterReactions (declined — vacuous
  without boss data); c = RakeSnapshot, RipSnapshot, FireNovaReplacement
  (module-local state, unpinnable).
- **Pinned**: `test_b_bucket_closeout_regression.lua` extended to 33 lanes
  (incl. the race-5 variant proof), verify_all battery pin 19 → 13, badges
  475/475, scorecard regenerated.

## Top-tier parsing campaign (2026-08-13/14): provenance delta

- **No fixtures added or re-fetched** — the pin set remains the
  `563e4a08cb15729f1fdcfbcb68e6d68224553bfef` (2025-12-22) baseline;
  `test_apl_conformance.lua` stays 50/50.
- **One manifest change:** `wotlk/priest/holy` gained the
  `CircleOfHealing 48089 → "CircleOfHealing"` resolve (previously nil — the
  CoH strategy did not exist). The W3.3 priest fixer added the CoH lane at its
  exact APL slot (2+ injured party members) and wired the resolve
  (tools/apl_status.lua, 2026-08-13). Disc Penance/PoM comment updates only.
- **No TBC-era pin changes** during the campaign (tbc pins: fire, arcane,
  elemental, enhancement, protection + the reference_names family — all
  untouched; every Phase 2/3 change was pin-safe additions or
  condition/build_state edits).
